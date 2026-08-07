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

-- 情境 A：10M × 4
-- 比較次數 = 10M × 4 = 4×10⁷
-- 這個 join 幾乎 0 成本
-- 1. 4 列 discount_tiers 只佔一個 8KB page，Materialize 之後常駐 shared_buffers，實際上在 CPU cache 裡
-- 2. 每列 order 做 4 次 numeric 比較，沒有任何 I/O
-- 3. 真正的成本是 orders 那 10M 列的 Seq Scan 本身

-- 情境 B：10M × 100K
-- 比較次數 = 10M × 10⁵ = 10¹²
-- 100K 列的 tier 表已經塞不進 work_mem，Materialize 會 spill 到磁碟，變成每列 order 都在讀暫存檔。
-- 瓶頸從 I/O 換成了 CPU + 內表反覆掃描。這已經不是慢，是不能跑。
-- 加上 GiST 索引後：10M × log₂(10⁵) ≈ 10M × 17 ≈ 1.7×10⁸ 次索引走訪。降了四個數量級，變成分鐘級。

-- 回答範本
--「Nested Loop 的成本是 O(N×M)，所以要分兩段看：

-- 4 筆的情況：4×10⁷ 次比較，但 4 列只佔一個 page，Materialize 之後全在 cache 裡，沒有 I/O。真正的成本是 orders 那 10M 列的 Seq Scan —— join 只加了 10~30% overhead。這個規模不用優化，加索引反而更慢，因為要讀 10M 列的話 Seq Scan 一定贏 Index Scan。

-- 10 萬筆的情況：10¹² 次比較，直接不可行。而且內表塞不進 work_mem，Materialize 會 spill 到磁碟，每列 order 都在讀暫存檔。瓶頸從 I/O 移到 CPU 和內表重掃。

-- 這時唯一的解是把內側的 Seq Scan 換成 Index Scan —— GiST 索引可以把 10⁵ 降到 log(10⁵)≈17，總量從 10¹² 降到 10⁸ 量級，變成分鐘級。」

-- 技巧：「粗略的判準是：內表能不能常駐記憶體。幾百到幾千列以內，Nested Loop 完全可以接受；上萬列開始就必須有索引。而且成本是乘法關係，內表大小的影響是線性放大到每一列外表上的。」

-- 3. 「Band Join 可以用 index 加速嗎？加在哪個欄位？」

-- 考點：B-tree 的維度限制
-- 這題大部分人會答錯，因為直覺是「在 min_amount 和 max_amount 上建索引」。這個答案只對一半，而錯的那一半才是考點。

-- 原理：B-tree 只能剪掉一半
-- 謂詞是 `min_amount <= X AND max_amount >= X`。假設你建了複合索引 (min_amount, max_amount)：
-- `min_amount <= X` → B-tree 可以 seek，從索引開頭掃到 X 的位置。有效。
-- `max_amount >= X` → 不能當 seek 邊界。因為第一個欄位是範圍掃描，在這個範圍內第二個欄位是無序的，只能逐筆 filter。

-- 結果：索引平均要掃過一半的表。 10 萬列的 tier 表，掃 5 萬列再逐筆過濾。有幫助，但遠遠不夠。
-- 理論：
-- 一個區間是二維物件（在 (min, max) 平面上的一個點），而 min <= X <= max 是一個象限查詢。
-- B-tree 是一維有序結構，天生處理不了二維範圍查詢。

-- 正解：GiST + 範圍型別
CREATE INDEX idx_tier_range ON discount_tiers
  USING gist (numrange(min_amount, max_amount, '[)'));

-- 查詢端必須改用 @> 才吃得到索引
JOIN discount_tiers dt ON dt.amount_range @> o.amount

-- GiST 是可擴充的樹狀索引框架，範圍型別在上面實作了 @>（包含）和 &&（重疊），能真正做到 O(log n) 的區間查詢。
-- 計畫會從 Seq Scan + Join Filter 變成 Index Scan + Index Cond。

-- 回答範本:
-- 「能加速，但不能用 B-tree，這是重點。
-- 對 (min_amount, max_amount) 建 B-tree，只有 min <= X 能當 seek 邊界；第一欄是範圍掃描之後，第二欄在該範圍內是無序的，只能 filter。所以 B-tree 只剪掉一半，平均要掃半張表。
-- 根本原因是：一個區間本質上是 (min,max) 平面上的一個點，min <= X <= max 是象限查詢 —— 一維的 B-tree 處理不了二維範圍。
-- 正解是 GiST 索引 + 範圍型別，查詢用 @>。而且如果已經加了 EXCLUDE ... WITH && 的排它約束，那個索引本來就存在，等於約束和效能一起解決了。
-- 不過該加在哪張表要看誰是外側。如果 tier 表只有 4 筆、orders 要全掃，那其實不該加索引 —— Seq Scan 比 Index Scan 快。索引是給『大內表 + 逐列探查』的情境用的。」


-- 4. 「不用 JOIN，你能用 `CASE WHEN` 寫出同樣的結果嗎？兩種寫法各自的維護成本是什麼？」
select id, amount,
    case when amount < 100 then 'Bronze'
         when amount < 500 then 'Silver'
         when amount < 2000 then 'Gold'
         else 'Platinum'
    end as tier_name,
    case when amount < 100 then 0.000
         when amount < 500 then 0.050
         when amount < 2000 then 0.1000
         else 0.1500
    end as discount
from orders

-- CASE WHEN 在正確性上結構性地更安全
-- CASE WHEN 是由上而下、第一個命中就停

-- JOIN      = 彈性（資料驅動）  但正確性靠約束維持
-- CASE WHEN = 正確性（結構保證）但規則凍在程式裡