-- Resumo do atendimento para o dashboard. Devolve três cursores:
--   p_kpis      indicadores da janela atual [ref - N dias, ref) e da anterior
--               [ref - 2N, ref - N), com a variação (FN_CALC_TAXA_VARIACAO);
--   p_segmentos os mesmos indicadores por segmento;
--   p_anomalias volume das últimas 24 h de cada segmento contra as janelas de
--               24 h dos 28 dias anteriores (z-score).
-- Só lê. p_referencia existe para testes determinísticos (nula = agora).
CREATE OR REPLACE PROCEDURE PR_RESUMO_DASHBOARD (
    p_dias       IN  NUMBER,
    p_referencia IN  TIMESTAMP WITH TIME ZONE,
    p_kpis       OUT SYS_REFCURSOR,
    p_segmentos  OUT SYS_REFCURSOR,
    p_anomalias  OUT SYS_REFCURSOR
)
IS
    TYPE t_medidas IS RECORD (
        abertos         NUMBER,
        abertos_app     NUMBER,
        abertos_chatbot NUMBER,
        resolvidos      NUMBER,
        sla_pct         NUMBER,
        resolucao_h     NUMBER,
        assumir_min     NUMBER,
        escalados       NUMBER
    );

    v_ref      TIMESTAMP WITH TIME ZONE;
    v_ini      TIMESTAMP WITH TIME ZONE;
    v_ini_ant  TIMESTAMP WITH TIME ZONE;
    v_atual    t_medidas;
    v_anterior t_medidas;
    v_backlog  NUMBER;

    -- Durações em minutos/horas via DATE em UTC: respeita o fuso de cada
    -- coluna e não estoura como um INTERVAL DAY TO SECOND acima de 99 dias.
    PROCEDURE medir (
        p_ini     IN  TIMESTAMP WITH TIME ZONE,
        p_fim     IN  TIMESTAMP WITH TIME ZONE,
        p_medidas OUT t_medidas
    )
    IS
    BEGIN
        SELECT COUNT(*),
               COUNT(CASE WHEN channel = 'APP' THEN 1 END),
               COUNT(CASE WHEN channel = 'CHATBOT_IA' THEN 1 END)
          INTO p_medidas.abertos, p_medidas.abertos_app, p_medidas.abertos_chatbot
          FROM tickets
         WHERE created_at >= p_ini
           AND created_at < p_fim;

        SELECT COUNT(*),
               ROUND(100 * AVG(CASE WHEN FN_STATUS_SLA_TICKET(id) = 'CUMPRIDO' THEN 1 ELSE 0 END), 1),
               ROUND(AVG((CAST(SYS_EXTRACT_UTC(resolved_at) AS DATE)
                        - CAST(SYS_EXTRACT_UTC(created_at) AS DATE)) * 24), 1)
          INTO p_medidas.resolvidos, p_medidas.sla_pct, p_medidas.resolucao_h
          FROM tickets
         WHERE status IN ('RESOLVIDO', 'FECHADO')
           AND resolved_at >= p_ini
           AND resolved_at < p_fim;

        SELECT ROUND(AVG((CAST(SYS_EXTRACT_UTC(assumed_at) AS DATE)
                        - CAST(SYS_EXTRACT_UTC(created_at) AS DATE)) * 1440), 1)
          INTO p_medidas.assumir_min
          FROM tickets
         WHERE assumed_at >= p_ini
           AND assumed_at < p_fim;

        SELECT COUNT(*)
          INTO p_medidas.escalados
          FROM ticket_events
         WHERE type = 'ESCALADO'
           AND created_at >= p_ini
           AND created_at < p_fim;
    END medir;
BEGIN
    IF p_dias IS NULL OR p_dias NOT IN (7, 30, 90) THEN
        RAISE_APPLICATION_ERROR(-20004, 'Período inválido: ' || p_dias);
    END IF;

    v_ref     := NVL(p_referencia, SYSTIMESTAMP);
    v_ini     := v_ref - NUMTODSINTERVAL(p_dias, 'DAY');
    v_ini_ant := v_ref - NUMTODSINTERVAL(2 * p_dias, 'DAY');

    medir(v_ini, v_ref, v_atual);
    medir(v_ini_ant, v_ini, v_anterior);

    SELECT COUNT(*)
      INTO v_backlog
      FROM tickets
     WHERE created_at < v_ref
       AND status NOT IN ('RESOLVIDO', 'FECHADO');

    OPEN p_kpis FOR
        SELECT metrica, atual, anterior, FN_CALC_TAXA_VARIACAO(atual, anterior) AS variacao
          FROM (SELECT 1 AS ordem, CAST('ABERTOS' AS VARCHAR2(30)) AS metrica,
                       v_atual.abertos AS atual, v_anterior.abertos AS anterior FROM dual
                UNION ALL SELECT 2, 'RESOLVIDOS', v_atual.resolvidos, v_anterior.resolvidos FROM dual
                UNION ALL SELECT 3, 'BACKLOG', v_backlog, NULL FROM dual
                UNION ALL SELECT 4, 'SLA_CUMPRIDO_PCT', v_atual.sla_pct, v_anterior.sla_pct FROM dual
                UNION ALL SELECT 5, 'ESCALADOS', v_atual.escalados, v_anterior.escalados FROM dual
                UNION ALL SELECT 6, 'TEMPO_MEDIO_ASSUMIR_MIN', v_atual.assumir_min, v_anterior.assumir_min FROM dual
                UNION ALL SELECT 7, 'TEMPO_MEDIO_RESOLUCAO_H', v_atual.resolucao_h, v_anterior.resolucao_h FROM dual
                UNION ALL SELECT 8, 'ABERTOS_APP', v_atual.abertos_app, v_anterior.abertos_app FROM dual
                UNION ALL SELECT 9, 'ABERTOS_CHATBOT', v_atual.abertos_chatbot, v_anterior.abertos_chatbot FROM dual)
         ORDER BY ordem;

    OPEN p_segmentos FOR
        WITH base AS (
            SELECT c.segment,
                   c.label,
                   DECODE(c.segment, 'DEFEITO_APP', 1, 'PROBLEMA_PEDIDO', 2, 3) AS ordem,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment
                       AND t.created_at >= v_ini AND t.created_at < v_ref) AS abertos,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment
                       AND t.created_at >= v_ini_ant AND t.created_at < v_ini) AS abertos_anterior,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini AND t.resolved_at < v_ref) AS resolvidos,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini_ant AND t.resolved_at < v_ini) AS resolvidos_anterior,
                   (SELECT ROUND(100 * AVG(CASE WHEN FN_STATUS_SLA_TICKET(t.id) = 'CUMPRIDO' THEN 1 ELSE 0 END), 1)
                      FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini AND t.resolved_at < v_ref) AS sla_pct,
                   (SELECT ROUND(100 * AVG(CASE WHEN FN_STATUS_SLA_TICKET(t.id) = 'CUMPRIDO' THEN 1 ELSE 0 END), 1)
                      FROM tickets t
                     WHERE t.segment = c.segment AND t.status IN ('RESOLVIDO', 'FECHADO')
                       AND t.resolved_at >= v_ini_ant AND t.resolved_at < v_ini) AS sla_pct_anterior,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment AND t.created_at < v_ref
                       AND t.status NOT IN ('RESOLVIDO', 'FECHADO')) AS backlog
              FROM ticket_tipo_config c
        )
        SELECT segment, label,
               abertos, abertos_anterior, FN_CALC_TAXA_VARIACAO(abertos, abertos_anterior) AS abertos_variacao,
               resolvidos, resolvidos_anterior,
               FN_CALC_TAXA_VARIACAO(resolvidos, resolvidos_anterior) AS resolvidos_variacao,
               sla_pct, sla_pct_anterior, FN_CALC_TAXA_VARIACAO(sla_pct, sla_pct_anterior) AS sla_pct_variacao,
               backlog
          FROM base
         ORDER BY ordem;

    OPEN p_anomalias FOR
        WITH inicio AS (
            SELECT MIN(created_at) AS primeiro
              FROM tickets
             WHERE created_at < v_ref
        ),
        janela AS (
            SELECT LEVEL - 1 AS k,
                   v_ref - NUMTODSINTERVAL(LEVEL, 'DAY') AS ini,
                   v_ref - NUMTODSINTERVAL(LEVEL - 1, 'DAY') AS fim
              FROM dual
           CONNECT BY LEVEL <= 29
        ),
        contagem AS (
            SELECT c.segment,
                   j.k,
                   (SELECT COUNT(*) FROM tickets t
                     WHERE t.segment = c.segment
                       AND t.created_at >= j.ini AND t.created_at < j.fim) AS abertos,
                   CASE WHEN j.k > 0 AND j.ini >= (SELECT primeiro FROM inicio) THEN 1 ELSE 0 END AS conta
              FROM ticket_tipo_config c
             CROSS JOIN janela j
        ),
        estatistica AS (
            SELECT segment,
                   MAX(CASE WHEN k = 0 THEN abertos END) AS atual,
                   COUNT(CASE WHEN conta = 1 THEN 1 END) AS janelas,
                   AVG(CASE WHEN conta = 1 THEN abertos END) AS media,
                   STDDEV(CASE WHEN conta = 1 THEN abertos END) AS desvio
              FROM contagem
             GROUP BY segment
        ),
        resultado AS (
            SELECT c.segment,
                   c.label,
                   DECODE(c.segment, 'DEFEITO_APP', 1, 'PROBLEMA_PEDIDO', 2, 3) AS ordem,
                   e.atual,
                   e.janelas,
                   e.media AS media_bruta,
                   e.desvio AS desvio_bruto,
                   CASE WHEN e.janelas >= 7 THEN ROUND(e.media, 2) END AS media,
                   CASE WHEN e.janelas >= 7 THEN ROUND(e.desvio, 2) END AS desvio,
                   CASE WHEN e.janelas >= 7 AND e.desvio > 0
                        THEN ROUND((e.atual - e.media) / e.desvio, 2) END AS z_score
              FROM ticket_tipo_config c
              JOIN estatistica e ON e.segment = c.segment
        )
        SELECT segment, label, atual, media, desvio, z_score,
               CASE
                   WHEN janelas < 7 THEN 'SEM_HISTORICO'
                   WHEN desvio_bruto = 0 THEN CASE WHEN atual <> media_bruta THEN 'ANOMALIA' ELSE 'NORMAL' END
                   WHEN ABS(z_score) >= 2 THEN 'ANOMALIA'
                   ELSE 'NORMAL'
               END AS situacao,
               janelas
          FROM resultado
         ORDER BY ordem;
END PR_RESUMO_DASHBOARD;
/
