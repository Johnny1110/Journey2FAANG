-- Phase 6-06 — Deduplicate a 10M-Row Table
-- 50 萬列（想加壓把 500000 改成 5000000，但會慢很多）
DROP TABLE IF EXISTS contacts;
CREATE TABLE contacts (
    id         SERIAL PRIMARY KEY,
    email      TEXT NOT NULL,
    name       TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);
INSERT INTO contacts (email, name)
SELECT 'user'||(g % 200000)||'@example.com', 'name_'||g
FROM generate_series(1, 500000) g;
ANALYZE contacts;
-- 起始： rows=500000, distinct_emails=200000
