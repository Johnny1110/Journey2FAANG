-- Phase 1-07 — The Report With Missing Rows
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS regions;

CREATE TABLE regions (
    id   INT PRIMARY KEY,
    name VARCHAR(30) NOT NULL
);

CREATE TABLE sales (
    id        SERIAL PRIMARY KEY,
    region_id INT NOT NULL REFERENCES regions(id),
    sold_on   DATE NOT NULL,
    amount    NUMERIC(10,2) NOT NULL
);

INSERT INTO regions (id, name) VALUES
(1, 'APAC'), (2, 'EMEA'), (3, 'NA'), (4, 'LATAM');   -- LATAM 這一季無資料

INSERT INTO sales (region_id, sold_on, amount) VALUES
(1, '2026-01-08', 12000.00),
(1, '2026-01-22',  8500.00),
(1, '2026-02-14', 15000.00),
(1, '2026-03-05',  9800.00),
(1, '2026-03-27', 11200.00),
(2, '2026-01-15', 22000.00),
(2, '2026-03-11', 18500.00),
(3, '2026-02-20', 31000.00);
-- 報表期間 2026-01-01 ~ 2026-04-30，正確答案 16 行
