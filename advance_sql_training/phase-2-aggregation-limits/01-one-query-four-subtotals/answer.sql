-- ============================================================
-- Phase 2-01 — One Query, Four Subtotals
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- A1: UNION ALL 笨方法 + EXPLAIN（這張表掃了幾次？）
-- ------------------------------------------------------------

-- union all 3 select
select region, product, sum(amount) as revenue from sales group by region, product
union all
select region, NULL, sum(amount) as revenue from sales group by region
union all
select NULL, NULL, sum(amount) as revenue from sales
order by region, product;

-- Seq Scan on sales table 3 times

-- 1st select: seq scan + hashAggregate (6 rows)
-- 2th select: seq scan + hashAggregate (3 rows)
-- 3th select: seq scan + aggregate (1 row)

-- ------------------------------------------------------------
-- A2: ROLLUP 改寫 + EXPLAIN 對比
-- ------------------------------------------------------------

select region, product, sum(amount) as revenue 
from sales group by rollup (region, product)
order by region, product;

-- Seq Scan on sales table (row = 6), + MixedAggregate.
-- Hash Key: region, product"
-- Hash Key: region
-- Group Key: ()


-- ------------------------------------------------------------
-- B1: 兩行 (NULL,NULL) 各代表什麼
-- ------------------------------------------------------------

-- revenue = 400 -> Unknown region total revenue
-- revenue = 900 -> All region total revenue

-- ------------------------------------------------------------
-- B2: ROLLUP 展開成哪 3 個 grouping set，兩行為什麼撞在一起
-- ------------------------------------------------------------

-- answer is 3 ROLLUP group set: (region, product), (region), ALL

-- 400: group set (region), region null is unknown region. product null is group set null.
-- 900: group set ALL, region null is group set null. product null is group set null.

-- ------------------------------------------------------------
-- B3: GROUPING() 的定義 — 為什麼它能分辨而 IS NULL 不行
-- ------------------------------------------------------------

select region, product, sum(amount) as revenue,
       grouping(region) as GPR, grouping(product) as GPP
from sales group by rollup (region, product)
order by region, product;

-- 400:  GROUPING(region): 0, GROUPING(product): 1
-- 900:  GROUPING(region): 1, GROUPING(product): 1
-- 一個欄位留白，可能是「不詳」，也可能是「不適用」。光看空白分不出來，所以正式的表單會另外加一個「不適用」的勾選框。GROUPING() 就是那個勾選框。

-- ------------------------------------------------------------
-- B4: 加上 row_type 與 (unknown)/(all) 標籤的完整報表（注意排序）
-- ------------------------------------------------------------


select coalesce(region,
                case
                    when region is null and grouping(region) = 1 and grouping(product) = 1 then '(all)'
                    else '(unknown)' end
       )                          as region,
       coalesce(product, '(all)') as product,
       sum(amount)                as revenue,
       case
           when grouping(region) = 1 and grouping(product) = 1 then 'GRAND TOTAL'
           when grouping(region) = 0 and grouping(product) = 1 then 'region subtotal'
           else 'detail'
           end                    as row_type
from sales
group by rollup (region, product)
ORDER BY GROUPING(sales.region),
         GROUPING(sales.product),
         sales.region,
         sales.product;

-- ------------------------------------------------------------
-- B5: GROUPING(a,b) 位元遮罩 — 四種組合的值 + 簡潔 CASE
-- ------------------------------------------------------------

-- 00: 0, 01: 1, 10: 2, 11: 3

-- 00: per region, per product
-- 01: per region, all products
-- 11: all regions, all products

-- sql:



select coalesce(region,
                case
                    when region is null and grouping(region) = 1 and grouping(product) = 1 then '(all)'
                    else '(unknown)' end
       )                          as region,
       coalesce(product, '(all)') as product,
       sum(amount)                as revenue,
       case
           grouping(region, product)
           when 0 then 'detil'
           when 1 then 'region subtotal'
           when 3 then 'GRAND total'
           end                    as row_type
from sales
group by rollup (region, product)
ORDER BY GROUPING(sales.region),
         GROUPING(sales.product),
         sales.region,
         sales.product;

-- ------------------------------------------------------------
-- C1: CUBE 多出的 2 行是什麼 + ROLLUP/CUBE grouping set 數量通式
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- C2: 用 GROUPING SETS 手寫等價於 ROLLUP 的查詢
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- C3: 只要產品小計不要區域小計 — 為什麼非 GROUPING SETS 不可
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


