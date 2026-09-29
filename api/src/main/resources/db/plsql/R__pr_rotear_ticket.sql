-- Roteia um ticket pela matriz de triagem (TICKET_TIPO_CONFIG): define fila,
-- prioridade padrão e prazo de SLA, e atribui ao próximo atendente ONLINE da
-- skill. Sem ninguém online, o ticket fica na fila sem dono. Não faz COMMIT.
CREATE OR REPLACE PROCEDURE PR_ROTEAR_TICKET (
    p_ticket_id   IN  tickets.id%TYPE,
    p_employee_id OUT employees.id%TYPE
)
IS
    v_status   tickets.status%TYPE;
    v_assigned tickets.assigned_employee_id%TYPE;
    v_segment  tickets.segment%TYPE;
    v_config   ticket_tipo_config%ROWTYPE;
    v_destino  tickets.status%TYPE;
BEGIN
    p_employee_id := NULL;

    BEGIN
        SELECT status, assigned_employee_id, segment
          INTO v_status, v_assigned, v_segment
          FROM tickets
         WHERE id = p_ticket_id
           FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Ticket ' || p_ticket_id || ' não encontrado');
    END;

    IF NOT (v_status = 'ABERTO'
            OR (v_status IN ('EM_FILA', 'ESCALADO') AND v_assigned IS NULL)) THEN
        RAISE_APPLICATION_ERROR(-20002,
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
            RAISE_APPLICATION_ERROR(-20003, 'Segmento ' || v_segment || ' sem configuração ativa');
    END;

    p_employee_id := FN_PROXIMO_ATENDENTE(v_config.skill_id);
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
        UPDATE employees
           SET last_assigned_at = SYSTIMESTAMP
         WHERE id = p_employee_id;

        INSERT INTO notifications (recipient_user_id, ticket_id, type, title, body)
        SELECT user_id, p_ticket_id, 'TICKET_ATRIBUIDO', 'Novo ticket na sua fila',
               'Ticket #' || p_ticket_id || ' (' || v_config.label || ') foi atribuído a você.'
          FROM employees
         WHERE id = p_employee_id;
    END IF;

    INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail)
    VALUES (p_ticket_id, 'ROTEADO', v_status, v_destino, p_employee_id,
            CASE WHEN p_employee_id IS NULL
                 THEN 'Fila ' || v_config.queue || ': nenhum atendente online'
                 ELSE 'Fila ' || v_config.queue END);
END PR_ROTEAR_TICKET;
/
