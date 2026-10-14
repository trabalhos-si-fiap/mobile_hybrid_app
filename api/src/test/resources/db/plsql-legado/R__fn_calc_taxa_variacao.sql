-- Variação percentual de um indicador entre o período atual e o anterior,
-- com 1 casa decimal. Sem base de comparação (anterior nulo ou zero) ou sem
-- valor atual, devolve nulo: "sem base" é diferente de "0%".
CREATE OR REPLACE FUNCTION FN_CALC_TAXA_VARIACAO (
    p_atual    IN NUMBER,
    p_anterior IN NUMBER
) RETURN NUMBER DETERMINISTIC
IS
BEGIN
    IF p_atual IS NULL OR p_anterior IS NULL OR p_anterior = 0 THEN
        RETURN NULL;
    END IF;

    RETURN ROUND((p_atual - p_anterior) / p_anterior * 100, 1);
END FN_CALC_TAXA_VARIACAO;
/
