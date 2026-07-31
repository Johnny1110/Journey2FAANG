-- Phase 5-03 — Cohort Revenue Curve
DROP TABLE IF EXISTS purchases;
DROP TABLE IF EXISTS members;
CREATE TABLE members (id INT PRIMARY KEY, signup_date DATE NOT NULL);
CREATE TABLE purchases (id SERIAL PRIMARY KEY, user_id INT NOT NULL, purchase_date DATE NOT NULL, amount NUMERIC(10,2) NOT NULL);
INSERT INTO members (id, signup_date) VALUES
(1,'2026-01-10'),(2,'2026-01-20'),(3,'2026-01-25'),   -- 一月 cohort：3 人
(4,'2026-02-05'),(5,'2026-02-14');                    -- 二月 cohort：2 人
INSERT INTO purchases (user_id, purchase_date, amount) VALUES
(1,'2026-01-11',100),(1,'2026-02-03',50),(1,'2026-03-08',30),
(2,'2026-01-22',200),
(3,'2026-03-15',500),
(4,'2026-02-06',80),(4,'2026-03-02',40);
-- user 5 從未消費（ARPU vs ARPPU 的分母差異）
