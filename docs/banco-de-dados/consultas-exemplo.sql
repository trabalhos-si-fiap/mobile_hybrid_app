-- Consultas de exemplo: as functions e procedures PL/SQL do Edu em uso.
--
-- Mostra cada objeto de api/src/main/resources/db/plsql/ dentro de consultas
-- reais sobre o seed de demonstração (V2, V4, V6, V7, V9 e V11). As procedures que
-- gravam dados rodam e são desfeitas com ROLLBACK: o script não deixa
-- alteração no banco.
--
-- Como rodar, com a stack no ar (em api/):
--   docker exec -i edu-admin-oracle sqlplus -s edu_admin/edu_admin@FREEPDB1 \
--     < ../docs/banco-de-dados/consultas-exemplo.sql
-- A saída de referência está em consultas-exemplo.saida.txt.
--
-- Atenção: o sqlplus encerra um comando em toda linha que termina em ponto e
-- vírgula, mesmo dentro de comentário. Os comentários deste arquivo evitam isso.

SET LINESIZE 160
SET PAGESIZE 200
SET FEEDBACK OFF
SET TRIMSPOOL ON
SET TRIMOUT ON
SET TAB OFF
SET SERVEROUTPUT ON
SET DEFINE OFF
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';
ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT = 'DD/MM/YYYY HH24:MI TZR';

COLUMN tabela FORMAT A24
COLUMN linhas FORMAT 99990
COLUMN segment FORMAT A18
COLUMN status FORMAT A15
COLUMN priority FORMAT A8
COLUMN prazo FORMAT A11
COLUMN sla FORMAT A10
COLUMN skill FORMAT A18
COLUMN proximo_atendente FORMAT A22
COLUMN frase FORMAT A40
COLUMN pergunta_do_faq FORMAT A54
COLUMN metrica FORMAT A24
COLUMN label FORMAT A20 TRUNCATED
COLUMN situacao FORMAT A14
COLUMN type FORMAT A20
COLUMN detail FORMAT A44
COLUMN title FORMAT A26
COLUMN atual FORMAT 99990D9
COLUMN anterior FORMAT 99990D9
COLUMN variacao FORMAT 9990D9
COLUMN variacao_pct FORMAT 9990D9
COLUMN abertos FORMAT 9990 HEADING 'ABERTOS'
COLUMN abertos_anterior FORMAT 9990 HEADING 'AB_ANT'
COLUMN abertos_variacao FORMAT 9990D9 HEADING 'AB_VAR%'
COLUMN resolvidos FORMAT 9990 HEADING 'RESOLV'
COLUMN resolvidos_anterior FORMAT 9990 HEADING 'RES_ANT'
COLUMN resolvidos_variacao FORMAT 9990D9 HEADING 'RES_VAR%'
COLUMN sla_pct FORMAT 990D9 HEADING 'SLA%'
COLUMN sla_pct_anterior FORMAT 990D9 HEADING 'SLA_ANT'
COLUMN sla_pct_variacao FORMAT 9990D9 HEADING 'SLA_VAR%'
COLUMN backlog FORMAT 9990 HEADING 'BACKLOG'
COLUMN media FORMAT 990D99
COLUMN desvio FORMAT 990D99
COLUMN z_score FORMAT 990D99
COLUMN janelas FORMAT 990

PROMPT
PROMPT ==== 0. Dados importados: linhas por tabela ====
SELECT 'admin_users' AS tabela, COUNT(*) AS linhas FROM admin_users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'inventories', COUNT(*) FROM inventories
UNION ALL SELECT 'inventory_adjustments', COUNT(*) FROM inventory_adjustments
UNION ALL SELECT 'carriers', COUNT(*) FROM carriers
UNION ALL SELECT 'carrier_occurrences', COUNT(*) FROM carrier_occurrences
UNION ALL SELECT 'skills', COUNT(*) FROM skills
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'employee_skills', COUNT(*) FROM employee_skills
UNION ALL SELECT 'ticket_tipo_config', COUNT(*) FROM ticket_tipo_config
UNION ALL SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL SELECT 'ticket_messages', COUNT(*) FROM ticket_messages
UNION ALL SELECT 'ticket_attachments', COUNT(*) FROM ticket_attachments
UNION ALL SELECT 'ticket_events', COUNT(*) FROM ticket_events
UNION ALL SELECT 'notifications', COUNT(*) FROM notifications
UNION ALL SELECT 'chatbot_faq', COUNT(*) FROM chatbot_faq
UNION ALL SELECT 'chatbot_faq_keywords', COUNT(*) FROM chatbot_faq_keywords
UNION ALL SELECT 'chatbot_conversations', COUNT(*) FROM chatbot_conversations
UNION ALL SELECT 'chatbot_messages', COUNT(*) FROM chatbot_messages;

PROMPT
PROMPT ==== 1. FN_STATUS_SLA_TICKET: SLA de cada ticket em aberto ====
SELECT t.id, t.segment, t.status, t.priority,
       TO_CHAR(t.sla_due_at, 'DD/MM HH24:MI') AS prazo,
       FN_STATUS_SLA_TICKET(t.id) AS sla
  FROM tickets t
 WHERE t.status NOT IN ('RESOLVIDO', 'FECHADO')
 ORDER BY t.id;

PROMPT
PROMPT ==== 2. FN_STATUS_SLA_TICKET: todos os tickets por status de SLA ====
SELECT FN_STATUS_SLA_TICKET(id) AS sla, COUNT(*) AS tickets
  FROM tickets
 GROUP BY FN_STATUS_SLA_TICKET(id)
 ORDER BY tickets DESC;

PROMPT
PROMPT ==== 3. FN_CALC_TAXA_VARIACAO: abertos por segmento, ultimos 7 dias x 7 anteriores ====
SELECT segment, atual, anterior, FN_CALC_TAXA_VARIACAO(atual, anterior) AS variacao_pct
  FROM (SELECT c.segment,
               (SELECT COUNT(*) FROM tickets t
                 WHERE t.segment = c.segment
                   AND t.created_at >= SYSTIMESTAMP - INTERVAL '7' DAY) AS atual,
               (SELECT COUNT(*) FROM tickets t
                 WHERE t.segment = c.segment
                   AND t.created_at >= SYSTIMESTAMP - INTERVAL '14' DAY
                   AND t.created_at < SYSTIMESTAMP - INTERVAL '7' DAY) AS anterior
          FROM ticket_tipo_config c)
 ORDER BY segment;

PROMPT
PROMPT ==== 4. FN_PROXIMO_ATENDENTE: quem recebe o proximo ticket de cada skill ====
PROMPT (no seed todos estao OFFLINE, o UPDATE abaixo e desfeito pelo ROLLBACK)
UPDATE employees
   SET presence = 'ONLINE'
 WHERE user_id IN (SELECT id FROM admin_users
                    WHERE email IN ('dev@edu.com', 'logistica@edu.com', 'produto@edu.com'));
SELECT s.code AS skill, u.name AS proximo_atendente
  FROM skills s
  LEFT JOIN employees e ON e.id = FN_PROXIMO_ATENDENTE(s.id)
  LEFT JOIN admin_users u ON u.id = e.user_id
 ORDER BY s.code;
ROLLBACK;

PROMPT
PROMPT ==== 5. FN_CHATBOT_RESPOSTA: texto livre do usuario x pergunta do FAQ ====
SELECT x.frase, NVL(f.question, '(sem casamento: vai para o atendente)') AS pergunta_do_faq
  FROM (SELECT 1 AS ordem, 'Qual o prazo de entrega do meu pedido?' AS frase FROM dual
        UNION ALL SELECT 2, 'Faltou um item na entrega' FROM dual
        UNION ALL SELECT 3, 'A camera nao abre no app' FROM dual
        UNION ALL SELECT 4, 'Quero mandar uma sugestao' FROM dual
        UNION ALL SELECT 5, 'O app esta muito lento hoje' FROM dual) x
  LEFT JOIN chatbot_faq f ON f.id = FN_CHATBOT_RESPOSTA(x.frase)
 ORDER BY x.ordem;

PROMPT
PROMPT ==== 6. PR_RESUMO_DASHBOARD: resumo dos ultimos 7 dias (tres cursores) ====
VARIABLE kpis REFCURSOR
VARIABLE segmentos REFCURSOR
VARIABLE anomalias REFCURSOR
EXEC PR_RESUMO_DASHBOARD(7, NULL, :kpis, :segmentos, :anomalias)
PROMPT -- p_kpis
PRINT kpis
PROMPT -- p_segmentos
PRINT segmentos
PROMPT -- p_anomalias
PRINT anomalias

PROMPT
PROMPT ==== 7. PR_ROTEAR_TICKET: abre um ticket e roteia (desfeito no fim) ====
DECLARE
    v_usuario   admin_users.id%TYPE;
    v_ticket    tickets.id%TYPE;
    v_atendente employees.id%TYPE;
    v_nome      admin_users.name%TYPE;
BEGIN
    UPDATE employees
       SET presence = 'ONLINE'
     WHERE user_id = (SELECT id FROM admin_users WHERE email = 'dev@edu.com');

    SELECT id INTO v_usuario FROM admin_users WHERE email = 'usuario@edu.com';
    INSERT INTO tickets (user_id, segment, description)
    VALUES (v_usuario, 'DEFEITO_APP', 'Exemplo: o app fecha ao abrir o carrinho.')
    RETURNING id INTO v_ticket;

    PR_ROTEAR_TICKET(v_ticket, v_atendente);

    SELECT u.name INTO v_nome
      FROM employees e JOIN admin_users u ON u.id = e.user_id
     WHERE e.id = v_atendente;
    DBMS_OUTPUT.PUT_LINE('Ticket #' || v_ticket || ' roteado para ' || v_nome);
END;
/
SELECT t.id, t.status, t.priority, TO_CHAR(t.sla_due_at, 'DD/MM HH24:MI') AS prazo
  FROM tickets t
 WHERE t.id = (SELECT MAX(id) FROM tickets);
SELECT e.type, e.detail
  FROM ticket_events e
 WHERE e.ticket_id = (SELECT MAX(id) FROM tickets);
SELECT n.type, n.title
  FROM notifications n
 WHERE n.ticket_id = (SELECT MAX(id) FROM tickets);
ROLLBACK;

PROMPT
PROMPT ==== 8. PR_ESCALAR_TICKET_CRITICO: escala os tickets com SLA estourado (desfeito no fim) ====
PROMPT (o job de SLA da API escala sozinho a cada minuto: o UPDATE vence o prazo
PROMPT  do ticket em atendimento so nesta transacao, para o exemplo ter o que escalar)
UPDATE tickets
   SET sla_due_at = SYSTIMESTAMP - INTERVAL '5' MINUTE
 WHERE id = (SELECT MIN(id) FROM tickets WHERE status = 'EM_ATENDIMENTO');
VARIABLE ultimo_evento NUMBER
EXEC SELECT MAX(id) INTO :ultimo_evento FROM ticket_events
DECLARE
    v_qtd NUMBER;
BEGIN
    PR_ESCALAR_TICKET_CRITICO(SYSTIMESTAMP, v_qtd);
    DBMS_OUTPUT.PUT_LINE(v_qtd || ' ticket(s) escalado(s)');
END;
/
SELECT e.ticket_id AS id, e.type, e.detail
  FROM ticket_events e
 WHERE e.id > :ultimo_evento;
ROLLBACK;
