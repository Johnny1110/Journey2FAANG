-- Phase 6-02 — The Job Queue That Double-Processed
SET lock_timeout = '5s';
DROP TABLE IF EXISTS jobs;
CREATE TABLE jobs (
    id        SERIAL PRIMARY KEY,
    payload   TEXT NOT NULL,
    status    TEXT NOT NULL DEFAULT 'pending',
    locked_by TEXT,
    locked_at TIMESTAMP
);
INSERT INTO jobs (payload) SELECT 'job_'||g FROM generate_series(1,5) g;
-- 重置： UPDATE jobs SET status='pending', locked_by=NULL, locked_at=NULL;
