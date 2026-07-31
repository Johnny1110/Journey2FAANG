-- Phase 3-01 — The LAST_VALUE That Lied
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    created_at  DATE NOT NULL
);
INSERT INTO orders (id, customer_id, amount, created_at) VALUES
(1, 1, 100.00, '2026-01-05'),
(2, 1, 250.00, '2026-02-10'),
(3, 1,  80.00, '2026-03-15'),
(4, 1, 600.00, '2026-04-20'),
(5, 2, 900.00, '2026-01-08'),
(6, 2, 150.00, '2026-02-14'),
(7, 3, 320.00, '2026-03-01');
