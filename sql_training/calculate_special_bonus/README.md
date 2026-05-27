# LC 1873. Calculate Special Bonus

<br>

---

<br>

## Desc

Write a solution to calculate the bonus of each employee. The bonus of an employee is `100%` of their salary if the ID of the employee is **an odd number** and **the employee's name does not start with the character `'M'`**. The bonus of an employee is `0` otherwise.

Return the result table ordered by `employee_id`.

<br>
<br>

## Table Schema + Testing Data

```sql
-- Create Employees table
DROP TABLE IF EXISTS Employees;

CREATE TABLE Employees (
    employee_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    salary INT NOT NULL
);

-- Insert test data
INSERT INTO Employees (employee_id, name, salary) VALUES
    (2, 'Meir', 3000),
    (3, 'Michael', 3800),
    (7, 'Addilyn', 7400),
    (8, 'Juan', 6100),
    (9, 'Kannon', 7700);

-- Input:
-- +-------------+---------+--------+
-- | employee_id | name    | salary |
-- +-------------+---------+--------+
-- | 2           | Meir    | 3000   |
-- | 3           | Michael | 3800   |
-- | 7           | Addilyn | 7400   |
-- | 8           | Juan    | 6100   |
-- | 9           | Kannon  | 7700   |
-- +-------------+---------+--------+

-- Expected output:
-- +-------------+-------+
-- | employee_id | bonus |
-- +-------------+-------+
-- | 2           | 0     |
-- | 3           | 0     |
-- | 7           | 7400  |
-- | 8           | 0     |
-- | 9           | 7700  |
-- +-------------+-------+
```
