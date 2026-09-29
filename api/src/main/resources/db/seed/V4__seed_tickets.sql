-- Demonstração dos tickets omnichannel (não roda no perfil de teste).
-- Atendentes: senha atendente123 (BCrypt, custo 10). Todos começam OFFLINE.
-- Só INSERTs simples: os R__ (PL/SQL) rodam depois das versões, então o seed
-- não pode depender deles.

INSERT INTO admin_users (name, email, password, role)
VALUES ('Diego Desenvolvedor', 'dev@edu.com', '$2a$10$fm/X5dFA8iXq6/A3wB8qAO64pYeAqBoo7zY.lAkygJi02/4RolrSS', 'EMPLOYEE');
INSERT INTO admin_users (name, email, password, role)
VALUES ('Lara Logística', 'logistica@edu.com', '$2a$10$fm/X5dFA8iXq6/A3wB8qAO64pYeAqBoo7zY.lAkygJi02/4RolrSS', 'EMPLOYEE');
INSERT INTO admin_users (name, email, password, role)
VALUES ('Paula Produto', 'produto@edu.com', '$2a$10$fm/X5dFA8iXq6/A3wB8qAO64pYeAqBoo7zY.lAkygJi02/4RolrSS', 'EMPLOYEE');

INSERT INTO employees (user_id)
SELECT id FROM admin_users
 WHERE email IN ('dev@edu.com', 'logistica@edu.com', 'produto@edu.com', 'admin@edu.com');

INSERT INTO employee_skills (employee_id, skill_id)
SELECT e.id, s.id
  FROM employees e
  JOIN admin_users u ON u.id = e.user_id
  JOIN skills s ON (u.email = 'dev@edu.com' AND s.code = 'DESENVOLVEDOR')
                OR (u.email = 'logistica@edu.com' AND s.code = 'GESTAO_ENTREGAS')
                OR (u.email = 'produto@edu.com' AND s.code = 'PRODUTO_MELHORIAS')
                OR u.email = 'admin@edu.com';

-- 1) Defeito em atendimento com o dev, com conversa.
INSERT INTO tickets (user_id, segment, description, status, priority, assigned_employee_id,
                     sla_started_at, sla_due_at, created_at, updated_at, assumed_at)
SELECT u.id, 'DEFEITO_APP', 'O app fecha sozinho quando abro o carrinho de compras.', 'EM_ATENDIMENTO', 'ALTA', e.id,
       SYSTIMESTAMP - NUMTODSINTERVAL(30, 'MINUTE'), SYSTIMESTAMP + NUMTODSINTERVAL(210, 'MINUTE'),
       SYSTIMESTAMP - NUMTODSINTERVAL(30, 'MINUTE'), SYSTIMESTAMP - NUMTODSINTERVAL(10, 'MINUTE'),
       SYSTIMESTAMP - NUMTODSINTERVAL(20, 'MINUTE')
  FROM admin_users u
 CROSS JOIN employees e
  JOIN admin_users du ON du.id = e.user_id
 WHERE u.email = 'usuario@edu.com'
   AND du.email = 'dev@edu.com';

-- 2) Pedido na fila sem dono, com SLA estourado: demonstra o escalonamento
--    pelo job e o roteamento quando logistica@edu.com fica ONLINE.
INSERT INTO tickets (user_id, segment, description, status, priority,
                     sla_started_at, sla_due_at, created_at, updated_at)
SELECT id, 'PROBLEMA_PEDIDO', 'Meu pedido #7788 consta como entregue, mas não recebi.', 'EM_FILA', 'NORMAL',
       SYSTIMESTAMP - NUMTODSINTERVAL(490, 'MINUTE'), SYSTIMESTAMP - NUMTODSINTERVAL(10, 'MINUTE'),
       SYSTIMESTAMP - NUMTODSINTERVAL(490, 'MINUTE'), SYSTIMESTAMP - NUMTODSINTERVAL(490, 'MINUTE')
  FROM admin_users
 WHERE email = 'usuario@edu.com';

-- 3) Sugestão resolvida aguardando confirmação do usuário.
INSERT INTO tickets (user_id, segment, description, status, priority, assigned_employee_id,
                     sla_started_at, sla_due_at, created_at, updated_at, assumed_at, resolved_at)
SELECT u.id, 'FEEDBACK_SUGESTAO', 'Seria ótimo poder filtrar os cursos por duração.', 'RESOLVIDO', 'NORMAL', e.id,
       SYSTIMESTAMP - NUMTODSINTERVAL(1, 'DAY'), SYSTIMESTAMP + NUMTODSINTERVAL(1, 'DAY'),
       SYSTIMESTAMP - NUMTODSINTERVAL(1, 'DAY'), SYSTIMESTAMP - NUMTODSINTERVAL(2, 'HOUR'),
       SYSTIMESTAMP - NUMTODSINTERVAL(20, 'HOUR'), SYSTIMESTAMP - NUMTODSINTERVAL(2, 'HOUR')
  FROM admin_users u
 CROSS JOIN employees e
  JOIN admin_users pu ON pu.id = e.user_id
 WHERE u.email = 'usuario@edu.com'
   AND pu.email = 'produto@edu.com';

-- Conversas.
INSERT INTO ticket_messages (ticket_id, sender_type, sender_user_id, body, created_at)
SELECT t.id, 'EMPLOYEE', du.id, 'Olá! Qual a versão do app e o modelo do seu celular?',
       SYSTIMESTAMP - NUMTODSINTERVAL(15, 'MINUTE')
  FROM tickets t CROSS JOIN admin_users du
 WHERE t.description = 'O app fecha sozinho quando abro o carrinho de compras.'
   AND du.email = 'dev@edu.com';
INSERT INTO ticket_messages (ticket_id, sender_type, sender_user_id, body, created_at)
SELECT t.id, 'USER', u.id, 'Versão 2.3.1, num Android 14.', SYSTIMESTAMP - NUMTODSINTERVAL(10, 'MINUTE')
  FROM tickets t CROSS JOIN admin_users u
 WHERE t.description = 'O app fecha sozinho quando abro o carrinho de compras.'
   AND u.email = 'usuario@edu.com';
INSERT INTO ticket_messages (ticket_id, sender_type, sender_user_id, body, created_at)
SELECT t.id, 'EMPLOYEE', pu.id, 'Obrigada pela sugestão! Registramos no backlog de evolução do produto.',
       SYSTIMESTAMP - NUMTODSINTERVAL(2, 'HOUR')
  FROM tickets t CROSS JOIN admin_users pu
 WHERE t.description = 'Seria ótimo poder filtrar os cursos por duração.'
   AND pu.email = 'produto@edu.com';

-- Trilha de eventos coerente com os estados acima.
INSERT INTO ticket_events (ticket_id, type, from_status, to_status, created_at)
SELECT id, 'ABERTO', NULL, 'ABERTO', created_at
  FROM tickets
 WHERE description IN ('O app fecha sozinho quando abro o carrinho de compras.',
                       'Meu pedido #7788 consta como entregue, mas não recebi.',
                       'Seria ótimo poder filtrar os cursos por duração.');

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail, created_at)
SELECT t.id, 'ROTEADO', 'ABERTO', 'EM_FILA', t.assigned_employee_id,
       CASE WHEN t.assigned_employee_id IS NULL
            THEN 'Fila ' || c.queue || ': nenhum atendente online'
            ELSE 'Fila ' || c.queue END,
       t.created_at + NUMTODSINTERVAL(1, 'SECOND')
  FROM tickets t
  JOIN ticket_tipo_config c ON c.segment = t.segment
 WHERE t.description IN ('O app fecha sozinho quando abro o carrinho de compras.',
                         'Meu pedido #7788 consta como entregue, mas não recebi.',
                         'Seria ótimo poder filtrar os cursos por duração.');

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, created_at)
SELECT id, 'ASSUMIDO', 'EM_FILA', 'EM_ATENDIMENTO', assigned_employee_id, assumed_at
  FROM tickets
 WHERE description IN ('O app fecha sozinho quando abro o carrinho de compras.',
                       'Seria ótimo poder filtrar os cursos por duração.');

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, created_at)
SELECT id, 'RESOLVIDO', 'EM_ATENDIMENTO', 'RESOLVIDO', assigned_employee_id, resolved_at
  FROM tickets
 WHERE description = 'Seria ótimo poder filtrar os cursos por duração.';

-- Notificações que o usuário já teria recebido.
INSERT INTO notifications (recipient_user_id, ticket_id, type, title, body, created_at)
SELECT user_id, id, 'TICKET_ASSUMIDO', 'Atendimento iniciado',
       'Seu ticket #' || id || ' está em atendimento.', assumed_at
  FROM tickets
 WHERE description = 'O app fecha sozinho quando abro o carrinho de compras.';
INSERT INTO notifications (recipient_user_id, ticket_id, type, title, body, created_at)
SELECT user_id, id, 'TICKET_RESOLVIDO', 'Ticket resolvido',
       'Confirme a solução ou reabra o ticket #' || id || '.', resolved_at
  FROM tickets
 WHERE description = 'Seria ótimo poder filtrar os cursos por duração.';
