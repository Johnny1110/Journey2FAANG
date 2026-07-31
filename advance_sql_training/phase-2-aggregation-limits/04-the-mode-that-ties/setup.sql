-- Phase 2-04 — The Mode That Ties
DROP TABLE IF EXISTS purchases;

CREATE TABLE purchases (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL,
    product     VARCHAR(30) NOT NULL,
    bought_on   DATE NOT NULL
);

INSERT INTO purchases (id, customer_id, product, bought_on) VALUES
(1, 1, 'laptop',   '2026-01-01'),
(2, 1, 'laptop',   '2026-01-02'),
(3, 1, 'laptop',   '2026-01-03'),
(4, 1, 'mouse',    '2026-01-04'),
(5, 2, 'keyboard', '2026-02-01'),
(6, 2, 'keyboard', '2026-02-02'),
(7, 2, 'monitor',  '2026-02-03'),
(8, 2, 'monitor',  '2026-02-04'),
(9,  3, 'cable',   '2026-03-01'),
(10, 3, 'dock',    '2026-03-02'),
(11, 3, 'hub',     '2026-03-03'),
(12, 4, 'webcam',  '2026-03-05');
