-- Phase 5-04 — The As-Of Join
DROP TABLE IF EXISTS fx_orders;
DROP TABLE IF EXISTS fx_rates;
CREATE TABLE fx_rates (currency CHAR(3) NOT NULL, rate_date DATE NOT NULL, rate_to_usd NUMERIC(12,6) NOT NULL, PRIMARY KEY (currency, rate_date));
CREATE TABLE fx_orders (id INT PRIMARY KEY, order_date DATE NOT NULL, amount NUMERIC(12,2) NOT NULL, currency CHAR(3) NOT NULL);
INSERT INTO fx_rates VALUES
('EUR','2026-01-01',1.100000),('EUR','2026-03-01',1.050000),('EUR','2026-06-01',1.150000),
('JPY','2026-01-01',0.007000),('JPY','2026-04-01',0.006500);
INSERT INTO fx_orders VALUES
(1,'2026-02-15',  100.00,'EUR'),
(2,'2026-03-05',  100.00,'EUR'),
(3,'2026-07-01',  100.00,'EUR'),
(4,'2026-02-01',10000.00,'JPY'),
(5,'2026-05-01',10000.00,'JPY'),
(6,'2025-12-01',  100.00,'EUR');   -- 早於任何匯率紀錄
-- 天真版總額 590.00，as-of 正確版 465.00
-- CREATE INDEX ON fx_rates (currency, rate_date DESC);   -- Part B2 用
