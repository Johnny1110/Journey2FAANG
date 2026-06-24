# Scenario 03 — The Daily Report That Times Out

## Interview Context

> *Interviewer:* "Our data team runs a daily revenue report every morning at 6 AM. It joins three tables — `orders`, `order_items`, and `products` — to calculate revenue by product category for the previous day. The query used to finish in under 2 seconds, but as the tables grew, it started timing out at our 30-second limit. We haven't added any indexes beyond the primary keys. Can you diagnose and fix it?"

---

## Database Schema

```sql
CREATE TABLE orders (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id            BIGSERIAL PRIMARY KEY,
    order_id      BIGINT NOT NULL REFERENCES orders(id),
    product_id    BIGINT NOT NULL,
    quantity      INT NOT NULL,
    unit_price    NUMERIC(10,2) NOT NULL
);

CREATE TABLE products (
    id            BIGSERIAL PRIMARY KEY,
    name          VARCHAR(200) NOT NULL,
    category      VARCHAR(50) NOT NULL,
    unit_cost     NUMERIC(8,2) NOT NULL
);
```

## Testing Data

```sql
-- 80,000 orders in the last 90 days
INSERT INTO orders (user_id, status, created_at)
SELECT
    (random() * 20000 + 1)::BIGINT,
    (ARRAY['pending','confirmed','shipped','delivered','cancelled'])[floor(random() * 5 + 1)],
    NOW() - (random() * INTERVAL '90 days')
FROM generate_series(1, 80000) AS g;

-- ~240,000 order items (average 3 items per order)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT
    o.id,
    (random() * 5000 + 1)::BIGINT,
    (random() * 5 + 1)::INT,
    (random() * 200 + 5)::NUMERIC(10,2)
FROM orders o
CROSS JOIN generate_series(1, 3) AS g;

-- 5,000 products across 20 categories
INSERT INTO products (name, category, unit_cost)
SELECT
    'Product ' || g,
    (ARRAY['Electronics','Clothing','Books','Food','Sports','Toys','Health','Home','Garden','Music',
           'Automotive','Office','Beauty','Baby','Pet','Tools','Jewelry','Games','Shoes','Other'])[floor(random() * 20 + 1)],
    (random() * 300 + 10)::NUMERIC(8,2)
FROM generate_series(1, 5000) AS g;
```

---

## The Slow Query

```sql
SELECT
    p.category,
    COUNT(DISTINCT o.id)   AS order_count,
    SUM(oi.quantity)        AS units_sold,
    SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p     ON p.id = oi.product_id
WHERE o.created_at >= '2026-06-23 00:00:00+08'
  AND o.created_at <  '2026-06-24 00:00:00+08'
  AND o.status IN ('confirmed', 'shipped', 'delivered')
GROUP BY p.category
ORDER BY total_revenue DESC;
```

---

## EXPLAIN ANALYZE Output (before adding indexes)

```
                                                           QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=17532.11..17532.16 rows=20 width=76)
       (actual time=28451.234..28451.247 rows=18 loops=1)
   Sort Key: (sum((oi.quantity * oi.unit_price))) DESC
   Sort Method: quicksort  Memory: 27kB
   ->  HashAggregate  (cost=17531.26..17531.61 rows=20 width=76)
                      (actual time=28450.891..28450.978 rows=18 loops=1)
         Group Key: p.category
         Batches: 1  Memory Usage: 49kB
         ->  Hash Join  (cost=4532.12..16817.33 rows=47652 width=41)
                        (actual time=512.345..28123.456 rows=8234 loops=1)
               Hash Cond: (oi.product_id = p.id)
               ->  Nested Loop  (cost=4012.78..15773.22 rows=47652 width=20)
                                (actual time=456.123..27801.234 rows=8234 loops=1)
                     ->  Seq Scan on orders o
                         (cost=0.00..4037.00 rows=890 width=8)
                         (actual time=45.234..127.456 rows=897 loops=1)
                         Filter: (created_at >= '2026-06-23 00:00:00+08'::timestamp with time zone
                                  AND created_at < '2026-06-24 00:00:00+08'::timestamp with time zone
                                  AND (status = ANY ('{confirmed,shipped,delivered}'::text[])))
                         Rows Removed by Filter: 79103
                     ->  Seq Scan on order_items oi
                         (cost=0.00..12.89 rows=54 width=28)
                         (actual time=27.891..30.812 rows=9 loops=897)
                         Filter: (order_id = o.id)
                         Rows Removed by Filter: 239991
               ->  Hash  (cost=371.00..371.00 rows=5000 width=23)
                         (actual time=55.891..55.892 rows=5000 loops=1)
                     Buckets: 8192  Batches: 1  Memory Usage: 342kB
                     ->  Seq Scan on products p
                         (cost=0.00..371.00 rows=5000 width=23)
                         (actual time=0.023..24.567 rows=5000 loops=1)
 Planning Time: 0.456 ms
 Execution Time: 28451.567 ms
```

*(28.4 seconds — just under the 30s timeout!)*

---

## Interviewer's Questions

1. **"Walk me through this EXPLAIN output. Which operation is eating most of the time, and why?"**

2. **"The Nested Loop on `order_items` reads all 240k rows 897 times. What index would eliminate this? Write the DDL."**

3. **"The Seq Scan on `orders` filters by `created_at` and `status`. What index would you create, and in what column order? Explain your reasoning."**

4. **"After adding indexes, we expect the planner to switch from Nested Loop to something else. What join strategy would you expect, and why?"**

5. **"What is a covering index, and would one help here?"**

---

## Your Task

Write your answers in `answer.sql`. Include:
- Diagnosis: identify the bottleneck from the EXPLAIN output
- At least 2 `CREATE INDEX` statements with justification for column ordering
- Explanation of the expected plan change after indexing
- Optional: the `EXPLAIN` output you'd expect after optimization

---

## Hints (unfold if stuck)

<details>
<summary>Hint 1</summary>
The killer is the Nested Loop: for each of the 897 matching orders, PostgreSQL does a full Seq Scan on `order_items` (240k rows). That's 897 × 240k = ~215 million row reads. An index on `order_items.order_id` turns each loop iteration into an Index Scan reading ~3 rows.
</details>

<details>
<summary>Hint 2</summary>
For the `orders` table filter, a composite index on `(created_at, status)` lets PostgreSQL seek to the date range first (prefix match), then filter by status. Order matters: the equality/range column goes first, the IN filter goes second.
</details>

<details>
<summary>Hint 3</summary>
After adding indexes, the Nested Loop should become a Hash Join or Merge Join — PostgreSQL will read the 897 orders via an Index Scan, fetch their items via an Index Scan, build a hash table, and join. The total row reads drop from ~215 million to maybe ~10,000.
</details>
