# LC 1795. Rearrange Products Table — Feedback

## Score: 7 / 10

## What's Good

- Correct use of `UNION ALL` to unpivot the three store columns into rows. This is the right pattern for this problem.
- The `WHERE price IS NOT NULL` correctly filters out products that are unavailable in a given store.
- The query produces the expected output.

## What Can Be Improved

### 1. Redundant `CASE WHEN` (main issue)

```sql
case when store1 is not null
     then store1
     else null
end as price
```

This is functionally identical to just writing `store1 as price`. If `store1` is `NULL`, the SELECT already returns `NULL` — there's no need for the `CASE`. Removing it makes the query cleaner and shows you understand that columns naturally pass through NULL values.

### 2. Unnecessary outer subquery

Instead of wrapping the whole UNION ALL in `SELECT * FROM (...) AS t WHERE price IS NOT NULL`, you can push the NULL filter into each individual SELECT:

```sql
SELECT product_id, 'store1' AS store, store1 AS price
FROM products WHERE store1 IS NOT NULL
```

This is more readable and avoids the extra nesting. Both approaches are logically correct, but the flatter version is preferred in an interview setting.

### 3. Formatting consistency

The indentation between the three UNION ALL blocks is inconsistent — the first block has different spacing than the others. Clean formatting matters in an interview; it signals attention to detail.

## Hint for Improvement

Try rewriting without the `CASE WHEN` and without the outer subquery. The cleanest version should look something like:

```sql
SELECT product_id, 'store1' AS store, store1 AS price FROM products WHERE store1 IS NOT NULL
UNION ALL
SELECT product_id, 'store2', store2 FROM products WHERE store2 IS NOT NULL
UNION ALL
SELECT product_id, 'store3', store3 FROM products WHERE store3 IS NOT NULL
ORDER BY product_id, price;
```

Want to give it another shot?
