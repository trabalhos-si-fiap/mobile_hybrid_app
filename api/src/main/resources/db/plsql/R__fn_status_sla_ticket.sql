-- Status textual do SLA de um ticket. p_referencia existe para testes
-- determinísticos; em produção usa-se o padrão (agora).
CREATE OR REPLACE FUNCTION FN_STATUS_SLA_TICKET (
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

    FUNCTION segundos (p_intervalo IN INTERVAL DAY TO SECOND) RETURN NUMBER
    IS
    BEGIN
        RETURN EXTRACT(DAY FROM p_intervalo) * 86400
             + EXTRACT(HOUR FROM p_intervalo) * 3600
             + EXTRACT(MINUTE FROM p_intervalo) * 60
             + EXTRACT(SECOND FROM p_intervalo);
    END segundos;
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
        RAISE_APPLICATION_ERROR(-20001, 'Ticket ' || p_ticket_id || ' não encontrado');
END FN_STATUS_SLA_TICKET;
/
