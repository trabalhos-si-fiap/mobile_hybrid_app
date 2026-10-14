-- Packages PL/SQL.
--
-- Remove os sete objetos standalone que viraram membros de PKG_TICKETS,
-- PKG_CHATBOT e PKG_DASHBOARD (db/plsql). Num banco novo eles não existem e
-- o bloco não faz nada; os nomes são fixos, nunca vêm de fora.
BEGIN
    FOR o IN (SELECT object_type, object_name
                FROM user_objects
               WHERE object_type IN ('FUNCTION', 'PROCEDURE')
                 AND object_name IN ('FN_PROXIMO_ATENDENTE', 'FN_STATUS_SLA_TICKET', 'PR_ROTEAR_TICKET',
                                     'PR_ESCALAR_TICKET_CRITICO', 'FN_CHATBOT_RESPOSTA',
                                     'FN_CALC_TAXA_VARIACAO', 'PR_RESUMO_DASHBOARD')) LOOP
        EXECUTE IMMEDIATE 'DROP ' || o.object_type || ' ' || o.object_name;
    END LOOP;
END;
/
