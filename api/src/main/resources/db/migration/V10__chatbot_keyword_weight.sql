-- Peso de cada palavra-chave do FAQ: a FN_CHATBOT_RESPOSTA soma os pesos das
-- que casam com o texto. 2 é o normal; 1 é a palavra genérica, que aparece
-- também em frases de outras dúvidas ("entrega", "abre") e por isso não
-- decide sozinha contra uma palavra que aponta a dúvida. As linhas que já
-- existem ficam com 2.
ALTER TABLE chatbot_faq_keywords ADD (
    weight NUMBER(1) DEFAULT 2 NOT NULL
        CONSTRAINT CK_CHATBOT_KEYWORDS_WEIGHT CHECK (weight IN (1, 2))
);
