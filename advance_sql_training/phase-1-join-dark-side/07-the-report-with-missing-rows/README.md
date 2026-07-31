# Phase 1-07 — The Report With Missing Rows

> **難度**：★★★★☆
> **核心技巧**：CROSS JOIN 維度骨架、`ON` vs `WHERE` 的致命差異、`generate_series` 造時間軸
> **對應基礎題**：[LC 1179. Reformat Department Table](../../../sql_training/reformat_department_table)（你當初的 Pivot 練習）

<br>

---

<br>

## Interview Context

> *面試官：*「這是我們 CEO 每月看的區域營收報表。四個區域 × 四個月，應該是 **16 行**。
>
> 但這張報表這個月只印出 **6 行**。CEO 問我：『LATAM 呢？我們不是在拉美有業務嗎？』
>
> 我看了工程師寫的 SQL，他用了 `LEFT JOIN`，理論上不該漏。你找一下問題在哪。」

<br>

這一題會讓你踩到 SQL 裡**最常見也最安靜**的一個 bug。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS regions;

CREATE TABLE regions (
    id   INT PRIMARY KEY,
    name VARCHAR(30) NOT NULL
);

CREATE TABLE sales (
    id        SERIAL PRIMARY KEY,
    region_id INT NOT NULL REFERENCES regions(id),
    sold_on   DATE NOT NULL,
    amount    NUMERIC(10,2) NOT NULL
);

INSERT INTO regions (id, name) VALUES
(1, 'APAC'),
(2, 'EMEA'),
(3, 'NA'),
(4, 'LATAM');       -- ← 這一季一筆訂單都沒有

INSERT INTO sales (region_id, sold_on, amount) VALUES
-- APAC：1、2、3 月都有
(1, '2026-01-08', 12000.00),
(1, '2026-01-22',  8500.00),
(1, '2026-02-14', 15000.00),
(1, '2026-03-05',  9800.00),
(1, '2026-03-27', 11200.00),
-- EMEA：只有 1、3 月（2 月完全沒有）
(2, '2026-01-15', 22000.00),
(2, '2026-03-11', 18500.00),
-- NA：只有 2 月
(3, '2026-02-20', 31000.00);
-- LATAM：完全沒有資料
-- 4 月：所有區域都沒有資料
```

<br>

### 報表期間：2026-01-01 ~ 2026-04-30

### 正確答案：**16 行**（4 區域 × 4 個月）

```
+--------+---------+----------+
| region | month   | revenue  |
+--------+---------+----------+
| APAC   | 2026-01 | 20500.00 |
| APAC   | 2026-02 | 15000.00 |
| APAC   | 2026-03 | 21000.00 |
| APAC   | 2026-04 |     0.00 |
| EMEA   | 2026-01 | 22000.00 |
| EMEA   | 2026-02 |     0.00 |   ← 沒賣但要有行
| EMEA   | 2026-03 | 18500.00 |
| EMEA   | 2026-04 |     0.00 |
| LATAM  | 2026-01 |     0.00 |   ← 整個區域沒資料，還是要有 4 行
| LATAM  | 2026-02 |     0.00 |
| LATAM  | 2026-03 |     0.00 |
| LATAM  | 2026-04 |     0.00 |
| NA     | 2026-01 |     0.00 |
| NA     | 2026-02 | 31000.00 |
| NA     | 2026-03 |     0.00 |
| NA     | 2026-04 |     0.00 |
+--------+---------+----------+
```

<br>

---

<br>

## The Broken Query

工程師寫的版本：

```sql
SELECT r.name AS region,
       TO_CHAR(s.sold_on, 'YYYY-MM') AS month,
       COALESCE(SUM(s.amount), 0) AS revenue
FROM regions r
LEFT JOIN sales s ON s.region_id = r.id
WHERE s.sold_on BETWEEN '2026-01-01' AND '2026-04-30'
GROUP BY r.name, TO_CHAR(s.sold_on, 'YYYY-MM')
ORDER BY 1, 2;
```

**回傳 6 行。** 他有寫 `LEFT JOIN`，也有寫 `COALESCE`。

<br>

---

<br>

## Your Task

### Q1 — `LEFT JOIN` 為什麼失效了？

工程師寫了 `LEFT JOIN`，為什麼 LATAM 還是不見了？

請說明 SQL 的**邏輯執行順序**：`FROM` → `JOIN` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY`。

然後推導：LATAM 在 JOIN 之後長什麼樣（提示：`s.*` 全是 NULL），接著 `WHERE s.sold_on BETWEEN ...` 對它求值是什麼，會發生什麼事。

**寫出這句結論**：把 LEFT JOIN 右表的條件放在 `WHERE`，等於把 `LEFT JOIN` 降級成 `_____ JOIN`。

### Q2 — 第一次修正

把日期條件從 `WHERE` 移到 `ON`。重跑。

現在是 **7 行**，LATAM 回來了 —— 但它長這樣：

```
| LATAM  | (NULL)  | 0        |
```

回答：
- `month` 為什麼是 NULL？（提示：`TO_CHAR(NULL, 'YYYY-MM')` 是什麼）
- LATAM 只有 **1 行**，不是 4 行。為什麼？
- 這個結果能交給 CEO 嗎？**還缺什麼？**

### Q3 — 為什麼還是不夠

即使 Q2 修好了，2026-04 這個月**還是不會出現在任何一行**。

為什麼？（提示：`month` 這個欄位的值是從哪裡來的？）

**寫出這句結論**：報表的維度值只能來自 `_____`，不能來自 `_____`。

### Q4 — 完整解法

寫出回傳完整 16 行的查詢。核心思路：

1. 用 `generate_series` 造出**月份骨架**（4 個月）
2. `CROSS JOIN` 區域表 → 得到 4 × 4 = 16 行的**完整維度骨架**
3. 再 `LEFT JOIN` 實際銷售資料
4. `COALESCE` 補 0

### Q5 — 順序敏感度測試

把你 Q4 的答案做以下三種改動，各自會發生什麼？（先預測，再實測）

| 改動 | 你的預測 | 實際結果 |
|------|---------|---------|
| `CROSS JOIN` 改成 `INNER JOIN ... ON true` | ? | ? |
| `LEFT JOIN` 改成 `INNER JOIN` | ? | ? |
| 把 `COALESCE(SUM(s.amount), 0)` 改成 `SUM(COALESCE(s.amount, 0))` | ? | ? |

**第三個特別注意** — 這兩種寫法在這一題結果相同，但有一種在**其他情況**下會出錯。哪一種？什麼情況？

<br>

---

<br>

## 面試官的追問

> 1. 「`ON` 和 `WHERE` 對 `INNER JOIN` 來說有差別嗎？對 `LEFT JOIN` 呢？為什麼？」
>
> 2. 「如果我想要『只顯示有銷售的月份，但每個月份都要包含全部四個區域』，查詢怎麼改？」
>
> 3. 「`generate_series` 造骨架的做法，資料量大的時候有沒有問題？有沒有更好的做法？」
>    （提示：日期維度表 / calendar table — 這是資料倉儲的標準做法）
>
> 4. 「這張報表要加上『同期比較』（YoY），每一行多一欄去年同月的營收。怎麼寫？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — LEFT JOIN + WHERE 的降級效應</summary>

`LEFT JOIN` 之後，LATAM 這一行是：

```
r.id = 4, r.name = 'LATAM', s.id = NULL, s.sold_on = NULL, s.amount = NULL
```

接著 `WHERE s.sold_on BETWEEN '2026-01-01' AND '2026-04-30'`：

`NULL BETWEEN ... AND ...` → **UNKNOWN** → `WHERE` 不放行 → **LATAM 被丟掉**。

**把右表的條件放在 `WHERE`，等於把 `LEFT JOIN` 降級成 `INNER JOIN`。**

這是 SQL 最常見的隱形 bug — 因為它不報錯，只是安靜地少幾行。而報表少幾行，通常沒人發現，直到 CEO 問「LATAM 呢？」

**唯一的例外**：`WHERE s.something IS NULL`（anti-join 模式，Phase 1-01 用過）。那是**故意**利用這個行為。

</details>

<details>
<summary>Hint 2 — 造月份骨架</summary>

```sql
SELECT generate_series(
    DATE '2026-01-01',
    DATE '2026-04-01',
    INTERVAL '1 month'
)::DATE AS month_start;
```

回傳 4 行：`2026-01-01`, `2026-02-01`, `2026-03-01`, `2026-04-01`。

注意結束值用 `2026-04-01` 不是 `2026-04-30` — `generate_series` 是**閉區間**，用 `04-30` 也只會生成到 `04-01`（因為 `04-01 + 1 month = 05-01 > 04-30`），但寫 `04-01` 意圖更清楚。

</details>

<details>
<summary>Hint 3 — 完整骨架</summary>

```sql
WITH months AS (
    SELECT generate_series(DATE '2026-01-01', DATE '2026-04-01', INTERVAL '1 month')::DATE AS m
),
skeleton AS (
    SELECT r.id AS region_id, r.name AS region, m.m AS month_start
    FROM regions r
    CROSS JOIN months m              -- ← 4 × 4 = 16 行，完整骨架
)
SELECT sk.region,
       TO_CHAR(sk.month_start, 'YYYY-MM') AS month,
       COALESCE(SUM(s.amount), 0) AS revenue
FROM skeleton sk
LEFT JOIN sales s
       ON s.region_id = sk.region_id
      AND s.sold_on >= sk.month_start
      AND s.sold_on <  sk.month_start + INTERVAL '1 month'    -- ← 條件在 ON，不在 WHERE
GROUP BY sk.region, sk.month_start
ORDER BY sk.region, sk.month_start;
```

**核心心法：報表的維度值必須來自「骨架」，不能來自「事實資料」。** 事實資料沒有的維度，它自己長不出來。

</details>

<details>
<summary>Hint 4 — COALESCE(SUM()) vs SUM(COALESCE())</summary>

- `COALESCE(SUM(s.amount), 0)`：先聚合。組內全是 NULL 時 `SUM` 回傳 NULL，再被 `COALESCE` 轉成 0。✓
- `SUM(COALESCE(s.amount, 0))`：先轉換。每個 NULL 變 0，再加總 → 也是 0。✓

這題兩者結果相同。但如果需求是「**沒有資料時顯示 NULL，有資料但金額為 0 時顯示 0**」，兩者就不同了 — 後者會把「沒資料」和「金額為 0」混為一談，資訊被抹掉。

還有一個更實際的差異：`AVG(COALESCE(x, 0))` 和 `COALESCE(AVG(x), 0)` **永遠不等價**。前者把 NULL 當 0 拉低平均，後者只在全空時給 0。財報上這是天差地別。

**通則：先聚合再補值（`COALESCE(AGG(x), default)`），除非你確實想讓 NULL 參與運算。**

</details>
