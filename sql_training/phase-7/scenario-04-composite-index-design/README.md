# Scenario 04 — The Index That Doesn't Work

## Interview Context

> *Interviewer:* "Last week a developer added a composite index on the `events` table to speed up our analytics dashboard. They created `idx_events_status_created_user` on `(status, created_at, user_id)`. But the dashboard query — which filters by `user_id` and `created_at` — still does a Seq Scan. The developer is confused. Can you explain what went wrong and how to fix it?"

---

## Database Schema

```sql
CREATE TABLE events (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT NOT NULL,
    event_type    VARCHAR(30) NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'active',
    payload       JSONB,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- The index the developer created:
CREATE INDEX idx_events_status_created_user ON events (status, created_at, user_id);
```

## Testing Data

```sql
-- 150,000 events across 10,000 users, last 90 days
INSERT INTO events (user_id, event_type, status, payload, created_at)
SELECT
    (random() * 10000 + 1)::BIGINT,
    (ARRAY['login','logout','purchase','view','click','search','share','comment','like','upload'])[floor(random() * 10 + 1)],
    (ARRAY['active','completed','failed','pending'])[floor(random() * 4 + 1)],
    jsonb_build_object('ip', '192.168.' || (random()*255)::int || '.' || (random()*255)::int),
    NOW() - (random() * INTERVAL '90 days')
FROM generate_series(1, 150000) AS g;
```

---

## The Slow Query (Dashboard)

```sql
-- The analytics dashboard runs this to show a user's recent activity
SELECT id, event_type, status, created_at, payload
FROM events
WHERE user_id = 4823
  AND created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC
LIMIT 50;
```

---

## EXPLAIN ANALYZE Output

```
                                                         QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=3078.32..3078.45 rows=50 width=128)
        (actual time=45.234..45.256 rows=50 loops=1)
   ->  Sort  (cost=3078.32..3080.89 rows=1028 width=128)
             (actual time=45.232..45.242 rows=50 loops=1)
         Sort Key: created_at DESC
         Sort Method: top-N heapsort  Memory: 41kB
         ->  Seq Scan on events  (cost=0.00..3054.00 rows=1028 width=128)
                                 (actual time=0.034..42.891 rows=487 loops=1)
               Filter: (created_at >= (now() - '30 days'::interval)
                        AND (user_id = 4823))
               Rows Removed by Filter: 149513
 Planning Time: 0.156 ms
 Execution Time: 45.312 ms
```

The existing index `idx_events_status_created_user (status, created_at, user_id)` is **NOT used**.

---

## A Second Query (works fine)

```sql
-- This query DOES use the index
SELECT COUNT(*)
FROM events
WHERE status = 'completed'
  AND created_at >= NOW() - INTERVAL '7 days';
```

EXPLAIN output for this query:
```
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Aggregate  (cost=412.34..412.35 rows=1 width=8)
            (actual time=2.345..2.346 rows=1 loops=1)
   ->  Index Only Scan using idx_events_status_created_user on events
       (cost=0.00..408.12 rows=1687 width=0)
       (actual time=0.034..2.012 rows=1823 loops=1)
         Index Cond: (status = 'completed' AND created_at >= (now() - '7 days'::interval))
         Heap Fetches: 0
 Planning Time: 0.089 ms
 Execution Time: 2.389 ms
```

---

## Interviewer's Questions

1. **"Both queries filter on two columns of the index. Why does the second query use the index but the first one doesn't?"**

2. **"Explain the leftmost prefix principle. How does it apply to this composite index `(status, created_at, user_id)`?"**

3. **"What composite index should the developer have created for the dashboard query? Write the DDL and explain your column order."**

4. **"Does the original index `(status, created_at, user_id)` still have value, or should we drop it?"**

5. **"If we needed to support BOTH queries efficiently, how many indexes would you create? What are they?"**

---

## Your Task

Write your answers in `answer.sql`. Include:
- Explanation of why the first query can't use the existing index (leftmost prefix)
- The corrected index DDL for the dashboard query
- A comparison table showing which query patterns each index supports
- Decision on whether to keep or drop the original index

---

## Hints (unfold if stuck)

<details>
<summary>Hint 1</summary>
A B-tree composite index on `(A, B, C)` can efficiently serve queries that filter on:
- `A` alone
- `A` + `B`
- `A` + `B` + `C`
It CANNOT efficiently serve queries that filter only on `B` and `C` without `A`. The first query filters on `user_id` (which is C — the third column) and `created_at` (which is B — the second column) but neither uses `status` (A — the first column). The index is useless for this query.
</details>

<details>
<summary>Hint 2</summary>
Think of a composite index like a phone book sorted by `(last_name, first_name)`. You can quickly find all "Smith, John" entries. But you CANNOT efficiently find all people named "John" — the book is sorted by last name first, so Johns are scattered everywhere.
</details>

<details>
<summary>Hint 3</summary>
For the dashboard query `WHERE user_id = ? AND created_at > ?`, the best composite index is `(user_id, created_at)`. Equality column first, range column second. The `status` column would go after the range if needed (or be omitted since the query doesn't filter by it).
</details>
