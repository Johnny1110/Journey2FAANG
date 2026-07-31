-- Phase 1-01 — The NULL That Ate Your Results
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT,                    -- 可為 NULL：訪客結帳沒有帳號
    amount      NUMERIC(10,2) NOT NULL,
    created_at  DATE NOT NULL
);

INSERT INTO customers (id, name) VALUES
(1, 'Alice'), (2, 'Bob'), (3, 'Carol'), (4, 'Dave'), (5, 'Eve'), (6, 'Frank');

INSERT INTO orders (id, customer_id, amount, created_at) VALUES
(101, 1,    250.00,  '2026-01-05'),
(102, 2,     99.00,  '2026-01-07'),
(103, 2,   1200.00,  '2026-02-11'),
(104, NULL,  45.00,  '2026-02-14'),    -- 訪客結帳
(105, 3,   3000.00,  '2026-03-02'),
(106, NULL, 780.00,  '2026-03-19');    -- 訪客結帳
