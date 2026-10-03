-- Revisão das palavras-chave do FAQ de demonstração para o casamento pelo
-- começo da palavra e por peso (V10). V6 e V7 já foram aplicados no banco da
-- demonstração e seed aplicado não é editado (o Flyway confere o checksum),
-- então a revisão vem numa versão nova.

-- Genéricas valem 1: aparecem também em frases de outras dúvidas. Com peso
-- igual, "entregaram faltando" empatava "entreg" com "faltand" e caía no
-- prazo de entrega, e "o que sugeri" empatava "suger" com "sugeri" e caía em
-- "Como enviar uma sugestão?". "acompanh" e "andament" sozinhos são do
-- pedido; na sugestão vêm junto de "sugest" ou "sugeri".
UPDATE chatbot_faq_keywords
   SET weight = 1
 WHERE (faq_id, keyword) IN (
       SELECT f.id, g.keyword
         FROM chatbot_faq f
         JOIN (VALUES ('PROBLEMA_PEDIDO', 1, 'prazo'), ('PROBLEMA_PEDIDO', 1, 'entreg'),
                      ('PROBLEMA_PEDIDO', 1, 'demor'), ('PROBLEMA_PEDIDO', 1, 'atras'),
                      ('PROBLEMA_PEDIDO', 3, 'transportador'),
                      ('DEFEITO_APP', 1, 'acess'), ('DEFEITO_APP', 4, 'atualiz'),
                      ('FEEDBACK_SUGESTAO', 1, 'sugest'), ('FEEDBACK_SUGESTAO', 1, 'suger'),
                      ('FEEDBACK_SUGESTAO', 2, 'sugest'), ('FEEDBACK_SUGESTAO', 2, 'acompanh'),
                      ('FEEDBACK_SUGESTAO', 2, 'andament'),
                      ('FEEDBACK_SUGESTAO', 3, 'sugest')) g (segment, sort_order, keyword)
           ON g.segment = f.segment AND g.sort_order = f.sort_order);

-- "faltand" e "faltou" não pegavam "faltaram" nem "falta": fica um radical só.
DELETE FROM chatbot_faq_keywords
 WHERE keyword IN ('faltand', 'faltou')
   AND faq_id = (SELECT id FROM chatbot_faq WHERE segment = 'PROBLEMA_PEDIDO' AND sort_order = 4);

-- Frases reais que não casavam nada ou caíam no item errado: "Quando chega
-- meu pedido?", "Cadê meu pedido?", "Como acompanho meu pedido?", "Faltaram
-- itens", "O app não abre" (o "abre" volta com peso 1, então "A câmera não
-- abre" continua na câmera), "O app está travando", "Quero sugerir". Com o
-- casamento pelo começo da palavra, "atualiz" e "instal" não casam mais
-- dentro de "desatualizado" e "reinstalar", que ganham radical próprio.
INSERT INTO chatbot_faq_keywords (faq_id, keyword, weight)
SELECT f.id, k.keyword, k.weight
  FROM chatbot_faq f
  JOIN (VALUES ('PROBLEMA_PEDIDO', 1, 'cheg', 1),
               ('PROBLEMA_PEDIDO', 3, 'cade', 1), ('PROBLEMA_PEDIDO', 3, 'acompanh', 2),
               ('PROBLEMA_PEDIDO', 3, 'andament', 2),
               ('PROBLEMA_PEDIDO', 4, 'falt', 2), ('PROBLEMA_PEDIDO', 4, 'itens', 2),
               ('DEFEITO_APP', 1, 'abre', 1),
               ('DEFEITO_APP', 4, 'trav', 2), ('DEFEITO_APP', 4, 'desatualiz', 2),
               ('DEFEITO_APP', 4, 'reinstal', 2),
               ('FEEDBACK_SUGESTAO', 1, 'sugerir', 2)) k (segment, sort_order, keyword, weight)
    ON k.segment = f.segment AND k.sort_order = f.sort_order;
