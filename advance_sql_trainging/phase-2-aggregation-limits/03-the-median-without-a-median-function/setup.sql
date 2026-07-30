-- Phase 2-03 — The Median Without a Median Function
DROP TABLE IF EXISTS employees;

CREATE TABLE employees (
    id         INT PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(30) NOT NULL,
    salary     NUMERIC(10,2)          -- 可為 NULL：實習生還沒定薪
);

INSERT INTO employees (id, name, department, salary) VALUES
(1,'e1','Engineering',100000),(2,'e2','Engineering',200000),(3,'e3','Engineering',300000),
(4,'e4','Engineering',400000),(5,'e5','Engineering',500000),
(6,'s1','Sales',100000),(7,'s2','Sales',200000),(8,'s3','Sales',300000),(9,'s4','Sales',400000),
(10,'h1','HR',500000),
(11,'p1','Support',300000),(12,'p2','Support',300000),
(13,'m1','Marketing',100000),(14,'m2','Marketing',200000),
(15,'m3','Marketing',200000),(16,'m4','Marketing',900000),
(17,'i1','Intern',NULL),(18,'i2','Intern',50000);
