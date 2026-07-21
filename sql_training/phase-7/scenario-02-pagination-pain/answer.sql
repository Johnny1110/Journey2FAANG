-- Scenario 02: The Never-Ending Page Scroll
-- Your diagnosis, cursor-based pagination rewrite, and trade-offs go here.
--

-- 1. Why OFFSET degrades with large values:
Because offset will skip first N rows, which means when user select offset a very big number, the database engine will have to scan over all N rows to locate the target row data.
even though the query with indexes, the database engine will also iterate through the index B+ tree to find the target row data.

-- 2. Cursor-based pagination rewrite (show SQL for "next page")
-- first page query:
SELECT id, user_id, total_amount, status, created_at
FROM orders
ORDER BY created_at desc
    LIMIT 20;
-- next page query:
SELECT id, user_id, total_amount, status, created_at
FROM orders
WHERE created_at < '2026-07-21 00:46:54.569639 +00:00' -- last page, last row''s created_at
ORDER BY created_at desc
LIMIT 20;


-- 3. Trade-offs: cursor-based vs offset-based:
cursor-based pagination is more efficient for large datasets, because it avoids scanning through all previous rows.
However, it requires previous page's last row value(index) to locate the next page, which means developers need to manage state between query requests.
offset-based pagination is simpler to implement and understand, but it is not efficient for large datasets. when the offset value is not too large, offset-based pagination is better choice.

-- 4. (Optional) Additional index recommendation:
create index idx_orders_user_id_created_at on orders (user_id, created_at desc);


---------------------------------------------------------------------------------------------------------------
-- feedback
---------------------------------------------------------------------------------------------------------------

-- 1. Why OFFSET degrades with large values:

OFFSET is not jump to M row, but find order result, read and skip M row data, return data from M ~ M + limit N.
So the acture scanned row is offset M + limit N. total time complexxity is O(N+M) 

-- 2. Cursor-based pagination rewrite:

SELECT id, user_id, total_amount, status, created_at
FROM orders
ORDER BY created_at desc
    LIMIT 20;

-- next page query:
SELECT id, user_id, total_amount, status, created_at
FROM orders
WHERE (created_at, id) < (?, ?) -- last page, last row's (created_at, id)
ORDER BY created_at desc
LIMIT 20;

-- 3. Trade-offs: cursor-based vs offset-based:
Cursor can not jump to certain page, it can only jump 1 page step by step.
Offset can jump to certain page, so it is good to use in admin dashboard, Cursor is fit in FB, IG, X, Infinite Scroll use case.

-- 4. 4. (Optional) Additional index recommendation:
create index for cursor query
(created_at, id)