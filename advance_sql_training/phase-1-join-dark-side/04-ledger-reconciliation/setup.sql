-- Phase 1-04 — Ledger Reconciliation
DROP TABLE IF EXISTS internal_ledger;
DROP TABLE IF EXISTS bank_statement;

CREATE TABLE internal_ledger (
    txn_ref   VARCHAR(20) PRIMARY KEY,
    amount    NUMERIC(12,2),
    booked_on DATE NOT NULL
);

CREATE TABLE bank_statement (
    txn_ref    VARCHAR(20) PRIMARY KEY,
    amount     NUMERIC(12,2),      -- 可為 NULL：清算中
    settled_on DATE NOT NULL
);

INSERT INTO internal_ledger (txn_ref, amount, booked_on) VALUES
('TXN-001', 1500.00, '2026-03-01'),
('TXN-002',  890.50, '2026-03-01'),
('TXN-003', 2300.00, '2026-03-02'),
('TXN-004',   45.00, '2026-03-02'),   -- 銀行沒有
('TXN-005', 1200.00, '2026-03-03'),
('TXN-007',    0.00, '2026-03-04');   -- 對上銀行的 NULL

INSERT INTO bank_statement (txn_ref, amount, settled_on) VALUES
('TXN-001', 1500.00, '2026-03-01'),
('TXN-002',  890.50, '2026-03-02'),   -- 金額對，結算日晚一天
('TXN-003', 2300.50, '2026-03-02'),   -- 金額差 0.50
('TXN-005', 1200.00, '2026-03-03'),
('TXN-006',  675.25, '2026-03-03'),   -- 我們沒記帳
('TXN-007',    NULL, '2026-03-04');   -- 清算中
