-- Contas do e2e do app (mobile-flutter/e2e). Só entram na stack efêmera do e2e,
-- pela location filesystem:/e2e/fixtures; nunca no Compose de desenvolvimento.
-- Senhas (BCrypt, custo 10): usuario123 e atendente123, as mesmas do seed.
-- Os tickets são criados pelos próprios testes.
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Usuário', 'e2e.usuario@edu.com',
        '$2a$10$qHbwNXNi4A7vDJ/ttRw4JO2iv9k1JrqHhzH0NkRbqjkSvHuJu/QlC', 'USER');
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Atendente', 'e2e.dev@edu.com',
        '$2a$10$fm/X5dFA8iXq6/A3wB8qAO64pYeAqBoo7zY.lAkygJi02/4RolrSS', 'EMPLOYEE');

-- Começa OFFLINE (padrão da tabela); o teste o põe ONLINE quando precisa.
INSERT INTO employees (user_id)
SELECT id FROM admin_users WHERE email = 'e2e.dev@edu.com';

INSERT INTO employee_skills (employee_id, skill_id)
SELECT e.id, s.id
  FROM employees e
  JOIN admin_users u ON u.id = e.user_id
  JOIN skills s ON s.code = 'DESENVOLVEDOR'
 WHERE u.email = 'e2e.dev@edu.com';

-- FAQ do Mentor Edu: 2 itens (os 12 do seed de demonstração não entram aqui).
-- Ids fixos para o teste achar a opção "faq:9001". Palavras-chave como na V5:
-- minúsculas, sem acento, radicais. "Esqueci a senha e não consigo entrar"
-- casa só com o 9001 (senha, entrar).
INSERT INTO chatbot_faq (id, segment, question, answer, sort_order)
VALUES (9001, 'DEFEITO_APP', 'Não consigo entrar no app',
        'E2E: confira o e-mail e a senha na tela de entrada.', 1);
INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (9001, 'entrar');
INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (9001, 'senha');
INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (9001, 'login');

INSERT INTO chatbot_faq (id, segment, question, answer, sort_order)
VALUES (9002, 'PROBLEMA_PEDIDO', 'Qual o prazo de entrega?',
        'E2E: o prazo de entrega aparece no resumo do pedido.', 1);
INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (9002, 'prazo');
INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (9002, 'entreg');
INSERT INTO chatbot_faq_keywords (faq_id, keyword) VALUES (9002, 'demor');
