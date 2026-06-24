# Scenario 02 — The Never-Ending Page Scroll

## Interview Context

> *Interviewer:* "We have an admin dashboard that lists all orders with pagination. The frontend calls `GET /api/orders?page=5000&size=20`. Users are complaining that clicking to later pages takes several seconds. The query looks simple — it has an `ORDER BY` and a `LIMIT` with `OFFSET`. The table has about 5 million rows. What's going on?"

---

## Database Schema

```sql
CREATE TABLE orders (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT NOT NULL,
    total_amount  NUMERIC(10,2) NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_created_at ON orders (created_at);
```

## Testing Data

```sql
-- Generate 200,000 orders spread over the last 2 years
INSERT INTO orders (user_id, total_amount, status, created_at)
SELECT
    (random() * 50000 + 1)::BIGINT,
    (random() * 500 + 10)::NUMERIC(10,2),
    (ARRAY['pending','confirmed','shipped','delivered','cancelled'])[floor(random() * 5 + 1)],
    NOW() - (random() * INTERVAL '730 days')
FROM generate_series(1, 200000) AS g;
```

---

## The Slow Query

The API runs this for page 5000 (page size = 20):

```sql
SELECT id, user_id, total_amount, status, created_at
FROM orders
ORDER BY created_at DESC
OFFSET 100000
LIMIT 20;
```

---

## EXPLAIN ANALYZE Output (page=5000, offset=100000)

```
                                                                   QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=6251.44..6252.69 rows=20 width=32)
        (actual time=142.561..142.587 rows=20 loops=1)
   ->  Gather Merge  (cost=5397.25..7228.71 rows=14651 width=32)
                     (actual time=138.212..142.521 rows=100020 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=4397.23..4407.97 rows=6105 width=32)
                   (actual time=127.891..128.567 rows=33340 loops=3)
               Sort Key: created_at DESC
               Sort Method: external merge  Disk: 1848kB
               ->  Parallel Seq Scan on orders
                   (cost=0.00..3792.05 rows=6105 width=32)
                   (actual time=16.723..52.891 rows=33340 loops=3)
 Planning Time: 0.234 ms
 Execution Time: 143.089 ms
```

*(Note: with 5 million rows, the sort spills to disk and latency spikes to seconds.)*

---

## Interviewer's Questions

1. **"Why does page 5000 take longer than page 1? The query looks the same except for the OFFSET value."**

2. **"What does PostgreSQL actually do when it processes `OFFSET N LIMIT M`? Walk me through the steps it takes."**

3. **"Can you rewrite this query to use cursor-based pagination (also called keyset pagination)? Show me the SQL for fetching the 'next page'."**

4. **"What are the trade-offs of cursor-based pagination vs offset-based pagination? When would you still choose OFFSET?"**

5. **"If the business absolutely requires jumping to arbitrary pages (e.g., page 5000 directly), what other strategies could help?"**

---

## Your Task

Write your answers in `answer.sql`. Include:
- Explanation of why OFFSET degrades with large values
- The cursor-based pagination rewrite
- A brief comparison of trade-offs
- Optional: the DDL for any additional index you'd recommend

---

## Hints (unfold if stuck)

<details>
<summary>Hint 1</summary>
`OFFSET 100000` does NOT skip 100,000 rows like an array index. The database still reads, sorts, and then discards those 100,000 rows before returning your 20.
</details>

<details>
<summary>Hint 2</summary>
Cursor-based pagination uses the last value from the previous page as a filter: `WHERE created_at < :last_cursor ORDER BY created_at DESC LIMIT 20`. This lets the index seek directly to the right position.
</details>

<details>
<summary>Hint 3</summary>
The cursor column must be **deterministic** — if multiple rows share the same `created_at`, you need a tiebreaker (like adding `id` as a secondary sort key) to avoid skipping or duplicating rows.
</details>
