-- Phase 7-03 — Partial Index for the 1% Case
DROP TABLE IF EXISTS tickets;
CREATE TABLE tickets (
    id         BIGSERIAL PRIMARY KEY,
    status     TEXT NOT NULL,
    assignee   INT,
    created_at TIMESTAMPTZ NOT NULL,
    body       TEXT NOT NULL
);
INSERT INTO tickets (status, assignee, created_at, body)
SELECT 'closed', (random()*99+1)::int, now() - (random()*interval '180 days'), repeat('x',50)
FROM generate_series(1, 990000);
INSERT INTO tickets (status, assignee, created_at, body)
SELECT 'open', (random()*99+1)::int,
       now() - interval '180 days' - (random()*interval '185 days'), repeat('x',50)
FROM generate_series(1, 10000);
ANALYZE tickets;

-- Part C 用
DROP TABLE IF EXISTS users7;
CREATE TABLE users7 (id SERIAL PRIMARY KEY, email TEXT NOT NULL);
INSERT INTO users7 (email) SELECT 'User'||g||'@Example.COM' FROM generate_series(1, 500000) g;
CREATE INDEX idx_email ON users7 (email);
ANALYZE users7;
-- 先查 collation： SELECT datcollate FROM pg_database WHERE datname=current_database();
