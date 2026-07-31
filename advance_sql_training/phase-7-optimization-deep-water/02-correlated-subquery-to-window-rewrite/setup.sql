-- Phase 7-02 — Correlated Subquery → Window Rewrite
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
CREATE INDEX ON sales7 (customer_id);
ANALYZE sales7;
-- 相關子查詢 2435ms / 4.8M buffers；window 170ms / 296K buffers
