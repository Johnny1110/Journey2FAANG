-- Phase 1-02 — Price Tier Assignment
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS discount_tiers;

CREATE TABLE orders (
    id     INT PRIMARY KEY,
    amount NUMERIC(10,3) NOT NULL       -- 精度 3 位：(10,2) 會把 99.995 進位成 100.00
);

CREATE TABLE discount_tiers (
    tier_name  VARCHAR(20) PRIMARY KEY,
    min_amount NUMERIC(10,3) NOT NULL,
    max_amount NUMERIC(10,3),            -- NULL = 無上限
    discount   NUMERIC(4,3) NOT NULL
);

INSERT INTO discount_tiers (tier_name, min_amount, max_amount, discount) VALUES
('Bronze',      0.00,   99.99, 0.000),
('Silver',    100.00,  499.99, 0.050),
('Gold',      500.00, 1999.99, 0.100),
('Platinum', 2000.00,    NULL, 0.150);

INSERT INTO orders (id, amount) VALUES
(1,   45.000), (2,   99.990), (3,  100.000), (4,  250.000),
(5,  499.990), (6,  500.000), (7, 1999.990), (8, 2000.000),
(9, 5000.000), (10,  99.995),                -- 10 落在縫隙裡
(11, 750.000), (12, 999.990);

-- Part B 的 ops 誤改（做完 Part A 再執行）：
-- UPDATE discount_tiers SET max_amount = 999.99 WHERE tier_name = 'Silver';
