-- Atendimento omnichannel: escolha do atendente, status do SLA, roteamento e
-- escalonamento dos tickets. Regras comuns aos packages do Edu:
--   * AUTHID DEFINER, sem GRANT EXECUTE para outro usuário;
--   * sem estado de package (só constantes, exceções e tipos): recriar o
--     package com a API no ar não derruba as sessões do pool (ORA-04068);
--   * nenhuma rotina faz COMMIT: a transação é de quem chama.
CREATE OR REPLACE PACKAGE PKG_TICKETS AUTHID DEFINER AS

    c_erro_ticket_nao_encontrado CONSTANT PLS_INTEGER := -20001;
    c_erro_estado_invalido       CONSTANT PLS_INTEGER := -20002;
    c_erro_segmento_inativo      CONSTANT PLS_INTEGER := -20003;

    e_ticket_nao_encontrado EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_ticket_nao_encontrado, -20001);
    e_estado_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_estado_invalido, -20002);
    e_segmento_inativo EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_segmento_inativo, -20003);

    -- Próximo atendente de uma skill: ONLINE, com menos tickets ativos e, no
    -- empate, o que está há mais tempo sem receber ticket. Nunca escolhe
    -- p_excluir_id nem o cadastro de atendente de quem abriu o ticket
    -- (p_solicitante_id é um admin_users.id, comparado com employees.user_id).
    FUNCTION FN_PROXIMO_ATENDENTE (
        p_skill_id       IN skills.id%TYPE,
        p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
        p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
    ) RETURN employees.id%TYPE;

    -- Status textual do SLA de um ticket. p_referencia existe para testes
    -- determinísticos; em produção usa-se o padrão (agora).
    FUNCTION FN_STATUS_SLA_TICKET (
        p_ticket_id  IN tickets.id%TYPE,
        p_referencia IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP
    ) RETURN VARCHAR2;

    -- Roteia um ticket pela matriz de triagem (TICKET_TIPO_CONFIG): define
    -- fila, prioridade padrão e prazo de SLA, e atribui ao próximo atendente
    -- ONLINE da skill, nunca a quem abriu o ticket. Sem ninguém online, o
    -- ticket fica na fila sem dono.
    PROCEDURE PR_ROTEAR_TICKET (
        p_ticket_id   IN  tickets.id%TYPE,
        p_employee_id OUT employees.id%TYPE
    );

    -- Escala os tickets com SLA estourado: sobe a prioridade, reatribui a outro
    -- atendente ONLINE da skill que não seja quem abriu o ticket (ou mantém o
    -- dono, se não houver outro), marca ESCALADO e renova o prazo. Cada ticket
    -- roda isolado por SAVEPOINT: se um falhar, é desfeito e registrado, e os
    -- demais seguem.
    PROCEDURE PR_ESCALAR_TICKET_CRITICO (
        p_referencia    IN  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP,
        p_qtd_escalados OUT NUMBER
    );

END PKG_TICKETS;
/
CREATE OR REPLACE PACKAGE BODY PKG_TICKETS AS

    -- DSINTERVAL_UNCONSTRAINED: um INTERVAL DAY TO SECOND comum tem precisão
    -- de 2 dígitos no dia e estoura (ORA-01873) acima de 99 dias.
    FUNCTION segundos (p_intervalo IN DSINTERVAL_UNCONSTRAINED) RETURN NUMBER
    IS
    BEGIN
        RETURN EXTRACT(DAY FROM p_intervalo) * 86400
             + EXTRACT(HOUR FROM p_intervalo) * 3600
             + EXTRACT(MINUTE FROM p_intervalo) * 60
             + EXTRACT(SECOND FROM p_intervalo);
    END segundos;

    PROCEDURE marcar_atribuicao (p_employee_id IN employees.id%TYPE)
    IS
    BEGIN
        UPDATE employees
           SET last_assigned_at = SYSTIMESTAMP
         WHERE id = p_employee_id;
    END marcar_atribuicao;

    PROCEDURE notificar_atendente (
        p_employee_id IN employees.id%TYPE,
        p_ticket_id   IN tickets.id%TYPE,
        p_tipo        IN VARCHAR2,
        p_titulo      IN VARCHAR2,
        p_corpo       IN VARCHAR2
    )
    IS
    BEGIN
        INSERT INTO notifications (recipient_user_id, ticket_id, type, title, body)
        SELECT user_id, p_ticket_id, p_tipo, p_titulo, p_corpo
          FROM employees
         WHERE id = p_employee_id;
    END notificar_atendente;

    FUNCTION FN_PROXIMO_ATENDENTE (
        p_skill_id       IN skills.id%TYPE,
        p_excluir_id     IN employees.id%TYPE DEFAULT NULL,
        p_solicitante_id IN admin_users.id%TYPE DEFAULT NULL
    ) RETURN employees.id%TYPE
    IS
        CURSOR c_candidatos IS
            SELECT e.id
              FROM employees e
              JOIN employee_skills es ON es.employee_id = e.id
             WHERE es.skill_id = p_skill_id
               AND e.presence = 'ONLINE'
               AND (p_excluir_id IS NULL OR e.id <> p_excluir_id)
               AND (p_solicitante_id IS NULL OR e.user_id <> p_solicitante_id)
             ORDER BY (SELECT COUNT(*)
                         FROM tickets t
                        WHERE t.assigned_employee_id = e.id
                          AND t.status IN ('EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO')),
                      e.last_assigned_at NULLS FIRST,
                      e.id;

        v_employee_id employees.id%TYPE;
    BEGIN
        OPEN c_candidatos;
        FETCH c_candidatos INTO v_employee_id;
        CLOSE c_candidatos;

        RETURN v_employee_id;
    END FN_PROXIMO_ATENDENTE;

    FUNCTION FN_STATUS_SLA_TICKET (
        p_ticket_id  IN tickets.id%TYPE,
        p_referencia IN TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP
    ) RETURN VARCHAR2
    IS
        v_status         tickets.status%TYPE;
        v_sla_started_at tickets.sla_started_at%TYPE;
        v_sla_due_at     tickets.sla_due_at%TYPE;
        v_resolved_at    tickets.resolved_at%TYPE;
        v_janela         NUMBER;
        v_consumido      NUMBER;
    BEGIN
        SELECT status, sla_started_at, sla_due_at, resolved_at
          INTO v_status, v_sla_started_at, v_sla_due_at, v_resolved_at
          FROM tickets
         WHERE id = p_ticket_id;

        IF v_status IN ('RESOLVIDO', 'FECHADO') THEN
            IF v_sla_due_at IS NULL OR v_resolved_at <= v_sla_due_at THEN
                RETURN 'CUMPRIDO';
            END IF;
            RETURN 'VIOLADO';
        END IF;

        IF v_sla_due_at IS NULL THEN
            RETURN 'NO_PRAZO';
        END IF;

        IF p_referencia > v_sla_due_at THEN
            RETURN 'ESTOURADO';
        END IF;

        v_janela    := segundos(v_sla_due_at - NVL(v_sla_started_at, v_sla_due_at));
        v_consumido := segundos(p_referencia - NVL(v_sla_started_at, p_referencia));

        IF v_janela > 0 AND v_consumido / v_janela >= 0.8 THEN
            RETURN 'EM_RISCO';
        END IF;

        RETURN 'NO_PRAZO';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(c_erro_ticket_nao_encontrado, 'Ticket ' || p_ticket_id || ' não encontrado');
    END FN_STATUS_SLA_TICKET;

    PROCEDURE PR_ROTEAR_TICKET (
        p_ticket_id   IN  tickets.id%TYPE,
        p_employee_id OUT employees.id%TYPE
    )
    IS
        v_status    tickets.status%TYPE;
        v_assigned  tickets.assigned_employee_id%TYPE;
        v_segment   tickets.segment%TYPE;
        v_requester tickets.user_id%TYPE;
        v_config    ticket_tipo_config%ROWTYPE;
        v_destino   tickets.status%TYPE;
    BEGIN
        p_employee_id := NULL;

        BEGIN
            SELECT status, assigned_employee_id, segment, user_id
              INTO v_status, v_assigned, v_segment, v_requester
              FROM tickets
             WHERE id = p_ticket_id
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(c_erro_ticket_nao_encontrado, 'Ticket ' || p_ticket_id || ' não encontrado');
        END;

        IF NOT (v_status = 'ABERTO'
                OR (v_status IN ('EM_FILA', 'ESCALADO') AND v_assigned IS NULL)) THEN
            RAISE_APPLICATION_ERROR(c_erro_estado_invalido,
                'Ticket ' || p_ticket_id || ' não pode ser roteado no estado ' || v_status);
        END IF;

        BEGIN
            SELECT *
              INTO v_config
              FROM ticket_tipo_config
             WHERE segment = v_segment
               AND active = TRUE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(c_erro_segmento_inativo, 'Segmento ' || v_segment || ' sem configuração ativa');
        END;

        p_employee_id := FN_PROXIMO_ATENDENTE(v_config.skill_id, p_solicitante_id => v_requester);
        v_destino := CASE WHEN v_status = 'ESCALADO' THEN 'ESCALADO' ELSE 'EM_FILA' END;

        UPDATE tickets
           SET status               = v_destino,
               assigned_employee_id = p_employee_id,
               priority             = CASE WHEN v_status = 'ABERTO' THEN v_config.default_priority ELSE priority END,
               sla_started_at       = NVL(sla_started_at, SYSTIMESTAMP),
               sla_due_at           = NVL(sla_due_at, SYSTIMESTAMP + NUMTODSINTERVAL(v_config.sla_minutes, 'MINUTE')),
               updated_at           = SYSTIMESTAMP
         WHERE id = p_ticket_id;

        IF p_employee_id IS NOT NULL THEN
            marcar_atribuicao(p_employee_id);
            notificar_atendente(p_employee_id, p_ticket_id, 'TICKET_ATRIBUIDO', 'Novo ticket na sua fila',
                                'Ticket #' || p_ticket_id || ' (' || v_config.label || ') foi atribuído a você.');
        END IF;

        INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail)
        VALUES (p_ticket_id, 'ROTEADO', v_status, v_destino, p_employee_id,
                CASE WHEN p_employee_id IS NULL
                     THEN 'Fila ' || v_config.queue || ': nenhum outro atendente online'
                     ELSE 'Fila ' || v_config.queue END);
    END PR_ROTEAR_TICKET;

    PROCEDURE PR_ESCALAR_TICKET_CRITICO (
        p_referencia    IN  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP,
        p_qtd_escalados OUT NUMBER
    )
    IS
        CURSOR c_vencidos IS
            SELECT t.id, t.status, t.priority, t.assigned_employee_id, t.user_id,
                   c.skill_id, c.escalation_minutes, c.label
              FROM tickets t
              JOIN ticket_tipo_config c ON c.segment = t.segment
             WHERE t.status IN ('EM_FILA', 'EM_ATENDIMENTO', 'ESCALADO')
               AND t.sla_due_at < p_referencia
             ORDER BY t.sla_due_at, t.id
               FOR UPDATE OF t.status SKIP LOCKED;

        v_novo_dono employees.id%TYPE;
        v_nova_prio tickets.priority%TYPE;
        v_erro      VARCHAR2(500);
    BEGIN
        p_qtd_escalados := 0;

        FOR r IN c_vencidos LOOP
            SAVEPOINT sp_ticket;
            BEGIN
                v_nova_prio := CASE r.priority WHEN 'NORMAL' THEN 'ALTA' ELSE 'CRITICA' END;
                v_novo_dono := NVL(FN_PROXIMO_ATENDENTE(r.skill_id, r.assigned_employee_id, r.user_id),
                                   r.assigned_employee_id);

                UPDATE tickets
                   SET priority             = v_nova_prio,
                       status               = 'ESCALADO',
                       assigned_employee_id = v_novo_dono,
                       sla_started_at       = p_referencia,
                       sla_due_at           = p_referencia + NUMTODSINTERVAL(r.escalation_minutes, 'MINUTE'),
                       updated_at           = SYSTIMESTAMP
                 WHERE id = r.id;

                IF v_novo_dono IS NOT NULL THEN
                    IF v_novo_dono <> NVL(r.assigned_employee_id, -1) THEN
                        marcar_atribuicao(v_novo_dono);
                    END IF;

                    notificar_atendente(v_novo_dono, r.id, 'TICKET_ESCALADO', 'Ticket escalado',
                                        'Ticket #' || r.id || ' (' || r.label || ') estourou o SLA e está com prioridade '
                                        || v_nova_prio || '.');
                END IF;

                INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail)
                VALUES (r.id, 'ESCALADO', r.status, 'ESCALADO', v_novo_dono,
                        'Prioridade ' || r.priority || ' -> ' || v_nova_prio);

                p_qtd_escalados := p_qtd_escalados + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    v_erro := SUBSTR(SQLERRM, 1, 500);
                    ROLLBACK TO SAVEPOINT sp_ticket;
                    INSERT INTO ticket_events (ticket_id, type, detail)
                    VALUES (r.id, 'ERRO_ESCALONAMENTO', v_erro);
            END;
        END LOOP;
    END PR_ESCALAR_TICKET_CRITICO;

END PKG_TICKETS;
/
