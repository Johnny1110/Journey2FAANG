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

-- Display initial state
SELECT * FROM Salary ORDER BY id;
