-- Phase 3-05 — Sessionization: The 30-Minute Rule
DROP TABLE IF EXISTS events;
CREATE TABLE events (
    id       SERIAL PRIMARY KEY,
    user_id  INT NOT NULL,
    event_at TIMESTAMP NOT NULL,
    page     VARCHAR(30) NOT NULL
);
INSERT INTO events (user_id, event_at, page) VALUES
(1,'2026-03-01 09:00','/home'),(1,'2026-03-01 09:05','/search'),(1,'2026-03-01 09:20','/item'),
(1,'2026-03-01 10:30','/home'),(1,'2026-03-01 10:45','/cart'),(1,'2026-03-01 11:00','/checkout'),
(1,'2026-03-01 14:00','/home'),
(2,'2026-03-01 09:00','/home'),(2,'2026-03-01 09:30','/search'),   -- 間隔正好 30 分
(3,'2026-03-01 08:00','/home'),(3,'2026-03-01 08:31','/search'),   -- 間隔 31 分
(4,'2026-03-01 12:00','/home');
