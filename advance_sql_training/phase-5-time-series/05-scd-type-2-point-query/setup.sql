-- Phase 5-05 — SCD Type 2 Point Query
DROP TABLE IF EXISTS product_price_scd;
DROP TABLE IF EXISTS price_changes;
CREATE TABLE product_price_scd (product_id INT NOT NULL, price NUMERIC(10,2) NOT NULL, valid_from DATE NOT NULL, valid_to DATE);
INSERT INTO product_price_scd (product_id, price, valid_from, valid_to) VALUES
(1,10.00,'2026-01-01','2026-03-01'),(1,12.00,'2026-03-01','2026-06-01'),(1,15.00,'2026-06-01',NULL),  -- 乾淨
(2,20.00,'2026-01-01','2026-02-01'),(2,25.00,'2026-03-01',NULL),                                       -- 二月缺口
(3,30.00,'2026-01-01','2026-04-01'),(3,35.00,'2026-03-01',NULL),                                       -- 三月重疊
(4,40.00,'2026-01-01',NULL);
-- Part D 用：上游變更記錄檔
CREATE TABLE price_changes (product_id INT NOT NULL, price NUMERIC(10,2) NOT NULL, changed_on DATE NOT NULL, PRIMARY KEY (product_id, changed_on));
INSERT INTO price_changes VALUES
(1,10.00,'2026-01-01'),(1,12.00,'2026-03-01'),(1,15.00,'2026-06-01'),
(4,40.00,'2026-01-01');
