-- Phase 2-05 — The Weighted Average Trap
DROP TABLE IF EXISTS regional_orders;
DROP TABLE IF EXISTS grades;

CREATE TABLE regional_orders (
    id     SERIAL PRIMARY KEY,
    region VARCHAR(20) NOT NULL,
    amount NUMERIC(10,2) NOT NULL
);

INSERT INTO regional_orders (region, amount) SELECT 'APAC', 1000.00;
INSERT INTO regional_orders (region, amount) SELECT 'EMEA',   10.00 FROM generate_series(1, 99);
INSERT INTO regional_orders (region, amount) SELECT 'NA',    100.00 FROM generate_series(1, 20);

-- Part B3 用
CREATE TABLE grades (
    student VARCHAR(20),
    course  VARCHAR(20),
    credits INT,
    score   NUMERIC(5,2)
);

INSERT INTO grades VALUES
('alice','Calculus',    4,  60.00),
('alice','PE',          1, 100.00),
('alice','Literature',  1, 100.00),
('bob',  'Calculus',    4,  90.00),
('bob',  'PE',          1,  60.00),
('bob',  'Literature',  1,  60.00);
