-- Phase 6-01 — The Idempotent Upsert
SET lock_timeout = '5s';
DROP TABLE IF EXISTS webhook_events;
CREATE TABLE webhook_events (
    event_id    VARCHAR(40) PRIMARY KEY,
    payload     TEXT NOT NULL,
    received_at TIMESTAMP NOT NULL DEFAULT now(),
    retry_count INT NOT NULL DEFAULT 0
);
DROP TABLE IF EXISTS subscriptions;
CREATE TABLE subscriptions (
    id      SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    plan    TEXT NOT NULL,
    status  TEXT NOT NULL
);
INSERT INTO subscriptions (user_id, plan, status) VALUES
(1,'pro','cancelled'),(1,'basic','cancelled');
-- Part C 要加：CREATE UNIQUE INDEX uniq_active_sub ON subscriptions (user_id) WHERE status='active';
