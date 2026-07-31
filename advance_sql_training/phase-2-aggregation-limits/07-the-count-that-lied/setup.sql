-- Phase 2-07 — The COUNT That Lied
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    amount      NUMERIC(10,2) NOT NULL
);

CREATE TABLE reviews (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    rating      INT NOT NULL
);

INSERT INTO customers (id, name) VALUES
(1, 'alice'), (2, 'bob'), (3, 'carol'), (4, 'dave');

INSERT INTO orders (id, customer_id, amount) VALUES
(101, 1, 100.00),
(102, 1, 100.00),     -- 和 101 金額相同：讓 SUM(DISTINCT) 出錯
(103, 1, 400.00),
(104, 2, 250.00);

INSERT INTO reviews (id, customer_id, rating) VALUES
(201, 1, 5),
(202, 1, 3),
(203, 3, 4);
