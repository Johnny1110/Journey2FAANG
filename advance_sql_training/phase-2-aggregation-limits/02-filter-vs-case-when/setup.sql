-- Phase 2-02 — FILTER vs CASE WHEN
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL,
    status      VARCHAR(20),          -- 可為 NULL：舊資料沒有狀態欄位
    amount      NUMERIC(10,2) NOT NULL,
    paid_with   VARCHAR(20),          -- 可為 NULL：未付款
    created_at  DATE NOT NULL
);

INSERT INTO orders (id, customer_id, status, amount, paid_with, created_at) VALUES
(1,  1, 'completed', 100.00, 'card',   '2026-03-01'),
(2,  1, 'completed', 250.00, 'card',   '2026-03-02'),
(3,  2, 'completed', 300.00, 'paypal', '2026-03-03'),
(4,  3, 'completed',  50.00, 'card',   '2026-03-04'),
(5,  2, 'pending',   120.00, 'card',   '2026-03-05'),
(6,  4, 'pending',    80.00, 'paypal', '2026-03-06'),
(7,  1, 'pending',   200.00, NULL,     '2026-03-07'),
(8,  3, 'cancelled', 400.00, 'card',   '2026-03-08'),
(9,  5, 'cancelled',  60.00, NULL,     '2026-03-09'),
(10, 4, NULL,         90.00, 'card',   '2026-03-10');
