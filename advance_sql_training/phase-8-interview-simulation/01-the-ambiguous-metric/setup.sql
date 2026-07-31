-- Phase 8-01 — The Ambiguous Metric
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
    id           BIGINT PRIMARY KEY,
    email        TEXT NOT NULL,
    signed_up_at TIMESTAMPTZ NOT NULL,
    deleted_at   TIMESTAMPTZ,
    account_type TEXT NOT NULL,        -- 'user' / 'internal' / 'bot'
    timezone     TEXT
);
CREATE TABLE events (
    id          BIGSERIAL PRIMARY KEY,
    account_id  BIGINT NOT NULL,
    event_type  TEXT NOT NULL,         -- app_open / page_view / click / purchase / heartbeat
    occurred_at TIMESTAMPTZ NOT NULL,
    device      TEXT
);
INSERT INTO accounts
SELECT g, 'u'||g||'@ex.com', now() - (random()*interval '400 days'),
       CASE WHEN random() < 0.03 THEN now() - (random()*interval '30 days') END,
       CASE WHEN random() < 0.02 THEN 'bot' WHEN random() < 0.04 THEN 'internal' ELSE 'user' END,
       CASE WHEN random() < 0.15 THEN NULL
            ELSE (ARRAY['UTC','Asia/Taipei','America/New_York','Europe/London'])[floor(random()*4+1)] END
FROM generate_series(1, 50000) g;
INSERT INTO events (account_id, event_type, occurred_at, device)
SELECT (random()*49999+1)::bigint,
       (ARRAY['app_open','page_view','click','purchase','heartbeat','heartbeat','heartbeat'])[floor(random()*7+1)],
       now() - (random()*interval '45 days'),
       (ARRAY['ios','android','web'])[floor(random()*3+1)]
FROM generate_series(1, 2000000);
CREATE INDEX ON events (account_id, occurred_at);
CREATE INDEX ON events (occurred_at);
ANALYZE accounts; ANALYZE events;
