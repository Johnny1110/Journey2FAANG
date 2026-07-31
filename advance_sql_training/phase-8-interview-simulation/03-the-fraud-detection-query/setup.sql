-- Phase 8-03 — The Fraud Detection Query
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS logins;
DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
    id BIGINT PRIMARY KEY, email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL, home_country TEXT
);
CREATE TABLE logins (
    id BIGSERIAL PRIMARY KEY, account_id BIGINT NOT NULL, ip INET NOT NULL,
    country TEXT, logged_at TIMESTAMPTZ NOT NULL, success BOOLEAN NOT NULL
);
CREATE TABLE transactions (
    id BIGSERIAL PRIMARY KEY, account_id BIGINT NOT NULL, amount NUMERIC(12,2) NOT NULL,
    currency CHAR(3) NOT NULL, merchant TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL, status TEXT NOT NULL
);
INSERT INTO accounts
SELECT g, 'u'||g||'@ex.com', now()-(random()*interval '500 days'),
       (ARRAY['TW','JP','US','DE'])[floor(random()*4+1)]
FROM generate_series(1,20000) g;
-- 一般登入
INSERT INTO logins (account_id, ip, country, logged_at, success)
SELECT (random()*19999+1)::bigint, ('10.'||(random()*255)::int||'.0.1')::inet,
       CASE WHEN random()<0.05 THEN NULL              -- IP 反查失敗
            ELSE (ARRAY['TW','JP','US','DE'])[floor(random()*4+1)] END,
       now()-(random()*interval '30 days'), random() > 0.05
FROM generate_series(1,200000);
-- 一般交易
INSERT INTO transactions (account_id, amount, currency, merchant, occurred_at, status)
SELECT (random()*19999+1)::bigint, (random()*200+5)::numeric(12,2),
       (ARRAY['USD','EUR','JPY'])[floor(random()*3+1)], 'shop_'||(random()*50)::int,
       now()-(random()*interval '30 days'),
       CASE WHEN random()<0.08 THEN 'declined' ELSE 'approved' END
FROM generate_series(1,500000);
-- 植入：帳號 777 短時間高頻交易
INSERT INTO transactions (account_id, amount, currency, merchant, occurred_at, status)
SELECT 777, 50.00, 'USD', 'suspicious_shop',
       now() - interval '2 days' + (g || ' minutes')::interval, 'approved'
FROM generate_series(1, 9) g;
-- 植入：帳號 888 異地登入（10 分鐘內跨國）
INSERT INTO logins (account_id, ip, country, logged_at, success) VALUES
(888,'1.1.1.1','TW', now()-interval '3 days', true),
(888,'2.2.2.2','US', now()-interval '3 days' + interval '10 minutes', true);
-- 植入：帳號 999 金額異常
INSERT INTO transactions (account_id, amount, currency, merchant, occurred_at, status)
SELECT 999, 30.00,'USD','normal_shop', now()-interval '20 days'+(g||' days')::interval,'approved'
FROM generate_series(1,20) g;
INSERT INTO transactions (account_id, amount, currency, merchant, occurred_at, status)
VALUES (999, 9999.00,'USD','suspicious_shop', now()-interval '1 hour','approved');
CREATE INDEX ON transactions (account_id, occurred_at);
CREATE INDEX ON logins (account_id, logged_at);
ANALYZE accounts; ANALYZE logins; ANALYZE transactions;
-- 已植入：帳號 777 (velocity) / 888 (impossible travel) / 999 (amount anomaly)
