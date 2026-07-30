-- Phase 1-05 — Top-3 Orders per Customer, Four Ways
-- 注意：20 萬筆，建立需要幾秒鐘。資料量小的話 EXPLAIN 看不出差異。
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    amount      NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL
);

INSERT INTO customers (name)
SELECT 'customer_' || g FROM generate_series(1, 200) g;

INSERT INTO orders (customer_id, amount, created_at)
SELECT (random() * 199 + 1)::INT,
       (random() * 1000)::NUMERIC(10,2),
       NOW() - (random() * INTERVAL '365 days')
FROM generate_series(1, 200000);

CREATE INDEX idx_orders_customer_created ON orders (customer_id, created_at DESC);

ANALYZE customers;
ANALYZE orders;
