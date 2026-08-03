-- ============================================================
-- Phase 1-01 — The NULL That Ate Your Results
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- Q1: 展開 NOT IN，逐項寫出 TRUE/FALSE/UNKNOWN，說明 WHERE 對 UNKNOWN 的處理
-- ------------------------------------------------------------

-- NOT IN unpacks to customer_id <> ? AND customer_id <> ? AND customer_id <> ? ...
-- SQL comparisons involving NULL don't return TRUE ot FALSE, they return UNKNOWN.
-- A row only shows up in the result if the whole WHERE clause evaluates to TRUE.
-- If one of bound parameters ? is NULL, then customer_id <> NULL is UNKNOWN for every single row, no matter what customer_id is.

-- Back to the query:

SELECT name
FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);

-- customer_id contains NULL, so it will be exculded due to UNKNOWN case.
-- only `WHERE UNKNOWN` left.
-- SQL is Three-Valueed Logic, not Boolean Logic. -> (TRUE, FALSE, UNKNOWN)

-- ------------------------------------------------------------
-- Q2: 保留 NOT IN 結構的修法
-- ------------------------------------------------------------

SELECT name
FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders where customer_id IS NOT NULL);

-- ------------------------------------------------------------
-- Q3: NOT EXISTS 版本
-- ------------------------------------------------------------

SELECT name
FROM customers
where not exists (select 1 from orders where customers.id = orders.customer_id);

-- ------------------------------------------------------------
-- Q3: LEFT JOIN ... IS NULL 版本
-- ------------------------------------------------------------

select c.name
from customers as c
         left join orders as o on o.customer_id = c.id
where o.id is null;

-- ------------------------------------------------------------
-- Q4: 三種寫法的取捨（語意安全性 / 可讀性 / 執行計畫）
-- ------------------------------------------------------------

-- Semantic Safety (Schema 改了會不會出問題)

-- NOT IN: It is most dnagerous, any subquery have NULL result whole query failed.
-- NOT EXISTS: safe option. NULL is OK, (perfer NOT EXISTS over NOT IN).
-- LEFT JOIN: also safe. if join is not unique key, like customers 1, orders 1, 1, 1, ,1 ... -> left join will produce many duplicate rows.

-- Readable

-- NOT EXISTS > LEFT JOIN > NOT IN

-- Execution Plan

-- NOT EXISTS: usually be `Hash Anti Join`
-- LEFT JOIN IS NULL: usually be `Hash Anti Join`
-- Hash Anti Join: 是一種資料庫查詢最佳化演算法，用來找出「存在於第一張表，但不存在於第二張表」的資料（對應 NOT IN 或 NOT EXISTS 語法）。它先將右側的資料表載入記憶體建立雜湊表（Hash Table），再掃描左側資料表進行比對與排除。

-- ------------------------------------------------------------
-- Q5: 邊界 — 空表 / customer_id 改 NOT NULL / NOT IN 空集合
-- ------------------------------------------------------------

-- 1. 如果 `orders` 表是**空的**，三種寫法各回傳什麼？
-- ans: 
-- NOT IN -> all customers anme show up.
-- NOT EXISTS -> all customers anme show up.
-- LEFT JOIN -> all customers anme show up.

-- 2. 如果把 `customer_id` 改成 `NOT NULL`，三種寫法的**結果**會一致嗎？**執行計畫**會一致嗎？

-- 3 type query results: All same, because no NULL case.
-- exec plan: not sure, could be Hash Anti Join or Hashed SubPlan.
-- Hashed SubPlan 是關聯式資料庫（例如 PostgreSQL）在執行包含子查詢（Subquery，如 IN 或 ANY 運算式）的 SQL 語句時，資料庫最佳化工具所採用的一種查詢執行計畫（Execution Plan）策略。

-- 3. `NOT IN` 的子查詢如果回傳的是**空集合**（0 筆），`x NOT IN ()` 求值是什麼？和有 NULL 的情況有什麼本質差異？

-- TRUE for every row (all rows returned)
-- x NOT IN () == NOT (FALSE) == TRUE

-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


-- 1. 「`IN` 遇到 NULL 也會有問題嗎？還是只有 `NOT IN`？」

-- ans: yes, because the main issue is NULL comparison is UNKNOWN, it won't turn out to TRUE or FLASE.
-- like select 4 IN (1, 2, NULL, 3);
-- it will turn to:
-- 4 = 1 OR 4 = 2 OR 4 = NULL OR 4 = 3
-- FALSE OR FALSE OR UNKNOWN OR FALSE = UNKNOWN
-- it wont return any data, beause where only accept TRUE.
-- but it will be safer than NOT IN
-- 4 NOT IN (1,2,NULL,3) -> 4 <> 1 AND 4 <> 2 AND 4 <> NULL AND 4 <> 3
-- TRUE AND TRUE AND UNKNOWN AND TRUE = UNKNOWN
-- so the whole where comparision is not work.

-- 2. 「如果我在子查詢加上 `WHERE customer_id IS NOT NULL`，是不是就等價於 `NOT EXISTS` 了？有沒有任何情況不等價？」

-- generally speak, both lead to same result.but semetic and planner is different, so I won't say they are the same.
-- for example:
select name from customers where in not in (
    select customer_id 
    from orders
    where customer_id is not null
);

select name from customers c
where not exists (
    select 1 from orders o where o.customer_id = c.id
    );

-- they both have the same outcome. because NULL has been excluded, so not in (...) won't have UNKNOWN case any more.
-- NOT IN means:      x not in collection -> x <> ALL(...) -> planner will do it like `Hash SubPlan` or `HASH Anti Join`
-- NOT EXISTS means: there is no row match to rules. -> planner will do it like `HASH Anti Join`

WHERE NOT EXISTS (
    SELECT 1
    FROM t2
    WHERE t1.a=t2.a
      AND t1.b=t2.b
);

(a, b) not in (...);

-- In this case, NULL will be complicated.
-- final answer: result is same. sematic is not same, safety is not same.


-- 3. 「你說 `NOT EXISTS` 比較安全。那為什麼還有這麼多人寫 `NOT IN`？`NOT IN` 有什麼場合是更好的？」

-- NOT IN is not bad, it just more sensitive about the NULL case. If I know subquery  won't have NULL data in collection then NOT IN is 100% avaliable to use.
-- The real issue is not `NOT IN`, it is sensitive about table schema.

-- sometime I perfer to use `not in` because it have more concreate sematic.
-- for example:

WHERE role_id NOT IN (
    SELECT role_id
    FROM disabled_roles
)

-- NOT EXISTS (...) is more difficult to understand.

-- using not exists is moe like just in case.
-- for example:

schema: customer_id NOT NULL

-- one year later, another ppl change the schema:
ALTER TABLE orders
ALTER COLUMN customer_id DROP NOT NULL;

-- then sql will return 0 rows as result. it is not a SQL error, just business logic broken.


-- 4. 「`LEFT JOIN ... WHERE x IS NULL` 這種寫法，如果 `orders.customer_id` 有大量重複值，會有什麼問題？」

-- It won't affect the result. it will affect performance.
-- if customer_id=1 have 10000 rows in orders table, then `left join` must create 10000 rows join.
-- eventhough `WHERE o.id IS NULL` will filter out those data, it still need join that much times useless data.

-- NOT EXISTS:

SELECT *
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.customer_id=c.id
);

-- we take a username = Alice, customer_id = 1, then go to orders find any row orders.customer_id = 1 then we can just stop, becasue we already know Alice(id=1) exists.

--Final: LEFT JOIN 的風險不是結果錯，而是可能產生大量中間資料（row explosion）；NOT EXISTS 表達的是存在性檢查，通常更符合 Anti Join 的語意，也避免了不必要的資料擴張。