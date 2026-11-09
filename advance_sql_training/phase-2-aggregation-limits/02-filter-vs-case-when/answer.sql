-- ============================================================
-- Phase 2-02 — FILTER vs CASE WHEN
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- A1: 為什麼 COUNT(CASE ... ELSE 0) 回傳 10 — COUNT() 到底數什麼 + 結論句
-- ------------------------------------------------------------

-- should change to this:
SELECT COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed_orders,
       COUNT(*) AS total_orders
FROM orders;

-- COUNT(expr) 數的是 expr 不為 NULL 的列數，不是 expr 的值，更不是條件成立的筆數。

-- ------------------------------------------------------------
-- A2: 四種正確寫法
-- ------------------------------------------------------------

-- 1.
SELECT COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed_orders,
       COUNT(*) AS total_orders
FROM orders;

-- 2.
SELECT SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
       COUNT(*) AS total_orders
FROM orders;

-- 3.
SELECT COUNT(1) filter (where status = 'completed') AS completed_orders,
       COUNT(*) AS total_orders
FROM orders;

-- 4.
SELECT SUM(1) filter (where status = 'completed') AS completed_orders,
       COUNT(*) AS total_orders
FROM orders;

-- ------------------------------------------------------------
-- A3: SUM(CASE) vs COUNT(FILTER) 在空集合下的差異 + 報表風險
-- ------------------------------------------------------------

-- 實驗 1：表裡有 10 筆資料，但沒有任何一筆是 'shipped'
SELECT SUM(CASE WHEN status = 'shipped' THEN 1 ELSE 0 END) AS sum_case,
       SUM(1)   FILTER (WHERE status = 'shipped')          AS sum_filter,
       COUNT(*) FILTER (WHERE status = 'shipped')          AS count_filter
FROM orders;

-- 實驗 2：WHERE 把所有資料濾掉，聚合函數收到 0 筆輸入
SELECT SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS sum_case,
       SUM(1)   FILTER (WHERE status = 'completed')          AS sum_filter,
       COUNT(*) FILTER (WHERE status = 'completed')          AS count_filter
FROM orders
WHERE created_at > '2099-01-01';

-- 問題 1：實驗 2 的 sum_case 為什麼是 NULL？
-- 提示：實驗 2 裡，那個 CASE WHEN ... ELSE 0 END 一共被執行了幾次？「ELSE 0 保證有值」這件事，在這裡還有機會發揮作用嗎？
-- 因為沒有資料，所以 case 一次都沒被執行到，「ELSE 0 保證有值」至少也需要有一筆資料．所以是 NULL

-- 問題 2：sum_filter 為什麼在實驗 1 就變 NULL 了？
-- 它和 count_filter 收到的列數一模一樣，為什麼一個給 0、一個給 NULL？
-- 滿足條件才會 sum 1，可是一個滿足條件的 row 都沒有．count() 雖然也沒有能滿足條件，但是 count() 會回傳 0，sum() 則是 NULL．

-- ------------------------------------------------------------
-- B1: 用 FILTER 一次做完整個儀表板 + CASE WHEN 版本對比
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- B2: AVG 三種寫法 — 175 vs 70 的推導 + 商業後果
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- B3: FILTER + DISTINCT 的求值順序
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- C1: <> 得 5 vs IS DISTINCT FROM 得 6 — 差的那筆是誰
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- C2: NULL status 跑哪去了 + 各狀態加總 = 總數的自我檢查
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


