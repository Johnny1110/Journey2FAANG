-- ============================================================
-- Phase 1-02 — Price Tier Assignment
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- A1: 直覺的 BETWEEN 寫法（會少 3 筆）
-- ------------------------------------------------------------
select o.id, o.amount, dt.tier_name, dt.discount, round(o.amount * (1 - dt.discount), 3) as final_amount
from orders o
         join discount_tiers dt on o.amount between dt.min_amount and dt.max_amount;
-- ------------------------------------------------------------
-- A2: 為什麼 Platinum 不見了 — 三值邏輯推導
-- ------------------------------------------------------------

-- Because Platinums max_amount column is NULL, which is means when we put that column into comparision it will become:
-- o.amount between dt.min_amount and dt.max_amount
-- 2001.000 between 2000 and NULL:

-- 2000.000 BETWEEN 2000.000 AND NULL
-- = (2000.000 >= 2000.000) AND (2000.000 <= NULL)
-- = TRUE AND UNKNOWN
-- = UNKNOWN

-- JOIN ... ON / WHERE only keep value which compare to TRUE, FALSE, UNKNOWN will be discarded.

-- ------------------------------------------------------------
-- A3: 兩種修法（COALESCE / OR IS NULL）+ EXPLAIN 對比 -> coalesce 合併
-- ------------------------------------------------------------

-- OR IS NULL
select o.id, o.amount, dt.tier_name, dt.discount
from orders o
         join discount_tiers dt on o.amount >= dt.min_amount and (o.amount <= dt.max_amount or dt.max_amount is NULL);

-- COALESCE
select o.id, o.amount, dt.tier_name, dt.discount
from orders o
         join discount_tiers dt
             on o.amount between dt.min_amount and coalesce(dt.max_amount, 'Infinity'::numeric);

-- OR IS NULL: seq scan on order then seq scan on discount_tiers
-- COALESCE: seq scan on order then seq scan on discount_tiers

--  discount_tiers 只有 4 列、orders 只有 12 列。
--  在這個規模下 planner 無論如何都會選 Nested Loop + Seq Scan，因為讀索引的成本比整張表掃過去還高。兩個計畫相同不代表兩種寫法等價，只代表這組資料量測不出差異。
-- 要讓比較有意義，得把 discount_tiers 灌到幾萬列再測。而真正該講的加分點是:
-- PostgreSQL 對 band join / range join 的優化本來就很弱 — B-tree 索引只能加速 min_amount 那一半，另一半仍要逐列驗證。
-- 要在大表上做區間比對，正解是把區間存成 numrange + GiST 索引，用 @> 做包含判斷，那才會走 Index Scan。

-- ------------------------------------------------------------
-- A4: 訂單 10 的縫隙 — INNER JOIN 的隱藏風險 + schema 重新設計
-- ------------------------------------------------------------

-- INNER JOIN using missing 1 row to express error, and missing 1 row can not be observed in the result set.
-- order_id 10 just missing in the result list.
-- If this query is called by a operation financial report, it will cause the report to be inaccurate and misleading.
-- And also discount amount range has overlapping issue, same order will match multiple discount tiers, sum() will be incorrect.

-- How to prevent?
-- 1. assertion: count(*) result set should be equals to count(*) from orders.
-- 2. add constraint on schema to prevent overlapping discount tiers.

-- gap checking:
select * from (
    select tier_name, max_amount, lead(min_amount) over (order by min_amount) as next_min
    from discount_tiers
              ) t
where next_min is not null and max_amount < next_min;

-- overlapping discount tiers:
select a.tier_name, b.tier_name
from discount_tiers a
    join discount_tiers b on a.min_amount < b.min_amount and b.min_amount < coalesce(a.max_amount, 'Infinity'::numeric);

-- how do we change the table schema to prevent overlapping discount tiers?
-- We can drop the max_amount column and change to use lead() function to get the next min_amount as current tier's max_amount.
alter table discount_tiers drop column max_amount;

select tier_name, min_amount, lead(min_amount) over (order by min_amount) as max_amount, discount from discount_tiers;

-- using numrange:
CREATE TABLE discount_tiers (
                                tier_name    VARCHAR(20) PRIMARY KEY,
                                amount_range NUMRANGE NOT NULL,
                                discount     NUMERIC(4,3) NOT NULL,
                                EXCLUDE USING gist (amount_range WITH &&) -- overlapping ranges are not allowed
);

INSERT INTO discount_tiers VALUES
                               ('Bronze',   numrange(   0,  100, '[)'), 0.000), -- >= 0 && < 100 左開右閉
                               ('Silver',   numrange( 100,  500, '[)'), 0.050),
                               ('Gold',     numrange( 500, 2000, '[)'), 0.100),
                               ('Platinum', numrange(2000, NULL, '[)'), 0.150);

-- ------------------------------------------------------------
-- B1: ops 改壞設定後為什麼變 14 筆 + 找出被複製的訂單
-- ------------------------------------------------------------


-- because the discount_tiers amount range have overlapping issue:
-- Sliver from 100 to 999.99
-- ('Silver',    100.00,  999.99, 0.050),
-- ('Gold',      500.00, 1999.99, 0.100),
-- If order amount is 800, it could be Silver or Gold, which is the reason why business logic broke.

-- find out duplicate orders:
with cte as (select o.id, o.amount, dt.tier_name, dt.discount, dt.min_amount, dt.max_amount, count(o.id) over (partition by o.id) as duplicate_count
    from orders o
    join discount_tiers dt on o.amount >= dt.min_amount and (o.amount <= dt.max_amount or dt.max_amount is NULL)
    ) select id, amount, tier_name, discount, min_amount, max_amount from cte where duplicate_count > 1;
;

-- result:
id,amount,tier_name,discount,min_amount,max_amount
6,500.000,Gold,0.100,500.000,1999.990
6,500.000,Silver,0.050,100.000,999.990
11,750.000,Gold,0.100,500.000,1999.990
11,750.000,Silver,0.050,100.000,999.990
12,999.990,Gold,0.100,500.000,1999.990
12,999.990,Silver,0.050,100.000,999.990

-- If this query result count into financial report, it will cause double counting issue.

-- ------------------------------------------------------------
-- B2: 重疊稽核查詢
-- ------------------------------------------------------------

select a.tier_name as tier_a,
       b.tier_name tier_b,
       numrange(a.min_amount, a.max_amount, '[]') as range_a,
       numrange(b.min_amount, b.max_amount, '[]') as range_b
from discount_tiers a
    join discount_tiers b
        on (a.min_amount, a.tier_name) < (b.min_amount, b.tier_name)
        and (a.max_amount >= b.min_amount or a.max_amount is NULL)
order by a.min_amount;

-- ------------------------------------------------------------
-- B3: 縫隙偵測查詢
-- ------------------------------------------------------------

with cte as(
    select tier_name,
           max_amount,
           min_amount,
           lead(min_amount) over (order by min_amount) as next_min
    from discount_tiers)
select tier_name,
       max_amount,
       next_min,
       (next_min - max_amount) as gap
from cte where next_min - max_amount > 0;

-- ------------------------------------------------------------
-- B4: 資料庫層面根本擋掉重疊的機制
-- ------------------------------------------------------------

create table discount_tiers (
    tier_name varchar(20) primary key,
    amount_range numrange NOT NULL,
    discount numeric(4,3) NOT NULL,
    EXCLUDE USING gist (amount_range with &&) -- not allow overlapping ranges
);

-- overlapping is cross column constraint, so check constraint is not enough, unique also.
-- EXCLUSION CONSTRAINT is like a kind of unique constraint but it works for ranges and other data types.
-- in EXCLUDE, UNIQUE is `WITH =`, we using `WITH &&` range overlap operator to prevent overlapping ranges.

-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


-- 1. 「Band Join 的執行計畫長什麼樣？和等值 JOIN 的 Hash Join 有什麼不同？為什麼？」

-- Band join 只能走 Nested Loop —— 這不是 planner 選擇的結果，是它唯一的選項。
-- 範圍謂詞（>=、<=、BETWEEN）不是 hashable、也不是 mergejoinable 的運算子，這兩條路在 planner 生成計畫時就直接被排除了。
-- 怎麼從 EXPLAIN 看出來:
Hash Cond:   (a.id = b.id)          ← 等值，走 Hash
Merge Cond:  (a.id = b.id)          ← 等值，走 Merge
Join Filter: (a.amount >= b.min ...) ← 範圍，逐列驗證  ★
Index Cond:  ...                     ← 有索引在幫忙縮範圍

-- Join Filter 就是 band join 的指紋。典型計畫長這樣：

Nested Loop
  Join Filter: ((o.amount >= dt.min_amount) AND ...)
  Rows Removed by Join Filter: 33         ← ★ 這行是重點 (Nested Loop 未命中被丟棄的 part)
  -> Seq Scan on orders o
  -> Materialize
       -> Seq Scan on discount_tiers dt

-- 兩個要點：
-- 1). Materialize：內表被讀一次後暫存在記憶體，避免外表每一列都重掃一次磁碟。小表這招很有效。
-- 2). Rows Removed by Join Filter（要 EXPLAIN ANALYZE 才有）：這是 band join 的浪費指標。 它告訴你比對了幾次、丟掉幾次。Hash Join 是「算一次雜湊直接命中」，Nested Loop 是「比 M 次留 1 次」，這個數字就是差距的來源。

--回答範本：
-- Band join 的計畫是 Nested Loop + Join Filter，不會是 Hash Join —— 而且不是 planner 不想用，是不能用。
-- Hash Join 的前提是等值條件：雜湊會破壞順序，你沒辦法問雜湊表『所有小於 X 的 key 在哪』。Merge Join 也要等值，因為雙指標推進依賴相等判斷。範圍運算子既不 hashable 也不 mergejoinable，這兩條路在 planner 階段就被排除了。
-- 實務上看 EXPLAIN 就是看謂詞落在 Hash Cond 還是 Join Filter。落在 Join Filter 就代表在逐列驗證，這時要看 Rows Removed by Join Filter —— 那是被浪費掉的比較次數。

-- 2. 「如果 `orders` 有 1000 萬筆、`discount_tiers` 有 4 筆，這個 join 的成本是多少？如果 `discount_tiers` 有 10 萬筆呢？」
-->
-- 3. 「Band Join 可以用 index 加速嗎？加在哪個欄位？」
-->
-- 4. 「不用 JOIN，你能用 `CASE WHEN` 寫出同樣的結果嗎？兩種寫法各自的維護成本是什麼？」
-->