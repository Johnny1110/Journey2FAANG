-- Phase 5-01 — The Retention Matrix
DROP TABLE IF EXISTS activity;
DROP TABLE IF EXISTS users;
CREATE TABLE users (id INT PRIMARY KEY, signup_date DATE NOT NULL);
CREATE TABLE activity (user_id INT NOT NULL, active_date DATE NOT NULL, PRIMARY KEY (user_id, active_date));
INSERT INTO users (id, signup_date) VALUES
(1,'2026-03-01'),(2,'2026-03-01'),(3,'2026-03-01'),(4,'2026-03-01'),
(5,'2026-03-02'),(6,'2026-03-02');
INSERT INTO activity (user_id, active_date) VALUES
(1,'2026-03-01'),(1,'2026-03-02'),(1,'2026-03-08'),(1,'2026-03-31'),
(2,'2026-03-01'),(2,'2026-03-02'),(2,'2026-03-03'),(2,'2026-03-04'),
(3,'2026-03-01'),(3,'2026-03-08'),
(4,'2026-03-01'),
(5,'2026-03-02'),(5,'2026-03-03'),
(6,'2026-03-02');
-- 03-01 cohort: 恰好第7天 = 50%，7天內 = 75%
