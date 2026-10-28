-- Contas do smoke test da stack de deploy (api/deploy). Só entram nessa stack,
-- pela location filesystem:/deploy/fixtures; nunca no Compose de
-- desenvolvimento. Senhas (BCrypt, custo 10): usuario123 e admin123, as mesmas
-- do seed e do e2e; o smoke.sh também as tem em claro.
-- O ADMIN não tem linha em employees: o dashboard só exige o papel.
INSERT INTO admin_users (name, email, password, role)
VALUES ('Smoke Usuário', 'smoke.usuario@edu.com',
        '$2a$10$qHbwNXNi4A7vDJ/ttRw4JO2iv9k1JrqHhzH0NkRbqjkSvHuJu/QlC', 'USER');
INSERT INTO admin_users (name, email, password, role)
VALUES ('Smoke Admin', 'smoke.admin@edu.com',
        '$2a$10$EZL0gu4l/t1ikpqn5tR7B.zTJmed6GmoYDDcQIgMz2A9xRvzhse2C', 'ADMIN');
