-- Auditoria dos tickets: uma linha em TICKET_AUDITORIA para cada campo de
-- estado que mudou, venha a mudança da API, do PL/SQL ou de SQL manual. Um
-- UPDATE que não cita as colunas auditadas nem dispara a trigger. Não lê
-- TICKETS (sem tabela mutante) e não faz COMMIT: a auditoria segue a
-- transação de quem mudou o ticket.
CREATE OR REPLACE TRIGGER TRG_TICKETS_AUDITORIA
AFTER INSERT OR DELETE
   OR UPDATE OF status, priority, assigned_employee_id, segment, engineering_alert
   ON tickets
FOR EACH ROW
DECLARE
    v_operacao ticket_auditoria.operacao%TYPE;
    v_ticket   tickets.id%TYPE;

    -- Grava só quando antes e depois diferem: nulo e valor são diferentes,
    -- nulo e nulo são iguais.
    PROCEDURE registrar (
        p_campo    IN VARCHAR2,
        p_anterior IN VARCHAR2,
        p_novo     IN VARCHAR2
    )
    IS
    BEGIN
        IF (p_anterior IS NULL AND p_novo IS NULL) OR p_anterior = p_novo THEN
            RETURN;
        END IF;

        INSERT INTO ticket_auditoria (ticket_id, operacao, campo, valor_anterior, valor_novo)
        VALUES (v_ticket, v_operacao, p_campo, p_anterior, p_novo);
    END registrar;

    FUNCTION texto (p_valor IN BOOLEAN) RETURN VARCHAR2
    IS
    BEGIN
        RETURN CASE WHEN p_valor IS NULL THEN NULL WHEN p_valor THEN 'TRUE' ELSE 'FALSE' END;
    END texto;
BEGIN
    v_operacao := CASE WHEN INSERTING THEN 'INSERT' WHEN UPDATING THEN 'UPDATE' ELSE 'DELETE' END;
    v_ticket   := NVL(:NEW.id, :OLD.id);

    registrar('STATUS', :OLD.status, :NEW.status);
    registrar('PRIORITY', :OLD.priority, :NEW.priority);
    registrar('ASSIGNED_EMPLOYEE_ID', TO_CHAR(:OLD.assigned_employee_id), TO_CHAR(:NEW.assigned_employee_id));
    registrar('SEGMENT', :OLD.segment, :NEW.segment);
    registrar('ENGINEERING_ALERT', texto(:OLD.engineering_alert), texto(:NEW.engineering_alert));
END TRG_TICKETS_AUDITORIA;
/
