-- Phase 4-07 — The Recursion That Never Ended
-- 務必先設保險絲： SET statement_timeout = '3s';
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    id         INT PRIMARY KEY,
    name       VARCHAR(30) NOT NULL,
    manager_id INT
);
INSERT INTO employees (id, name, manager_id) VALUES
(1,'ceo',   NULL),
(2,'alice',    1),
(3,'bob',      1),
(4,'carol',    2),
(5,'dave',     8),   -- 環：5 -> 8 -> 7 -> 5
(6,'eve',      4),
(7,'frank',    5),
(8,'grace',    7);
