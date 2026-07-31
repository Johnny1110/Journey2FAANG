-- Phase 7-06 — Partition Pruning Gone Wrong
DROP TABLE IF EXISTS measurements;
CREATE TABLE measurements (
    id        BIGSERIAL,
    sensor_id INT NOT NULL,
    reading   NUMERIC(10,2) NOT NULL,
    taken_at  TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (taken_at);
CREATE TABLE measurements_2026_01 PARTITION OF measurements FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE measurements_2026_02 PARTITION OF measurements FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE measurements_2026_03 PARTITION OF measurements FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE measurements_2026_04 PARTITION OF measurements FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE measurements_2026_05 PARTITION OF measurements FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE measurements_2026_06 PARTITION OF measurements FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
INSERT INTO measurements (sensor_id, reading, taken_at)
SELECT (random()*99+1)::int, (random()*100)::numeric(10,2),
       '2026-01-01'::timestamptz + (random() * interval '180 days')
FROM generate_series(1, 600000);
ANALYZE measurements;
-- 數掃了幾張分區： EXPLAIN (ANALYZE) ... 然後 grep -c 'on measurements_'
