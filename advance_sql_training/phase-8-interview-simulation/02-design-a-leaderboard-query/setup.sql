-- Phase 8-02 — Design a Leaderboard Query
DROP TABLE IF EXISTS scores;
DROP TABLE IF EXISTS players;
CREATE TABLE players (
    id        BIGINT PRIMARY KEY,
    nickname  TEXT NOT NULL,
    country   TEXT NOT NULL,
    is_banned BOOLEAN NOT NULL DEFAULT false
);
CREATE TABLE scores (
    id          BIGSERIAL PRIMARY KEY,
    player_id   BIGINT NOT NULL REFERENCES players(id),
    score       INT NOT NULL,
    season      INT NOT NULL,
    achieved_at TIMESTAMPTZ NOT NULL
);
INSERT INTO players (id, nickname, country, is_banned)
SELECT g, 'player_'||g, (ARRAY['TW','JP','KR','US'])[floor(random()*4+1)], random() < 0.001
FROM generate_series(1, 1000000) g;
-- 分數只有 1000 種可能值 -> 平均每個分數 1000 人並列
INSERT INTO scores (player_id, score, season, achieved_at)
SELECT (random()*999999+1)::bigint, (random()*999)::int * 10, 1,
       now() - (random()*interval '90 days')
FROM generate_series(1, 5000000);
CREATE INDEX ON scores (player_id);
ANALYZE players; ANALYZE scores;
