-- ============================================================
-- Phase 1-07 — The Report With Missing Rows
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- Q1: LEFT JOIN 為什麼失效 — 邏輯執行順序推導 + 結論句
-- ------------------------------------------------------------

-- for the original intent of this query, using left join means regions is main table,
-- LATAM has no sales data in the given date range.
-- FROM /JOIN selecting all rows (including LATAM NULL), WHERE filtering out the NULLs from the sales table, GROUP BY only group the remaining rows.
-- LATAM rows: NULL BETWEEN '2026-01-01' AND '2026-04-30'
-- So the LATAM NULL rows always be UNKNOWN, and filtered out by WHERE clause.
-- Final conclusion: put LEFT JOIN on clause in where clause, make LEFT JOIN behave like INNER JOIN.

-- ------------------------------------------------------------
-- Q2: 條件移到 ON（會變 7 行，LATAM 的 month 是 NULL）
-- ------------------------------------------------------------

-- TO_CHAR(NULL, 'YYYY-MM') 會返回 NULL.
-- 因為主表是 regions. LATAM 原本有一筆．由於後面有 group by r.name, TO_CHAR(s.sold_on, 'YYYY-MM') 所以如果 region 在目標月有資料才會列出．沒有預設就只有一 row.
    -- LEFT JOIN 保證左婊每一行至少出現一次
    -- GROUP BY 只會把已存在的行合併成組，LATAM 只有一 row，所以只輸出 1 row。
-- 應該補上每一個地區的所有月份資料，沒有資料也要補．

-- ------------------------------------------------------------
-- Q3: 為什麼 2026-04 還是不出現 + 結論句
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Q4: 完整的 16 行解法（骨架 CROSS JOIN + LEFT JOIN + COALESCE）
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Q5: 三種改動的預測 vs 實測（特別是 COALESCE(SUM()) vs SUM(COALESCE()))
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


