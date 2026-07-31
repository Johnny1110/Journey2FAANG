-- Phase 8-04 — Debug This Query
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    id INT PRIMARY KEY, name TEXT NOT NULL, country TEXT,
    is_test BOOLEAN NOT NULL DEFAULT false
);
CREATE TABLE orders (
    id INT PRIMARY KEY, customer_id INT NOT NULL REFERENCES customers(id),
    status TEXT NOT NULL, amount NUMERIC(10,2) NOT NULL, ordered_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE refunds (
    id INT PRIMARY KEY, order_id INT NOT NULL REFERENCES orders(id), amount NUMERIC(10,2) NOT NULL
);
CREATE TABLE reviews (
    id INT PRIMARY KEY, customer_id INT NOT NULL REFERENCES customers(id), rating INT NOT NULL
);
INSERT INTO customers VALUES
(1,'alice','TW',false),(2,'bob','TW',false),(3,'carol','JP',false),
(4,'dave',NULL,false),            -- country 是 NULL
(5,'test_acct','TW',true);        -- 測試帳號
INSERT INTO orders VALUES
(101,1,'paid',100.00,'2026-03-05 10:00'),
(102,1,'paid',100.00,'2026-03-10 10:00'),      -- 和 101 同金額（讓 SUM(DISTINCT) 也錯）
(103,1,'paid',400.00,'2026-03-20 10:00'),
(104,2,'paid',250.00,'2026-03-15 10:00'),
(105,3,'paid',300.00,'2026-03-31 14:00'),      -- 3/31 下午：BETWEEN 會漏掉
(106,4,'paid',150.00,'2026-03-18 10:00'),
(107,5,'paid',999.00,'2026-03-12 10:00'),      -- 測試帳號
(108,2,'cancelled',500.00,'2026-03-22 10:00'); -- 已取消
INSERT INTO refunds VALUES (201,101,30.00),(202,103,50.00);
INSERT INTO reviews VALUES (301,1,5),(302,1,3),(303,2,4),(304,3,5);
-- 錯誤查詢輸出： (unknown) 1/1/150 ; TW 8/8/1790     <- JP 消失
-- 正確答案：     (unknown) 1/1/150 ; JP 1/1/300 ; TW 2/4/770
