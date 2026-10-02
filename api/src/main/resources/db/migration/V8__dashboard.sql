-- Índices das agregações do dashboard do atendimento (PR_RESUMO_DASHBOARD):
-- janelas por abertura, por resolução e eventos de escalonamento por data.
CREATE INDEX IX_TICKETS_CREATED ON tickets (created_at);
CREATE INDEX IX_TICKETS_RESOLVED ON tickets (resolved_at);
CREATE INDEX IX_TICKET_EVT_TYPE_CREATED ON ticket_events (type, created_at);
