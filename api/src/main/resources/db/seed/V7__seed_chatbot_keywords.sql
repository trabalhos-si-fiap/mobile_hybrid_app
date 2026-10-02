-- Ajuste das palavras-chave do FAQ de demonstração. O V6 já foi aplicado no
-- banco da demonstração e seed aplicado não é editado (o Flyway confere o
-- checksum), então a correção vai numa versão nova.
-- "abre" fazia "A câmera não abre" cair no item de login; "item" faz "Faltou
-- um item na entrega" desempatar para o item de pedido faltando.

DELETE FROM chatbot_faq_keywords
 WHERE keyword = 'abre'
   AND faq_id = (SELECT id FROM chatbot_faq WHERE segment = 'DEFEITO_APP' AND sort_order = 1);

INSERT INTO chatbot_faq_keywords (faq_id, keyword)
SELECT f.id, 'item'
  FROM chatbot_faq f
 WHERE f.segment = 'PROBLEMA_PEDIDO' AND f.sort_order = 4;
