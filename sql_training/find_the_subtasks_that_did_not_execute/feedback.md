# Feedback — LC 1767. Find the Subtasks That Did Not Execute

## Score: 8.5 / 10

---

## Correctness

**The query is correct.** Tracing it against the testing data:

| CTE row | In Executed? | Result |
|---------|-------------|--------|
| (1, 1)  | yes         | skip   |
| (1, 2)  | yes         | skip   |
| (1, 3)  | no          | ✓      |
| (2, 1)  | yes         | skip   |
| (2, 2)  | no          | ✓      |
| (3, 1)  | yes         | skip   |
| (3, 2)  | yes         | skip   |
| (3, 3)  | no          | ✓      |
| (3, 4)  | yes         | skip   |

Output: `(1,3), (2,2), (3,3)` — correct.

---

## What You Did Well

- **Right mental model**: generating all expected (task_id, subtask_id) pairs first and then anti-joining against `Executed` is the cleanest pattern for "find the missing rows" problems.
- **Termination condition is correct**: `WHERE t1.subtask_id + 1 <= t2.subtasks_count` correctly bounds the recursion to each task's own count.
- **Anti-join idiom**: `LEFT JOIN … WHERE exe.subtask_id IS NULL` is idiomatic and performs well in most engines.

---

## Issues & Suggestions

### 1. `UNION` vs `UNION ALL` in the recursive CTE (Minor, -1 point)

```sql
-- yours
union

-- better
union all
```

Recursive CTEs almost always need `UNION ALL`. Using `UNION` forces the engine to deduplicate every intermediate result set, which is `O(n log n)` per step instead of `O(n)`. Because your termination condition guarantees no duplicate rows are generated, `UNION ALL` is both correct and faster here.

> Note: some engines (MySQL before 8.0.19) **require** `UNION ALL` in recursive CTEs; `UNION` can raise a syntax error.

### 2. Alias confusion: `t1` and `t2` are swapped semantically (Style, -0.5 point)

```sql
from tasks as t2        -- the "base" reference
join cte as t1          -- the "recursive/previous" reference
```

Conventionally `t1` feels like it should be the first/base table and `t2` the derived one. Swap the aliases (or use descriptive names like `prev` and `base`) to reduce the mental load when reading:

```sql
from cte  as prev
join tasks as base on prev.task_id = base.task_id
where prev.subtask_id + 1 <= base.subtasks_count
```

### 3. Alternative: cross join with a numbers helper (Bonus awareness)

For databases that support `GENERATE_SERIES` (PostgreSQL) or where the max subtask count is known and small (≤ 20 per the problem), a cross-join approach avoids recursion entirely:

```sql
-- PostgreSQL / BigQuery style
SELECT t.task_id, n.subtask_id
FROM   Tasks t
JOIN   GENERATE_SERIES(1, 20) AS n(subtask_id)
       ON n.subtask_id <= t.subtasks_count
WHERE  (t.task_id, n.subtask_id) NOT IN (SELECT task_id, subtask_id FROM Executed);
```

Knowing both approaches (recursive CTE for portability, generate_series for readability) is valuable in interviews.

---

## Corrected Query

```sql
WITH RECURSIVE cte AS (
    SELECT task_id, 1 AS subtask_id
    FROM   Tasks

    UNION ALL

    SELECT base.task_id, prev.subtask_id + 1
    FROM   cte   AS prev
    JOIN   Tasks AS base ON prev.task_id = base.task_id
    WHERE  prev.subtask_id + 1 <= base.subtasks_count
)
SELECT cte.task_id, cte.subtask_id
FROM   cte
LEFT JOIN Executed AS exe
       ON cte.task_id = exe.task_id
      AND cte.subtask_id = exe.subtask_id
WHERE  exe.subtask_id IS NULL;
```

---

## Summary

| Dimension      | Assessment |
|----------------|-----------|
| Logic          | Correct    |
| Termination    | Correct    |
| Performance    | Minor issue (`UNION` vs `UNION ALL`) |
| Readability    | Slightly confusing alias naming |
| Portability    | Good (standard recursive CTE syntax) |

Solid attempt overall — the core pattern is right. Fix `UNION` → `UNION ALL` before submitting to avoid potential engine-level rejections.
