-- Phase 7-07 — Materialized View Refresh Strategy
DROP MATERIALIZED VIEW IF EXISTS mv_region_daily;
DROP TABLE IF EXISTS sales7;
CREATE TABLE sales7 (
    id          BIGSERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    region      TEXT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    sold_on     DATE NOT NULL
);
INSERT INTO sales7 (customer_id, region, amount, sold_on)
SELECT (random()*4999+1)::int,
       (ARRAY['APAC','EMEA','NA','LATAM'])[floor(random()*4+1)],
       (random()*1000)::numeric(10,2),
       '2026-01-01'::date + (random()*200)::int
FROM generate_series(1, 300000);
ANALYZE sales7;
CREATE MATERIALIZED VIEW mv_region_daily AS
SELECT region, sold_on, count(*) AS orders, sum(amount) AS revenue
FROM sales7 GROUP BY region, sold_on;
-- Part A2 要加： CREATE UNIQUE INDEX ON mv_region_daily (region, sold_on);
