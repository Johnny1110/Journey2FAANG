-- Phase 5-06 — Days With No Sales
DROP TABLE IF EXISTS daily_sales;
DROP TABLE IF EXISTS stock_snapshots;
CREATE TABLE daily_sales (product_id INT NOT NULL, sold_on DATE NOT NULL, revenue NUMERIC(10,2) NOT NULL, PRIMARY KEY (product_id, sold_on));
CREATE TABLE stock_snapshots (product_id INT NOT NULL, snap_date DATE NOT NULL, qty INT NOT NULL, PRIMARY KEY (product_id, snap_date));
INSERT INTO daily_sales (product_id, sold_on, revenue) VALUES
(1,'2026-03-01',100),(1,'2026-03-03',200),(1,'2026-03-07',150);
INSERT INTO stock_snapshots (product_id, snap_date, qty) VALUES
(1,'2026-03-01',500),(1,'2026-03-04',420),(1,'2026-03-08',600);
-- 流量(revenue)缺漏補 0；存量(qty)缺漏補前值 LOCF
-- Part C2 多商品時自行補資料
