-- Phase 2-01 — One Query, Four Subtotals
DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    id      INT PRIMARY KEY,
    region  VARCHAR(20),              -- 可為 NULL：抓不到區域的線上訂單
    product VARCHAR(20) NOT NULL,
    amount  NUMERIC(10,2) NOT NULL
);

INSERT INTO sales (id, region, product, amount) VALUES
(1, 'APAC', 'A', 100.00),
(2, 'APAC', 'B', 200.00),
(3, 'EMEA', 'A', 150.00),
(4, 'EMEA', 'B',  50.00),
(5, NULL,   'A', 300.00),   -- 未知區域
(6, NULL,   'B', 100.00);   -- 未知區域
