-- Scenario 01: The Login Slowdown
-- Your diagnosis, solutions, and index DDL go here.
--
-- 1. Root cause (why Seq Scan despite the index on email):
-- - The problem is we using LOWER(email) to wrapper email

-- 2. Proposed fixes + trade-offs:
-- - make a functional index on email with lower(emial)

-- 3. Index DDL for the functional-index approach:
create index idx_users_lower_email on users(LOWER(email));

-- 4. Common index-avoidance pitfalls (at least 3):
-- - Using functions on indexed columns in WHERE clauses
-- - Not considering the data types when creating indexes
-- - Creating too many indexes, which can slow down INSERT/UPDATE operations

------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------

-- Refinement

-- 1. Root cause (why Seq Scan despite the index on email):
B+ Tree index is built on the raw column value (emial)
The query is searching on expression: lower(email) not email
Since the index value is different from searched expression, Postgresql can not use the B+ Tree index.
Therefore it fallback to Seq Scan.

The planner can only use an index when the search predicate matches the indexed expression.

-- 2. Proposed fixes + trade-offs:
Solution-1: make Expression index: create INDEX idx_users_lower_email on users (LOWER(email))
Pros: minimal code changing
Cons: extra index mantainance, every insert update need compute LOWER() once.

Solution-2: Normalize data, insert update with LOWER(email)
Pros: normal index, fatest 
Cons: migration required, application discipline required

-- 3. Index DDL for the functional-index approach:
create index CONCURRENTLY idx_users_lower_email
on users(lower(email));

-- 4. Common index-avoidance pitfalls (at least 3):
1. Function on indexed column like: LOWER(), DATE(), SUBSTRING()
2. Leading wildcard like: where name like '%abc'
3. Arithmetic: salary*2>100
4. Implicit cast: WHERE bigint_col='1'
5. OR condition: WHERE email='a' OR phone='b'
6. Low selectivity: WHERE is_active=true (90% is true, seq scan is faster than index scan)
7. Not left-most prefix: index(a, b) -> select * from t1 where b = ? (without a condition)
8. Type mismatch: text, varchar, numeric
9. small table: planner think seq scan is faster.