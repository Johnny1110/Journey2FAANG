-- Phase 4-01 — The Org Chart That Loops
-- 執行任何遞迴查詢前先設保險絲： SET statement_timeout = '2s';
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    id         INT PRIMARY KEY,
    name       VARCHAR(30) NOT NULL,
    manager_id INT,
    salary     NUMERIC(10,2) NOT NULL
);
INSERT INTO employees (id, name, manager_id, salary) VALUES
(1, 'ceo',      NULL, 500000),
(2, 'vp_eng',      1, 300000),
(3, 'vp_sales',    1, 290000),
(4, 'dir_a',       2, 200000),
(5, 'dir_b',       2, 195000),
(6, 'mgr_x',       8, 150000),   -- 資料錯誤：應該是 4
(7, 'mgr_y',       6, 145000),
(8, 'mgr_z',       7, 148000),
(9, 'eng_1',       6, 120000),
(10,'eng_2',       4, 118000);
-- 環：6 -> 8 -> 7 -> 6，eng_1(9) 掛在環底下
