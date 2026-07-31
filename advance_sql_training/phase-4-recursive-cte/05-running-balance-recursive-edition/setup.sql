-- Phase 4-05 — The Running Balance, Recursive Edition
-- 和 Phase 3-07 完全相同的資料，方便對照
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
    id              INT PRIMARY KEY,
    owner           VARCHAR(30) NOT NULL,
    opening_balance NUMERIC(12,2) NOT NULL
);
CREATE TABLE transactions (
    id          INT PRIMARY KEY,
    account_id  INT NOT NULL REFERENCES accounts(id),
    amount      NUMERIC(12,2) NOT NULL,
    occurred_at TIMESTAMP NOT NULL
);
INSERT INTO accounts VALUES (1,'alice',100.00),(2,'bob',50.00);
INSERT INTO transactions VALUES
(1,1,  50.00,'2026-03-01 09:00'),
(2,1,-200.00,'2026-03-02 09:00'),   -- 拒絕
(3,1,  30.00,'2026-03-03 09:00'),
(4,1,-100.00,'2026-03-04 09:00'),
(5,1,-100.00,'2026-03-05 09:00'),   -- 拒絕
(6,1,  20.00,'2026-03-06 09:00'),
(7,2, -80.00,'2026-03-01 10:00'),   -- 拒絕
(8,2,  40.00,'2026-03-02 10:00'),
(9,2, -60.00,'2026-03-03 10:00');
-- Part C2 壓力測試資料（需要時再跑）：
-- INSERT INTO accounts VALUES (3,'stress',1000.00);
-- INSERT INTO transactions (id, account_id, amount, occurred_at)
-- SELECT 1000+g, 3, (random()*400-200)::NUMERIC(12,2),
--        TIMESTAMP '2026-01-01' + (g||' minutes')::INTERVAL
-- FROM generate_series(1,5000) g;
