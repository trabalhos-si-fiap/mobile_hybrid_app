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
    c_erro_busca_invalida        CONSTANT PLS_INTEGER := -20005;

    e_ticket_nao_encontrado EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_ticket_nao_encontrado, -20001);
    e_estado_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_estado_invalido, -20002);
    e_segmento_inativo EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_segmento_inativo, -20003);
    e_busca_invalida EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_busca_invalida, -20005);

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

    -- Busca de tickets com filtros opcionais, montada por Dynamic SQL
    -- (DBMS_SQL): filtro nulo fica fora do SQL, os valores entram por bind e
    -- a ordenação passa por whitelist. p_usuario_id e p_ver_todos não têm
    -- padrão: sem p_ver_todos, só aparece o que o usuário pode ver (abriu, é
    -- dono ou é de um segmento da sua skill). Devolve as colunas do resumo do
    -- ticket, no máximo p_limite linhas. Erros: -20005.
    PROCEDURE PR_BUSCAR_TICKETS (
        p_usuario_id   IN  admin_users.id%TYPE,
        p_ver_todos    IN  BOOLEAN,
        p_status       IN  tickets.status%TYPE      DEFAULT NULL,
        p_segment      IN  tickets.segment%TYPE     DEFAULT NULL,
        p_priority     IN  tickets.priority%TYPE    DEFAULT NULL,
        p_atendente_id IN  employees.id%TYPE        DEFAULT NULL,
        p_criado_desde IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_criado_ate   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_texto        IN  VARCHAR2                 DEFAULT NULL,
        p_alerta_eng   IN  BOOLEAN                  DEFAULT NULL,
        p_ordenar_por  IN  VARCHAR2                 DEFAULT 'CRIADO_EM',
        p_direcao      IN  VARCHAR2                 DEFAULT 'DESC',
        p_limite       IN  PLS_INTEGER              DEFAULT 50,
        p_referencia   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_resultado    OUT SYS_REFCURSOR
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

    PROCEDURE PR_BUSCAR_TICKETS (
        p_usuario_id   IN  admin_users.id%TYPE,
        p_ver_todos    IN  BOOLEAN,
        p_status       IN  tickets.status%TYPE      DEFAULT NULL,
        p_segment      IN  tickets.segment%TYPE     DEFAULT NULL,
        p_priority     IN  tickets.priority%TYPE    DEFAULT NULL,
        p_atendente_id IN  employees.id%TYPE        DEFAULT NULL,
        p_criado_desde IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_criado_ate   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_texto        IN  VARCHAR2                 DEFAULT NULL,
        p_alerta_eng   IN  BOOLEAN                  DEFAULT NULL,
        p_ordenar_por  IN  VARCHAR2                 DEFAULT 'CRIADO_EM',
        p_direcao      IN  VARCHAR2                 DEFAULT 'DESC',
        p_limite       IN  PLS_INTEGER              DEFAULT 50,
        p_referencia   IN  TIMESTAMP WITH TIME ZONE DEFAULT NULL,
        p_resultado    OUT SYS_REFCURSOR
    )
    IS
        -- O JDBC manda todos os parâmetros, inclusive os nulos: o DEFAULT da
        -- assinatura não se aplica, então os padrões vêm do NVL. v_coluna cabe
        -- qualquer valor recebido: um erro na declaração não chegaria ao
        -- recusar e sairia como ORA-06502, não -20005.
        v_coluna    VARCHAR2(32767) := UPPER(NVL(p_ordenar_por, 'CRIADO_EM'));
        v_limite    NUMBER          := NVL(p_limite, 50);
        v_texto     VARCHAR2(32767) := TRIM(p_texto);
        v_ordem     VARCHAR2(100);
        v_direcao   VARCHAR2(4);
        v_nulos     VARCHAR2(11);
        v_filtros   VARCHAR2(4000);
        v_sql       VARCHAR2(32767);
        v_cursor    INTEGER;
        v_executado INTEGER;

        -- A mensagem diz o parâmetro, nunca o valor recebido.
        PROCEDURE recusar (p_motivo IN VARCHAR2)
        IS
        BEGIN
            RAISE_APPLICATION_ERROR(c_erro_busca_invalida, 'Busca inválida: ' || p_motivo);
        END recusar;
    BEGIN
        IF p_usuario_id IS NULL THEN
            recusar('p_usuario_id é obrigatório');
        END IF;
        IF p_ver_todos IS NULL THEN
            recusar('p_ver_todos é obrigatório');
        END IF;

        -- Whitelist: o parâmetro só escolhe um trecho fixo do código; nenhum
        -- caractere dele entra no SQL.
        v_ordem := CASE v_coluna
                       WHEN 'CRIADO_EM'     THEN 't.created_at'
                       WHEN 'ATUALIZADO_EM' THEN 't.updated_at'
                       WHEN 'PRAZO_SLA'     THEN 't.sla_due_at'
                       WHEN 'PRIORIDADE'    THEN 'DECODE(t.priority, ''CRITICA'', 3, ''ALTA'', 2, 1)'
                   END;
        IF v_ordem IS NULL THEN
            recusar('p_ordenar_por aceita CRIADO_EM, ATUALIZADO_EM, PRAZO_SLA ou PRIORIDADE');
        END IF;

        v_direcao := CASE UPPER(NVL(p_direcao, 'DESC')) WHEN 'ASC' THEN 'ASC' WHEN 'DESC' THEN 'DESC' END;
        IF v_direcao IS NULL THEN
            recusar('p_direcao aceita ASC ou DESC');
        END IF;
        -- Ticket sem prazo fica sempre no fim, nas duas direções.
        v_nulos := CASE WHEN v_coluna = 'PRAZO_SLA' THEN ' NULLS LAST' END;

        IF v_limite NOT BETWEEN 1 AND 200 THEN
            recusar('p_limite aceita de 1 a 200');
        END IF;
        IF v_texto IS NOT NULL AND LENGTH(v_texto) NOT BETWEEN 3 AND 200 THEN
            recusar('p_texto aceita de 3 a 200 caracteres');
        END IF;
        IF p_criado_desde > p_criado_ate THEN
            recusar('p_criado_desde deve ser anterior ou igual a p_criado_ate');
        END IF;

        -- Predicados sempre na mesma ordem e com os mesmos nomes de bind: cada
        -- combinação de filtros gera um único texto de SQL, que o Oracle
        -- reaproveita.
        IF NOT p_ver_todos THEN
            v_filtros := v_filtros
                || ' AND (t.user_id = :usuario'
                || ' OR EXISTS (SELECT 1 FROM employees e WHERE e.user_id = :usuario'
                || ' AND (t.assigned_employee_id = e.id'
                || ' OR t.segment IN (SELECT c.segment FROM ticket_tipo_config c'
                || ' JOIN employee_skills es ON es.skill_id = c.skill_id'
                || ' WHERE es.employee_id = e.id))))';
        END IF;
        IF p_status IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.status = :status';
        END IF;
        IF p_segment IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.segment = :segment';
        END IF;
        IF p_priority IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.priority = :priority';
        END IF;
        IF p_atendente_id IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.assigned_employee_id = :atendente';
        END IF;
        IF p_criado_desde IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.created_at >= :desde';
        END IF;
        IF p_criado_ate IS NOT NULL THEN
            v_filtros := v_filtros || ' AND t.created_at < :ate';
        END IF;
        IF v_texto IS NOT NULL THEN
            v_filtros := v_filtros || ' AND LOWER(t.description) LIKE :texto ESCAPE ''\''';
        END IF;
        IF p_alerta_eng IS NOT NULL THEN
            v_filtros := v_filtros || CASE WHEN p_alerta_eng THEN ' AND t.engineering_alert = TRUE'
                                           ELSE ' AND t.engineering_alert = FALSE' END;
        END IF;

        -- A consulta interna filtra, ordena e limita; a externa junta rótulo e
        -- nomes e calcula o SLA só das linhas devolvidas.
        v_sql := 'SELECT b.id, b.segment, c.label AS segment_label, b.status, b.priority,'
              || ' PKG_TICKETS.FN_STATUS_SLA_TICKET(b.id, :referencia) AS sla_status, b.sla_due_at,'
              || ' r.name AS requester_name, a.name AS assignee_name, b.engineering_alert,'
              || ' b.created_at, b.updated_at'
              || ' FROM (SELECT t.id, t.segment, t.status, t.priority, t.sla_due_at, t.user_id,'
              || ' t.assigned_employee_id, t.engineering_alert, t.created_at, t.updated_at,'
              || ' ' || v_ordem || ' AS ordem'
              || ' FROM tickets t WHERE 1 = 1' || v_filtros
              || ' ORDER BY ordem ' || v_direcao || v_nulos || ', t.id ' || v_direcao
              || ' FETCH FIRST :limite ROWS ONLY) b'
              || ' JOIN ticket_tipo_config c ON c.segment = b.segment'
              || ' JOIN admin_users r ON r.id = b.user_id'
              || ' LEFT JOIN employees e ON e.id = b.assigned_employee_id'
              || ' LEFT JOIN admin_users a ON a.id = e.user_id'
              || ' ORDER BY b.ordem ' || v_direcao || v_nulos || ', b.id ' || v_direcao;

        -- DBMS_SQL liga só as binds dos filtros presentes, o que o OPEN ... FOR
        -- ... USING (lista fixa) não faz.
        v_cursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(v_cursor, v_sql, DBMS_SQL.NATIVE);

        DBMS_SQL.BIND_VARIABLE(v_cursor, ':referencia', NVL(p_referencia, SYSTIMESTAMP));
        DBMS_SQL.BIND_VARIABLE(v_cursor, ':limite', v_limite);
        IF NOT p_ver_todos THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':usuario', p_usuario_id);
        END IF;
        IF p_status IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':status', p_status);
        END IF;
        IF p_segment IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':segment', p_segment);
        END IF;
        IF p_priority IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':priority', p_priority);
        END IF;
        IF p_atendente_id IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':atendente', p_atendente_id);
        END IF;
        IF p_criado_desde IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':desde', p_criado_desde);
        END IF;
        IF p_criado_ate IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':ate', p_criado_ate);
        END IF;
        IF v_texto IS NOT NULL THEN
            -- Primeiro a barra, depois % e _: na ordem inversa, a barra do texto
            -- escaparia o caractere seguinte.
            DBMS_SQL.BIND_VARIABLE(v_cursor, ':texto',
                '%' || REPLACE(REPLACE(REPLACE(LOWER(v_texto), '\', '\\'), '%', '\%'), '_', '\_') || '%');
        END IF;

        v_executado := DBMS_SQL.EXECUTE(v_cursor);
        p_resultado := DBMS_SQL.TO_REFCURSOR(v_cursor);
    EXCEPTION
        WHEN OTHERS THEN
            IF v_cursor IS NOT NULL AND DBMS_SQL.IS_OPEN(v_cursor) THEN
                DBMS_SQL.CLOSE_CURSOR(v_cursor);
            END IF;
            RAISE;
    END PR_BUSCAR_TICKETS;

END PKG_TICKETS;
/
