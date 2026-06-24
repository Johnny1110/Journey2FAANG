-- Scenario 01: The Login Slowdown
-- Your diagnosis, solutions, and index DDL go here.
--
-- 1. Root cause (why Seq Scan despite the index on email):
-- The problem is we using LOWER(email) to wrapper email

-- 2. Proposed fixes + trade-offs:
-- make a functional index on email with lower(emial)

-- 3. Index DDL for the functional-index approach:
create index idx_users_lower_email on users(LOWER(email));

-- 4. Common index-avoidance pitfalls (at least 3):
