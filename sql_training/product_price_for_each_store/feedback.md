# Feedback: LC 1777. Product's Price for Each Store

## Score: 9 / 10

## Evaluation

**Correctness**: The query produces exactly the expected output. Using `CASE WHEN` + `GROUP BY` + `MAX` is the standard Pivot pattern and works correctly here because `(product_id, store)` is the primary key — there's at most one price per product per store, so `MAX` simply surfaces that single value.

**Time Complexity**: O(n) — a single scan of the `products` table with GROUP BY. This is optimal; no joins or subqueries needed.

**Space Complexity**: O(k) where k = number of distinct `product_id` values, for the GROUP BY hash table. Also optimal.

**Style**: Clean, well-formatted, easy to read at a glance.

## Minor Notes

- The `ORDER BY product_id` is not required by the problem ("any order"), but it doesn't hurt and actually makes output deterministic — a good habit.
- `MAX` is fine here, but since `(product_id, store)` is the PK, any aggregate (`MIN`, `SUM`, `AVG`) would produce the same result. `MAX`/`MIN` is the idiomatic choice for this Pivot pattern.
- No NULL handling needed — the implicit `ELSE NULL` in `CASE WHEN` is exactly what we want for missing stores.

## Verdict

This is a textbook Pivot solution. No improvements needed. The same pattern extends directly to LC 1179 (12 months instead of 3 stores) and LC 618 (different pivot mechanics but same core idea).
