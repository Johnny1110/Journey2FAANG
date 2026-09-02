-- ============================================================
-- Phase 1-05 — Top-3 Orders per Customer, Four Ways
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- 解法 A: Window Function
-- ------------------------------------------------------------

select *
from (select c.id                                                           as customer_id,
             c.name                                                         as name,
             o.id                                                           as order_id,
             o.created_at                                                   as created_at,
             row_number() over (partition by o.customer_id order by o.created_at desc) as rn
      from customers as c
               inner join orders as o on c.id = o.customer_id) as t
where rn <= 3
order by customer_id, rn;

-- ------------------------------------------------------------
-- 解法 B: LATERAL JOIN
-- ------------------------------------------------------------

select t.*, row_number() over (partition by t.customer_id order by t.created_at desc) as rn
from customers c
         cross join lateral (
    select o.customer_id, c.name, o.id as order_id, o.created_at
    from orders o
    where o.customer_id = c.id
    order by o.created_at desc
    limit 3
    ) t
order by t.customer_id;


-- ------------------------------------------------------------
-- 解法 C: Correlated Subquery
-- ------------------------------------------------------------
-- `WHERE o.id IN (SELECT ... LIMIT 3)`

select c.id as customer_id, c.name, o.id as order_id, o.created_at,
       row_number() over (partition by c.id order by o.created_at desc) as rn
from customers c inner join orders o on c.id = o.customer_id
where o.id in (
    select o2.id from orders o2 where o2.customer_id = c.id
    order by o2.created_at desc
    limit 3
);

-- ------------------------------------------------------------
-- 解法 D: DISTINCT ON（或說明為何不適用）
-- ------------------------------------------------------------

select distinct on (customer_id) customer_id
from orders
order by customer_id, created_at desc;

-- `Distinct on` can not make top 3 kind of query naturally, because it's semantically designed to return top1.
-- we do have several approaches to make it work, like union 3 queries, but it is not a good idea to do so.

-- ------------------------------------------------------------
-- Q1: 四種解法的 EXPLAIN (ANALYZE, BUFFERS) 輸出貼在這裡 + 分析
-- ------------------------------------------------------------

-- A:
-- Index Scan using idx_orders_customer_created, without index cond which is means full seq table scan. actual rows = 200000,
-- index only provides sorting but not filtering.

--B:
--  Index Scan using idx_orders_customer_created (rows=3.00 loops=200). so actual 600 rows scanned.

--Buffer Diff:
-- A: Buffers: shared hit=200609
-- B: Buffers: shared hit=1202
-- A is 166.6 times more expensive than B in terms of buffer hits.

-- About Index:
-- A using index sorting only but not filtering.
-- B using index for filtering and sorting.

-- 以後看到任何 EXPLAIN，照這個順序：
--
-- 找最深的節點，看 actual rows
-- 有 loops>1 就乘
-- Scan 節點有沒有 Index Cond ← 這一項就能解掉八成問題
-- cost rows 跟 actual rows 差幾倍
-- buffers 除以行數，看每行成本

-- ------------------------------------------------------------
-- Q1b: PG 15+ Run Condition 做了什麼、沒做什麼
-- ------------------------------------------------------------

-- WindowAgg (actual rows=600.00)
--    Run Condition: (row_number() OVER w1 <= 3)

-- PG 15 把這個條件下推進 WindowAgg 內部。
-- 現在 WindowAgg 一旦在某個 partition 算到 rn = 4，就知道這個 partition 剩下的都不要了，直接跳過、不再往上吐。
-- 所以 actual rows = 200 × 3 = 600。

-- ------------------------------------------------------------
-- Q2: 四種情境下你選哪一種 — 寫出判斷公式
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Q3: 砍掉索引後各自變慢幾倍
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Q4: created_at 並列的處理
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Q5: 沒有訂單的客戶
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 面試官追問 1~5
-- ------------------------------------------------------------


