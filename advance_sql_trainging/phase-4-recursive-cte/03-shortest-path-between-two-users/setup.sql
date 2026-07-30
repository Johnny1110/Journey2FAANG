-- Phase 4-03 — Shortest Path Between Two Users
DROP VIEW IF EXISTS edges;
DROP TABLE IF EXISTS friendships;
CREATE TABLE friendships (a INT NOT NULL, b INT NOT NULL, PRIMARY KEY (a, b));
INSERT INTO friendships (a, b) VALUES
(1,2),(2,3),(3,4),(4,5),   -- 長鏈
(1,6),(6,5),               -- 捷徑：1->6->5 只要 2 度
(2,7),(7,8),               -- 支線
(9,10);                    -- 不相連的社群
-- 無向圖展開成雙向邊
CREATE VIEW edges AS
SELECT a AS src, b AS dst FROM friendships
UNION ALL
SELECT b, a FROM friendships;
