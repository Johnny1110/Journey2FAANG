# Scenario 01 — The Login Slowdown

## Interview Context

> *Interviewer:* "We have a user authentication service. The login endpoint queries the `users` table by email to fetch the password hash. The table has grown to about 2 million rows and the login query has gotten noticeably slow — p99 latency is around 800ms. We already have an index on the `email` column. Can you take a look?"

---

## Database Schema

```sql
CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users (email);
```

## Testing Data

```sql
-- Generate 100,000 realistic users (enough to see Seq Scan vs Index Scan difference)
INSERT INTO users (email, password_hash, full_name, is_active, created_at)
SELECT
    'user' || g || '@example.com',
    md5(random()::text),
    'User ' || g,
    CASE WHEN random() > 0.05 THEN TRUE ELSE FALSE END,
    NOW() - (random() * INTERVAL '730 days')
FROM generate_series(1, 100000) AS g;

-- Add a few known users for testing
INSERT INTO users (email, password_hash, full_name) VALUES
    ('Alice.Johnson@Company.com', 'hash_alice_123', 'Alice Johnson'),
    ('Bob.Smith@Company.com',   'hash_bob_456',   'Bob Smith'),
    ('Carol.Davis@Company.com', 'hash_carol_789',  'Carol Davis');
```

---

## The Slow Query

This is the query the login endpoint runs:

```sql
SELECT id, email, password_hash, full_name, is_active
FROM users
WHERE LOWER(email) = LOWER('Alice.Johnson@Company.com');
```

---

## EXPLAIN ANALYZE Output

```
                                                     QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 Seq Scan on users  (cost=0.00..2487.00 rows=500 width=93)
                    (actual time=12.345..78.912 rows=1 loops=1)
   Filter: (lower((email)::text) = 'alice.johnson@company.com'::text)
   Rows Removed by Filter: 100002
 Planning Time: 0.152 ms
 Execution Time: 78.987 ms
```

*(Note: with 2 million rows, this would be ~1.5 seconds of Seq Scan)*

---

## Interviewer's Questions

1. **"We have an index on `email`. Why is the database doing a Seq Scan instead of an Index Scan?"**

2. **"Can you propose at least two different ways to fix this? Compare the trade-offs."**

3. **"If we decide to keep the `LOWER()` call in the query, what kind of index would you create? Write the DDL."**

4. **"What other common patterns cause an index to be ignored by the query planner? Name at least three."**

---

## Your Task

Write your diagnosis and solutions in `answer.sql`. Include:
- Root cause explanation (as if explaining to the interviewer)
- The index DDL you would create
- Any alternative solutions you'd mention
- A list of common index-avoidance pitfalls

---

## Hints (unfold if stuck)

<details>
<summary>Hint 1</summary>
The `LOWER()` function is applied **on the column**, not on the constant. Any function or expression wrapping an indexed column prevents the planner from using a B-tree index on that column.
</details>

<details>
<summary>Hint 2</summary>
PostgreSQL supports **expression indexes** (also called functional indexes). You can index `LOWER(email)` directly.
</details>

<details>
<summary>Hint 3</summary>
The simpler fix: normalize email casing at INSERT/UPDATE time (always store lowercase). Then the query just needs `WHERE email = LOWER(?)` with the plain index.
</details>
