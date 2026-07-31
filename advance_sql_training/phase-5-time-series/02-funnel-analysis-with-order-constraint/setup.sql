-- Phase 5-02 — Funnel Analysis With Order Constraint
DROP TABLE IF EXISTS events;
CREATE TABLE events (id SERIAL PRIMARY KEY, user_id INT NOT NULL, event_type VARCHAR(20) NOT NULL, event_at TIMESTAMP NOT NULL);
INSERT INTO events (user_id, event_type, event_at) VALUES
(1,'view','2026-03-01 09:00'),(1,'add_to_cart','2026-03-01 09:05'),(1,'checkout','2026-03-01 09:10'),(1,'purchase','2026-03-01 09:15'),
(2,'view','2026-03-01 10:00'),(2,'add_to_cart','2026-03-01 10:05'),(2,'checkout','2026-03-01 10:10'),
(3,'view','2026-03-01 11:00'),(3,'purchase','2026-03-01 11:05'),          -- 跳步驟
(4,'add_to_cart','2026-03-01 12:00'),(4,'view','2026-03-01 12:30'),       -- 順序顛倒
(5,'view','2026-03-02 09:00'),(5,'add_to_cart','2026-03-02 09:02'),
(5,'view','2026-03-02 14:00'),(5,'add_to_cart','2026-03-02 14:05'),(5,'checkout','2026-03-02 14:10'),(5,'purchase','2026-03-02 14:20'),
(6,'view','2026-03-03 09:00');
-- 天真版 6/4/3/3（結帳->付款 100%，荒謬）；順序版 6/3/3/2
