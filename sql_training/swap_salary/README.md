# LC 627. Swap Salary

<br>

---

<br>

## Desc

Write a solution to swap all `'f'` and `'m'` values (i.e., change all `'f'` values to `'m'` and vice versa) with a **single update statement** and no intermediate temporary tables.

Note that you must write a single update statement, **do not** write any select statement for this problem.

The result format is in the following example.

<br>
<br>

## Table Schema + Testing Data

```sql
-- Create Salary table
DROP TABLE IF EXISTS Salary;

CREATE TABLE Salary (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    sex CHAR(1) NOT NULL CHECK (sex IN ('m', 'f')),
    salary INT NOT NULL
);

-- Insert test data
INSERT INTO Salary (id, name, sex, salary) VALUES
    (1, 'A', 'm', 2500),
    (2, 'B', 'f', 1500),
    (3, 'C', 'm', 5500),
    (4, 'D', 'f', 500);

-- Initial state:
-- +----+------+-----+--------+
-- | id | name | sex | salary |
-- +----+------+-----+--------+
-- | 1  | A    | m   | 2500   |
-- | 2  | B    | f   | 1500   |
-- | 3  | C    | m   | 5500   |
-- | 4  | D    | f   | 500    |
-- +----+------+-----+--------+

-- Expected output after swap:
-- +----+------+-----+--------+
-- | id | name | sex | salary |
-- +----+------+-----+--------+
-- | 1  | A    | f   | 2500   |
-- | 2  | B    | m   | 1500   |
-- | 3  | C    | f   | 5500   |
-- | 4  | D    | m   | 500    |
-- +----+------+-----+--------+
```
