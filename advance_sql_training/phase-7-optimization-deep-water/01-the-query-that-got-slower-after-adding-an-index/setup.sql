-- Phase 7-01 — The Query That Got Slower After Adding an Index
-- open 的工單全部是最舊的：這是關鍵的資料分布
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
