-- Histórico de atendimento para o dashboard: 180 dias de tickets já fechados,
-- gerados por aritmética (sem DBMS_RANDOM: a mesma massa a cada subida), e um
-- pico de "Problemas com pedido" nas últimas 24 horas. Tudo é relativo à hora
-- da migration, então o pico vale nas 24 horas seguintes à subida da stack;
-- para repetir a demonstração, zere a stack (docker compose down -v).

-- Clientes fictícios, donos do histórico. A senha não é um hash BCrypt, então
-- ninguém entra com essas contas.
INSERT INTO admin_users (name, email, password, role)
SELECT name, email, 'conta-de-demonstracao-sem-login', 'USER'
  FROM (SELECT 'Ana Souza' AS name, 'cliente1@edu.com' AS email FROM dual
        UNION ALL SELECT 'Bruno Lima', 'cliente2@edu.com' FROM dual
        UNION ALL SELECT 'Carla Mendes', 'cliente3@edu.com' FROM dual
        UNION ALL SELECT 'Davi Rocha', 'cliente4@edu.com' FROM dual
        UNION ALL SELECT 'Elisa Prado', 'cliente5@edu.com' FROM dual);

-- Um ticket por (dia d, segmento, n). Dia 0: as últimas 24 horas, com 12
-- pedidos (o pico) e 3 nos outros segmentos, abertos entre 13 e 46 minutos
-- antes da migration. Dias 1 a 179: 2 a 5 por segmento, abertos de 5 a 21
-- horas antes do fim da janela de 24 horas do dia. h é um índice
-- estável que varia canal, tempos e SLA. Só a partir do dia 3 há SLA violado
-- (resolução depois do prazo do segmento) e escalonamento, para nenhum
-- carimbo cair no futuro.
INSERT INTO tickets (user_id, segment, description, channel, status, priority, assigned_employee_id,
                     sla_started_at, sla_due_at, created_at, updated_at, assumed_at, resolved_at, closed_at)
WITH dia AS (
    SELECT LEVEL - 1 AS d FROM dual CONNECT BY LEVEL <= 180
),
seq AS (
    SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 12
),
segmento AS (
    SELECT c.segment,
           c.label,
           c.default_priority,
           c.sla_minutes,
           DECODE(c.segment, 'DEFEITO_APP', 1, 'PROBLEMA_PEDIDO', 2, 3) AS s,
           (SELECT MIN(es.employee_id) FROM employee_skills es WHERE es.skill_id = c.skill_id) AS employee_id
      FROM ticket_tipo_config c
),
cliente AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY email) - 1 AS i
      FROM admin_users
     WHERE email LIKE 'cliente_@edu.com'
),
base AS (
    SELECT d.d,
           g.segment,
           g.label,
           g.default_priority,
           g.sla_minutes,
           g.employee_id,
           d.d * 31 + g.s * 17 + q.n * 13 AS h,
           CASE WHEN d.d = 0
                THEN SYSTIMESTAMP - NUMTODSINTERVAL(10 + q.n * 3, 'MINUTE')
                ELSE SYSTIMESTAMP - NUMTODSINTERVAL(d.d, 'DAY') - NUMTODSINTERVAL(60 + q.n * 240, 'MINUTE')
           END AS criado
      FROM dia d
     CROSS JOIN segmento g
     CROSS JOIN seq q
     WHERE q.n <= CASE
                      WHEN d.d = 0 AND g.segment = 'PROBLEMA_PEDIDO' THEN 12
                      WHEN d.d = 0 THEN 3
                      ELSE 2 + MOD(d.d * 7 + g.s * 3, 4)
                  END
),
marcado AS (
    SELECT b.*,
           CASE WHEN b.d >= 3 AND MOD(b.h, 10) = 0 THEN 1 ELSE 0 END AS violado,
           CASE WHEN b.d >= 3 AND MOD(b.h, 20) = 0 THEN 1 ELSE 0 END AS escalado,
           CASE WHEN b.d = 0 THEN 2 ELSE 5 + MOD(b.h, 40) END AS min_assumir
      FROM base b
),
tempo AS (
    SELECT m.*,
           CASE
               WHEN m.d = 0 THEN 6
               WHEN m.violado = 1 THEN m.sla_minutes + 30 + MOD(m.h, 90)
               ELSE m.min_assumir + LEAST(m.sla_minutes - 60, 20 + MOD(m.h * 13, 300))
           END AS min_resolver,
           CASE WHEN m.d = 0 THEN 2 ELSE 60 END AS min_fechar
      FROM marcado m
)
SELECT c.id,
       t.segment,
       'Chamado do histórico de demonstração (' || t.label || ').',
       CASE WHEN MOD(t.h, 7) = 0 THEN 'CHATBOT_IA' ELSE 'APP' END,
       'FECHADO',
       CASE WHEN t.escalado = 1 THEN 'CRITICA' ELSE t.default_priority END,
       t.employee_id,
       t.criado,
       t.criado + NUMTODSINTERVAL(t.sla_minutes, 'MINUTE'),
       t.criado,
       t.criado + NUMTODSINTERVAL(t.min_resolver + t.min_fechar, 'MINUTE'),
       t.criado + NUMTODSINTERVAL(t.min_assumir, 'MINUTE'),
       t.criado + NUMTODSINTERVAL(t.min_resolver, 'MINUTE'),
       t.criado + NUMTODSINTERVAL(t.min_resolver + t.min_fechar, 'MINUTE')
  FROM tempo t
  JOIN cliente c ON c.i = MOD(t.h, 5);

-- Trilha mínima de cada ticket do histórico. Os escalados são os únicos com
-- prioridade CRITICA (nenhum segmento nasce CRITICA).
INSERT INTO ticket_events (ticket_id, type, from_status, to_status, created_at)
SELECT t.id, 'ABERTO', NULL, 'ABERTO', t.created_at
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, detail, created_at)
SELECT t.id, 'ESCALADO', 'EM_ATENDIMENTO', 'ESCALADO', t.assigned_employee_id, 'SLA estourado',
       t.sla_due_at + NUMTODSINTERVAL(1, 'MINUTE')
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com'
   AND t.priority = 'CRITICA';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, employee_id, created_at)
SELECT t.id, 'RESOLVIDO', 'EM_ATENDIMENTO', 'RESOLVIDO', t.assigned_employee_id, t.resolved_at
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com';

INSERT INTO ticket_events (ticket_id, type, from_status, to_status, created_at)
SELECT t.id, 'FECHADO', 'RESOLVIDO', 'FECHADO', t.closed_at
  FROM tickets t
  JOIN admin_users u ON u.id = t.user_id
 WHERE u.email LIKE 'cliente_@edu.com';
