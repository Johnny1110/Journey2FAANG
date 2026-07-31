-- Phase 6-05 — Transfer Money Atomically
SET lock_timeout = '5s';
DROP TABLE IF EXISTS transfers;
DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
    id      INT PRIMARY KEY,
    owner   TEXT NOT NULL,
    balance NUMERIC(12,2) NOT NULL CHECK (balance >= 0)
);
CREATE TABLE transfers (
    id          SERIAL PRIMARY KEY,
    from_id     INT NOT NULL REFERENCES accounts(id),
    to_id       INT NOT NULL REFERENCES accounts(id),
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    occurred_at TIMESTAMP NOT NULL DEFAULT now(),
    CHECK (from_id <> to_id)
);
INSERT INTO accounts (id, owner, balance) VALUES (1,'alice',1000.00),(2,'bob',1000.00),(3,'carol',1000.00);
-- 不變式： SELECT SUM(balance) FROM accounts;  -- 必須恆為 3000.00
