-- Phase 6-07 — MERGE vs ON CONFLICT   (需要 PostgreSQL 15+)
SET lock_timeout = '5s';
DROP TABLE IF EXISTS inventory;
CREATE TABLE inventory (sku TEXT PRIMARY KEY, qty INT NOT NULL);
-- 重置： TRUNCATE inventory;
