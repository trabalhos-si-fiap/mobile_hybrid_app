-- Casa o texto livre do usuário com o FAQ do chatbot. Uma palavra-chave
-- (radical sem acento) casa quando alguma palavra do texto normalizado começa
-- por ela; cada item ativo soma os pesos das que casaram e vence o de maior
-- soma. Empate: o do segmento da conversa, depois o menor sort_order, depois
-- o menor id. Sem nenhuma palavra casada, nulo.
CREATE OR REPLACE FUNCTION FN_CHATBOT_RESPOSTA (
    p_texto   IN VARCHAR2,
    p_segment IN VARCHAR2 DEFAULT NULL
) RETURN chatbot_faq.id%TYPE
IS
    v_texto  VARCHAR2(32767);
    v_faq_id chatbot_faq.id%TYPE;
BEGIN
    IF TRIM(p_texto) IS NULL THEN
        RETURN NULL;
    END IF;

    -- O espaço na frente deixa toda palavra precedida de um espaço: buscar
    -- ' ' || keyword só acha o radical no começo de uma palavra ("resenha" não
    -- casa "senha").
    v_texto := ' ' || REGEXP_REPLACE(
                   TRANSLATE(LOWER(p_texto), 'áàâãäéèêëíìîïóòôõöúùûüç', 'aaaaaeeeeiiiiooooouuuuc'),
                   '[^a-z0-9]', ' ');

    SELECT id
      INTO v_faq_id
      FROM (SELECT f.id
              FROM chatbot_faq f
              JOIN chatbot_faq_keywords k ON k.faq_id = f.id
             WHERE f.active = TRUE
               AND INSTR(v_texto, ' ' || k.keyword) > 0
             GROUP BY f.id, f.segment, f.sort_order
             ORDER BY SUM(k.weight) DESC,
                      CASE WHEN f.segment = p_segment THEN 0 ELSE 1 END,
                      f.sort_order,
                      f.id
             FETCH FIRST 1 ROW ONLY);

    RETURN v_faq_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END FN_CHATBOT_RESPOSTA;
/
