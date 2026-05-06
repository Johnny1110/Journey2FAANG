WITH RECURSIVE subordinates AS (
    -- anchor: start AT manager 1
    SELECT employee_id
    FROM employees
    WHERE employee_id = 1 -- anchor is critical, boss ID.

    UNION ALL

    -- recursive: find employees whose boss is already in our set
    SELECT e.employee_id
    FROM employees e
             JOIN subordinates s ON e.manager_id = s.employee_id  -- downward
    where e.employee_id != e.manager_id -- prevent self-loop if an employee is their own manager
)
SELECT employee_id FROM subordinates
WHERE employee_id != 1;  -- exclude the manager themselves if needed


-- Iteration 0 (anchor): working table = {1}, result = {1}
    
-- Iteration 1: find employees where manager_id ∈ {1} and id != manager_id
-- → rows (2, Bob, 1) and (77, Robert, 1) match. Note that (1, Boss, 1) is filtered by the self-loop guard.
-- → new working table = {2, 77}, result = {1, 2, 77}
    
-- Iteration 2: find employees where manager_id ∈ {2, 77}
-- → (4, Daniel, 2) matches.
-- → working table = {4}, result = {1, 2, 77, 4}
    
-- Iteration 3: find employees where manager_id ∈ {4}
-- → (7, Luis, 4) matches.
-- → working table = {7}, result = {1, 2, 77, 4, 7}
    
-- Iteration 4: find employees where manager_id ∈ {7}
-- → nothing. Working table empty → terminate.
    
-- Final filter strips out 1, giving {2, 77, 4, 7}. Matches the expected output.