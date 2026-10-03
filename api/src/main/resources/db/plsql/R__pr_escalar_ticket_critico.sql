-- Escala os tickets com SLA estourado: sobe a prioridade, reatribui a outro
-- atendente ONLINE da skill que não seja quem abriu o ticket (ou mantém o
-- dono, se não houver outro), marca ESCALADO e renova o prazo. Cada ticket
-- roda isolado por SAVEPOINT: se um falhar, é desfeito e registrado, e os
-- demais seguem. Não faz COMMIT.
CREATE OR REPLACE PROCEDURE PR_ESCALAR_TICKET_CRITICO (
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
                    UPDATE employees
                       SET last_assigned_at = SYSTIMESTAMP
                     WHERE id = v_novo_dono;
                END IF;

                INSERT INTO notifications (recipient_user_id, ticket_id, type, title, body)
                SELECT user_id, r.id, 'TICKET_ESCALADO', 'Ticket escalado',
                       'Ticket #' || r.id || ' (' || r.label || ') estourou o SLA e está com prioridade '
                       || v_nova_prio || '.'
                  FROM employees
                 WHERE id = v_novo_dono;
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
/
