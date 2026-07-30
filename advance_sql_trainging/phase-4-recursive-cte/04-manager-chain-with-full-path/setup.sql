-- Phase 4-04 — Manager Chain With Full Path
-- 這是 4-01 修好之後的組織圖（沒有環）
DROP TABLE IF EXISTS org;
CREATE TABLE org (
    id         INT PRIMARY KEY,
    name       VARCHAR(30) NOT NULL,
    manager_id INT,
    salary     NUMERIC(10,2) NOT NULL
);
INSERT INTO org (id, name, manager_id, salary) VALUES
(1, 'ceo',      NULL, 500000),
(2, 'vp_eng',      1, 300000),
(3, 'vp_sales',    1, 290000),
(4, 'dir_a',       2, 200000),
(5, 'dir_b',       2, 195000),
(6, 'mgr_x',       4, 150000),
(7, 'mgr_y',       6, 145000),
(8, 'mgr_z',       5, 148000),
(9, 'eng_1',       6, 120000),
(10,'eng_2',       4, 118000);
