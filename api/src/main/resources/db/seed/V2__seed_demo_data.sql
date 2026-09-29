-- Massa de dados de demonstração (não roda no perfil de teste).
-- Os ids vêm da identity, e as FKs são resolvidas por chave natural
-- (e-mail da transportadora, SKU do produto), para não dessincronizar a
-- identity com ids explícitos.

INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('Rapidex Logística', 'São Paulo, SP', 'contato@rapidex.com.br', 2, 4.7, 96.50, 'ACTIVE');
INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('TotalFrete Express', 'Rio de Janeiro, RJ', 'ops@totalfrete.com.br', 3, 4.2, 89.80, 'ACTIVE');
INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('Nordeste Cargas', 'Fortaleza, CE', 'comercial@nordestecargas.com.br', 5, 3.8, 82.10, 'ACTIVE');
INSERT INTO carriers (name, location, email, average_delivery_days, rating, sla_percentage, status)
VALUES ('Sul Expresso', 'Porto Alegre, RS', 'atendimento@sulexpresso.com.br', 4, 4.0, 91.30, 'INACTIVE');

INSERT INTO carrier_occurrences (carrier_id, type, description)
SELECT id, 'DELIVERY_DELAY', 'Pedido #4521 com atraso de 2 dias por greve de rodoviários na SP-330.'
FROM carriers WHERE email = 'contato@rapidex.com.br';
INSERT INTO carrier_occurrences (carrier_id, type, description)
SELECT id, 'DAMAGE', 'Caixa do pedido #3870 chegou amassada. Cliente solicitou reenvio.'
FROM carriers WHERE email = 'ops@totalfrete.com.br';
INSERT INTO carrier_occurrences (carrier_id, type, description)
SELECT id, 'DELIVERY_FAILURE', 'Tentativa de entrega sem sucesso — endereço não localizado no pedido #5102.'
FROM carriers WHERE email = 'comercial@nordestecargas.com.br';

-- Quatro produtos abaixo do estoque mínimo e um normal.
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0001', 'Livro de Matemática Vol. 3', 'Material didático de álgebra avançada', 89.90, 10);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0002', 'Caderno Universitário 200fls', 'Caderno capa dura para anotações', 24.50, 20);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0003', 'Kit Canetas Coloridas 12un', 'Canetas para mapas mentais e estudos', 18.90, 15);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0004', 'Apostila Redação ENEM 2025', 'Guia completo de redação para o ENEM', 45.00, 8);
INSERT INTO products (sku, name, description, price, minimum_stock)
VALUES ('EDU-SEED0005', 'Borracha Branca Faber-Castell', 'Borracha de alta qualidade', 3.50, 5);

INSERT INTO inventories (product_id, quantity) SELECT id, 2  FROM products WHERE sku = 'EDU-SEED0001';
INSERT INTO inventories (product_id, quantity) SELECT id, 4  FROM products WHERE sku = 'EDU-SEED0002';
INSERT INTO inventories (product_id, quantity) SELECT id, 1  FROM products WHERE sku = 'EDU-SEED0003';
INSERT INTO inventories (product_id, quantity) SELECT id, 0  FROM products WHERE sku = 'EDU-SEED0004';
INSERT INTO inventories (product_id, quantity) SELECT id, 30 FROM products WHERE sku = 'EDU-SEED0005';

-- Senhas: admin123 e usuario123 (BCrypt, custo 10).
INSERT INTO admin_users (name, email, password, role)
VALUES ('Administrador Edu', 'admin@edu.com',
        '$2a$10$EZL0gu4l/t1ikpqn5tR7B.zTJmed6GmoYDDcQIgMz2A9xRvzhse2C', 'ADMIN');
INSERT INTO admin_users (name, email, password, role)
VALUES ('Usuário Demo', 'usuario@edu.com',
        '$2a$10$qHbwNXNi4A7vDJ/ttRw4JO2iv9k1JrqHhzH0NkRbqjkSvHuJu/QlC', 'USER');
