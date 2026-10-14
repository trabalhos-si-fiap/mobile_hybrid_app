-- A auditoria só recebe INSERT: nem a API nem SQL manual alteram ou apagam o
-- que foi registrado. O dono do schema ainda pode desabilitar a trigger ou
-- usar TRUNCATE (ver docs/banco-de-dados/plsql.md, "Limites da auditoria").
CREATE OR REPLACE TRIGGER TRG_TICKET_AUDITORIA_IMUTAVEL
BEFORE UPDATE OR DELETE ON ticket_auditoria
FOR EACH ROW
BEGIN
    RAISE_APPLICATION_ERROR(-20006, 'A auditoria de tickets não pode ser alterada nem apagada');
END TRG_TICKET_AUDITORIA_IMUTAVEL;
/
