-- Phase 3-03 — Gaps and Islands I: The Login Streak
DROP TABLE IF EXISTS logins;
CREATE TABLE logins (
    id       SERIAL PRIMARY KEY,
    user_id  INT NOT NULL,
    login_at TIMESTAMP NOT NULL
);
INSERT INTO logins (user_id, login_at) VALUES
(1,'2026-01-01 09:00'),(1,'2026-01-02 10:00'),(1,'2026-01-03 11:00'),
(1,'2026-01-05 09:00'),(1,'2026-01-06 09:00'),
(2,'2026-01-01 08:00'),
(2,'2026-01-02 09:00'),(2,'2026-01-02 14:00'),   -- 同一天兩次
(2,'2026-01-03 08:00'),(2,'2026-01-03 21:00'),   -- 同一天兩次
(2,'2026-01-04 10:00'),(2,'2026-01-05 10:00'),
(3,'2026-02-14 12:00'),
(4,'2026-03-10 09:00'),(4,'2026-03-11 09:00'),(4,'2026-03-12 09:00'),
(4,'2026-03-13 09:00'),(4,'2026-03-14 09:00'),
(4,'2026-03-20 09:00');
-- Part C3 用：伺服器狀態
DROP TABLE IF EXISTS server_status;
CREATE TABLE server_status (
    checked_at TIMESTAMP PRIMARY KEY,
    status     VARCHAR(10) NOT NULL
);
INSERT INTO server_status (checked_at, status) VALUES
('2026-03-01 00:00','up'),('2026-03-01 00:01','up'),
('2026-03-01 00:02','down'),('2026-03-01 00:03','down'),('2026-03-01 00:04','down'),
('2026-03-01 00:05','up'),
('2026-03-01 00:06','down'),('2026-03-01 00:07','down'),
('2026-03-01 00:08','up'),('2026-03-01 00:09','up');
