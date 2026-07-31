-- Phase 3-04 — Gaps and Islands II: Merge Overlapping Intervals
DROP TABLE IF EXISTS campaigns;
CREATE TABLE campaigns (
    id        INT PRIMARY KEY,
    product   VARCHAR(10) NOT NULL,
    starts_on DATE NOT NULL,
    ends_on   DATE NOT NULL          -- 閉區間
);
INSERT INTO campaigns (id, product, starts_on, ends_on) VALUES
(1,'P1','2026-01-01','2026-01-10'),
(2,'P1','2026-01-05','2026-01-15'),
(3,'P1','2026-01-20','2026-01-25'),
(4,'P2','2026-02-01','2026-02-05'),
(5,'P2','2026-02-05','2026-02-10'),
(6,'P2','2026-02-20','2026-02-22'),
(7,'P3','2026-03-01','2026-03-31'),   -- 包住下面兩檔
(8,'P3','2026-03-10','2026-03-15'),
(9,'P3','2026-03-20','2026-03-25');
