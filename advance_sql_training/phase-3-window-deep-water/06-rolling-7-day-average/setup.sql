-- Phase 3-06 — Rolling 7-Day Average With Missing Days
DROP TABLE IF EXISTS daily_revenue;
CREATE TABLE daily_revenue (
    day     DATE PRIMARY KEY,
    revenue NUMERIC(10,2) NOT NULL
);
INSERT INTO daily_revenue (day, revenue) VALUES
('2026-03-01', 100.00),('2026-03-02', 200.00),('2026-03-03', 300.00),
-- 3/04、3/05 缺
('2026-03-06', 600.00),('2026-03-07', 700.00),
-- 3/08 ~ 3/10 缺
('2026-03-11',1100.00),('2026-03-12',1200.00);
