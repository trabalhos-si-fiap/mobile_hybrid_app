-- Contas do e2e do painel (web-angular/e2e). Só entram na stack efêmera do e2e,
-- pela location filesystem:/e2e/fixtures; nunca no Compose de desenvolvimento.
-- Senhas (BCrypt, custo 10): usuario123, atendente123 e admin123, as mesmas do seed.
-- Os tickets são criados pelos próprios testes, pela API.
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Usuário', 'e2e.usuario@edu.com',
        '$2a$10$qHbwNXNi4A7vDJ/ttRw4JO2iv9k1JrqHhzH0NkRbqjkSvHuJu/QlC', 'USER');
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Atendente', 'e2e.dev@edu.com',
        '$2a$10$fm/X5dFA8iXq6/A3wB8qAO64pYeAqBoo7zY.lAkygJi02/4RolrSS', 'EMPLOYEE');
INSERT INTO admin_users (name, email, password, role)
VALUES ('E2E Admin', 'e2e.admin@edu.com',
        '$2a$10$EZL0gu4l/t1ikpqn5tR7B.zTJmed6GmoYDDcQIgMz2A9xRvzhse2C', 'ADMIN');

-- Os dois começam OFFLINE (padrão da tabela). O ADMIN não tem skill, para
-- nunca receber tickets pelo roteamento.
INSERT INTO employees (user_id)
SELECT id FROM admin_users WHERE email IN ('e2e.dev@edu.com', 'e2e.admin@edu.com');

INSERT INTO employee_skills (employee_id, skill_id)
SELECT e.id, s.id
  FROM employees e
  JOIN admin_users u ON u.id = e.user_id
  JOIN skills s ON s.code = 'DESENVOLVEDOR'
 WHERE u.email = 'e2e.dev@edu.com';
