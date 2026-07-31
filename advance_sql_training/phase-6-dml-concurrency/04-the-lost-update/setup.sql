-- Phase 6-04 — The Lost Update
SET lock_timeout = '5s';
DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
    id      INT PRIMARY KEY,
    owner   TEXT NOT NULL,
    balance NUMERIC(12,2) NOT NULL,
    version INT NOT NULL DEFAULT 0
);
INSERT INTO accounts (id, owner, balance) VALUES (1,'alice',1000.00),(2,'bob',1000.00);
-- 重置： UPDATE accounts SET balance=1000.00, version=0;
