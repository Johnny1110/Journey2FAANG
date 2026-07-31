-- Phase 7-04 — The Covering Index That Stopped Covering
DROP TABLE IF EXISTS events7;
CREATE TABLE events7 (
    id         BIGSERIAL PRIMARY KEY,
    user_id    INT NOT NULL,
    status     TEXT NOT NULL,
    amount     NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
INSERT INTO events7 (user_id, status, amount, created_at)
SELECT (random()*9999+1)::int,
       CASE WHEN random() < 0.99 THEN 'done' ELSE 'pending' END,
       (random()*500)::numeric(10,2),
       now() - (random() * interval '365 days')
FROM generate_series(1, 1000000);
CREATE INDEX idx_cover ON events7 (user_id) INCLUDE (amount);
VACUUM ANALYZE events7;
-- 狀態一：Heap Fetches=0, Buffers=4
-- 弄髒： UPDATE events7 SET amount = amount + 1 WHERE id % 20 = 0;  ANALYZE events7;
-- 狀態二：Bitmap Heap Scan, Buffers=113, relallvisible=0
-- 修復： VACUUM ANALYZE events7;
