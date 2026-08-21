ALTER TABLE products
ADD COLUMN price NUMERIC(10,2) NOT NULL DEFAULT 0.00;

ALTER TABLE products
ADD CONSTRAINT products_price_check
CHECK (price >= 0);

