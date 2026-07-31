-- Phase 5-07 — DAU / WAU / MAU in One Query
DROP TABLE IF EXISTS app_activity;
CREATE TABLE app_activity (user_id INT NOT NULL, active_date DATE NOT NULL, PRIMARY KEY (user_id, active_date));
-- user 1、2：每天都活躍
INSERT INTO app_activity
SELECT u, d::date FROM generate_series(1,2) u,
     generate_series('2026-03-01'::date,'2026-03-10'::date,'1 day') d;
-- user 3、4、5：各只出現一天
INSERT INTO app_activity (user_id, active_date) VALUES
(3,'2026-03-01'),(4,'2026-03-05'),(5,'2026-03-10');
-- 全站只有 5 個使用者。03-07 的 WAU 真值 = 4，DAU 加總法 = 16。
