# Enhancement

## -- 1. Why query A (WHERE user_id=? AND created_at>?) cannot use idx_events_status_created_user (status, created_at, user_id):

Better answer: 

> A composite B-Tree index is most effective when the query constrains the index columns from the leftmost column onward. Equality predicates on leading columns allow the database to efficiently use subsequent columns.

> Without the leading status column, the index cannot efficiently narrow down the search range based on created_at and user_id, so PostgreSQL chooses a Sequential Scan as the cheaper plan.


## -- 4. Decision: keep or drop the original index? Why?

如果：

```
90% rows = active
10% rows = completed / failed / pending
```

那麼 `WHERE status = 'active'` 確實可能選擇 Sequential Scan，因為：__要找 90% 的 table__．

這時候使用 index 可能比直接掃 table 更慢。

但是：

```
WHERE status = 'completed'
```

如果 completed 只佔 3%，這個 index 可能仍然非常有價值。所以不是 status 整體很常見，因此不要放入 index，而是要看實際 Query Pattern + Selectivity + Data Distribution．

