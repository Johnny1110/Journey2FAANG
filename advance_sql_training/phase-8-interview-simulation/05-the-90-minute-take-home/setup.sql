-- Phase 8-05 — The 90-Minute Take-Home
-- 跑完這個檔案，設 90 分鐘計時器，然後開始。
DROP TABLE IF EXISTS fx_rates;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS usage_events;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id BIGINT PRIMARY KEY, company TEXT NOT NULL, country TEXT,
    signed_up_at TIMESTAMPTZ NOT NULL, churned_at TIMESTAMPTZ,
    is_internal BOOLEAN NOT NULL DEFAULT false
);
CREATE TABLE subscriptions (
    id BIGSERIAL PRIMARY KEY, account_id BIGINT NOT NULL, plan TEXT NOT NULL,
    mrr NUMERIC(10,2) NOT NULL, valid_from DATE NOT NULL, valid_to DATE
);
CREATE TABLE usage_events (
    id BIGSERIAL PRIMARY KEY, account_id BIGINT NOT NULL, seat_email TEXT NOT NULL,
    feature TEXT NOT NULL, occurred_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE invoices (
    id BIGSERIAL PRIMARY KEY, account_id BIGINT NOT NULL, amount NUMERIC(10,2) NOT NULL,
    currency CHAR(3) NOT NULL, issued_on DATE NOT NULL, paid_on DATE
);
CREATE TABLE fx_rates (
    currency CHAR(3) NOT NULL, rate_date DATE NOT NULL,
    rate_to_usd NUMERIC(12,6) NOT NULL, PRIMARY KEY (currency, rate_date)
);

-- 300 個帳號（陷阱 1：country 有 NULL；陷阱 2：is_internal）
INSERT INTO accounts
SELECT g, 'company_'||g,
       CASE WHEN g % 17 = 0 THEN NULL
            ELSE (ARRAY['TW','JP','US','DE'])[floor(random()*4+1)] END,
       '2025-06-01'::timestamptz + (random()*interval '300 days'),
       CASE WHEN g % 11 = 0 THEN '2026-01-01'::timestamptz + (random()*interval '150 days') END,
       (g % 40 = 0)
FROM generate_series(1, 300) g;

-- 訂閱歷史：多數帳號一段，部分帳號在 2026-04-01 升級
INSERT INTO subscriptions (account_id, plan, mrr, valid_from, valid_to)
SELECT a.id,
       CASE WHEN a.id % 3 = 0 THEN 'enterprise' WHEN a.id % 3 = 1 THEN 'pro' ELSE 'free' END,
       CASE WHEN a.id % 3 = 0 THEN 2000.00 WHEN a.id % 3 = 1 THEN 300.00 ELSE 0.00 END,
       '2026-01-01',
       CASE WHEN a.id % 5 = 0 THEN '2026-04-01'::date END
FROM accounts a;
INSERT INTO subscriptions (account_id, plan, mrr, valid_from, valid_to)
SELECT a.id, 'enterprise', 2500.00, '2026-04-01', NULL
FROM accounts a WHERE a.id % 5 = 0;
-- 陷阱 5：月中升級
INSERT INTO subscriptions (account_id, plan, mrr, valid_from, valid_to) VALUES
(7, 'enterprise', 3000.00, '2026-03-15', NULL);
UPDATE subscriptions SET valid_to = '2026-03-15' WHERE account_id = 7 AND valid_from = '2026-01-01';
-- 陷阱 3：區間重疊（帳號 13）
INSERT INTO subscriptions (account_id, plan, mrr, valid_from, valid_to) VALUES
(13, 'enterprise', 5000.00, '2026-02-01', NULL);
-- 陷阱 4：區間缺口（帳號 23 在 3 月沒有方案）
UPDATE subscriptions SET valid_to = '2026-03-01' WHERE account_id = 23 AND valid_from = '2026-01-01';
INSERT INTO subscriptions (account_id, plan, mrr, valid_from, valid_to) VALUES
(23, 'pro', 300.00, '2026-04-01', NULL);

-- 使用事件（陷阱 7：seat_email 大小寫不一致）
INSERT INTO usage_events (account_id, seat_email, feature, occurred_at)
SELECT (random()*299+1)::bigint,
       CASE WHEN random() < 0.3 THEN 'User'||(random()*400)::int||'@Corp.COM'
            ELSE 'user'||(random()*400)::int||'@corp.com' END,
       (ARRAY['export','dashboard','api','report'])[floor(random()*4+1)],
       '2026-01-01'::timestamptz + (random()*interval '200 days')
FROM generate_series(1, 200000);
-- 陷阱 8：未來時間的事件
INSERT INTO usage_events (account_id, seat_email, feature, occurred_at)
SELECT 5, 'ghost@corp.com', 'api', now() + interval '30 days' FROM generate_series(1,5);
-- 陷阱 9：已流失帳號仍在產生事件
INSERT INTO usage_events (account_id, seat_email, feature, occurred_at)
SELECT a.id, 'zombie@corp.com', 'api', a.churned_at + interval '20 days'
FROM accounts a WHERE a.churned_at IS NOT NULL LIMIT 8;

-- 發票（多幣別）
INSERT INTO invoices (account_id, amount, currency, issued_on, paid_on)
SELECT (random()*299+1)::bigint, (random()*3000+100)::numeric(10,2),
       (ARRAY['USD','EUR','JPY'])[floor(random()*3+1)],
       '2026-01-01'::date + (random()*180)::int,
       CASE WHEN random() < 0.75 THEN '2026-01-01'::date + (random()*200)::int END
FROM generate_series(1, 1200);
-- 陷阱 6：發票早於所有匯率紀錄
INSERT INTO invoices (account_id, amount, currency, issued_on, paid_on)
VALUES (1, 5000.00, 'EUR', '2025-11-15', NULL);
-- 陷阱 10：付款日早於開立日
INSERT INTO invoices (account_id, amount, currency, issued_on, paid_on)
VALUES (2, 800.00, 'USD', '2026-05-10', '2026-04-01');

INSERT INTO fx_rates VALUES
('USD','2026-01-01',1.000000),
('EUR','2026-01-01',1.100000),('EUR','2026-04-01',1.050000),
('JPY','2026-01-01',0.007000),('JPY','2026-04-01',0.006500);

CREATE INDEX ON usage_events (account_id, occurred_at);
CREATE INDEX ON subscriptions (account_id, valid_from);
CREATE INDEX ON invoices (account_id, issued_on);
ANALYZE accounts; ANALYZE subscriptions; ANALYZE usage_events; ANALYZE invoices; ANALYZE fx_rates;
