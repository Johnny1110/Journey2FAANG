-- Phase 7-05 — The Statistics Lie
DROP TABLE IF EXISTS orders7;
DROP TABLE IF EXISTS addresses;
CREATE TABLE addresses (
    id      SERIAL PRIMARY KEY,
    country TEXT NOT NULL,
    city    TEXT NOT NULL,
    note    TEXT
);
-- 12 個城市，每個只屬於一個國家 -> city 完全決定 country
INSERT INTO addresses (country, city, note)
SELECT c.country, c.city, repeat('x',20)
FROM (VALUES
  ('Taiwan','Taipei'),('Taiwan','Kaohsiung'),('Taiwan','Taichung'),
  ('Japan','Tokyo'),('Japan','Osaka'),('Japan','Kyoto'),
  ('Korea','Seoul'),('Korea','Busan'),('Korea','Incheon'),
  ('USA','NYC'),('USA','LA'),('USA','Chicago')
) AS c(country, city), generate_series(1, 25000);
CREATE INDEX ON addresses (country, city);
ANALYZE addresses;

-- Part A4 用
CREATE TABLE orders7 (id SERIAL PRIMARY KEY, addr_id INT NOT NULL, amount NUMERIC(10,2) NOT NULL);
INSERT INTO orders7 (addr_id, amount)
SELECT (random()*299999+1)::int, (random()*100)::numeric(10,2) FROM generate_series(1,300000);
CREATE INDEX ON orders7 (addr_id);
ANALYZE orders7;
-- 無擴充統計：估 6041 / 實際 25000
-- CREATE STATISTICS stat_addr (dependencies, ndistinct, mcv) ON country, city FROM addresses;
