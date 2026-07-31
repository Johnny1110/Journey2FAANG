-- Phase 2-06 — Histogram With Empty Buckets
DROP TABLE IF EXISTS api_requests;

CREATE TABLE api_requests (
    id          SERIAL PRIMARY KEY,
    endpoint    VARCHAR(40) NOT NULL,
    response_ms INT NOT NULL
);

INSERT INTO api_requests (endpoint, response_ms) VALUES
('/login',     12), ('/login',     18), ('/login',     25), ('/login',    31),
('/login',     44), ('/login',     47), ('/login',    180), ('/login',   195),
('/search',    15), ('/search',    22), ('/search',   380), ('/search',  412),
('/search',   455), ('/checkout',   8), ('/checkout',  11), ('/checkout', 19),
('/checkout', 492),
('/checkout', 500),      -- 正好等於上界 -> width_bucket 回傳 11
('/search',   640);      -- 超過上界      -> width_bucket 回傳 11
-- 總共 19 筆
