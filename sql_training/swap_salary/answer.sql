-- 1. Using CASE WHEN (standard, works on all databases)
UPDATE Salary
SET sex = CASE WHEN sex = 'm' THEN 'f' ELSE 'm' END;

SELECT * FROM Salary ORDER BY id;
