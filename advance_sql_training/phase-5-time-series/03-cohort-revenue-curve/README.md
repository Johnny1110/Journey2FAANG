# Phase 5-03 — Cohort Revenue Curve

> **難度**：★★★★☆
> **核心技巧**：Cohort 分群、月份偏移計算、累計曲線、**per-user 正規化**
> **對應基礎題**：[LC 1384. Total Sales Amount by Year](../../../sql_training/total_sales_amount_by_year)（你當初的年度營收彙總）

<br>

---

<br>

## Interview Context

> *面試官：*「行銷想知道：**不同月份進來的用戶，哪一批比較會花錢？**
>
> 一月的用戶已經待了半年，二月的才五個月 —— 直接比總營收不公平。
>
> 給我一張圖，橫軸是『註冊後第幾個月』，縱軸是**每個用戶的累計貢獻**。」

<br>

**這是 LTV（客戶終身價值）分析的基礎。** 難點不在 SQL，在於**把不同 cohort 拉到同一個起跑線上比較**。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS purchases;
DROP TABLE IF EXISTS members;

CREATE TABLE members (
    id          INT PRIMARY KEY,
    signup_date DATE NOT NULL
);

CREATE TABLE purchases (
    id            SERIAL PRIMARY KEY,
    user_id       INT NOT NULL,
    purchase_date DATE NOT NULL,
    amount        NUMERIC(10,2) NOT NULL
);

INSERT INTO members (id, signup_date) VALUES
(1, '2026-01-10'), (2, '2026-01-20'), (3, '2026-01-25'),   -- 一月 cohort：3 人
(4, '2026-02-05'), (5, '2026-02-14');                      -- 二月 cohort：2 人

INSERT INTO purchases (user_id, purchase_date, amount) VALUES
(1, '2026-01-11', 100),   -- 註冊當月
(1, '2026-02-03',  50),   -- 第 1 個月
(1, '2026-03-08',  30),   -- 第 2 個月
(2, '2026-01-22', 200),   -- 註冊當月，之後就沒了
(3, '2026-03-15', 500),   -- 沉睡兩個月才爆發
(4, '2026-02-06',  80),
(4, '2026-03-02',  40);
-- user 5 從來沒買過東西
```

<br>

### 正確答案

```
   cohort   | cohort_size | month_n | revenue | cumulative | cum_per_user
------------+-------------+---------+---------+------------+--------------
 2026-01-01 |           3 |       0 |  300.00 |     300.00 |       100.00
 2026-01-01 |           3 |       1 |   50.00 |     350.00 |       116.67
 2026-01-01 |           3 |       2 |  530.00 |     880.00 |       293.33
 2026-02-01 |           2 |       0 |   80.00 |      80.00 |        40.00
 2026-02-01 |           2 |       1 |   40.00 |     120.00 |        60.00
```

<br>

---

<br>

## Part A — 建立曲線

### A1 — 月份偏移

核心是算出「這筆消費發生在註冊後第幾個月」。

**注意**：不是 `(purchase_date - signup_date) / 30`。

- user 1 註冊 `01-10`，消費 `02-03` —— 只隔 24 天，但算「第 1 個月」還是「第 0 個月」？
- user 4 註冊 `02-05`，消費 `03-02` —— 隔 25 天。
- **正確做法是先把兩個日期都截到「月初」再比較。** 為什麼？

寫出月份偏移的算式，驗證 user 1 的三筆消費分別是第 0、1、2 個月。

### A2 — 分群與加總

寫出完整查詢，輸出 `cohort` / `cohort_size` / `month_n` / `revenue`。

### A3 — 累計

加上 `cumulative`（該 cohort 到第 N 個月的累計營收）。

用 window function（[Phase 3-01](../../phase-3-window-deep-water/01-the-last-value-that-lied) 的預設 frame 在這裡剛好就是你要的）。

### A4 — per-user 正規化

加上 `cum_per_user = cumulative / cohort_size`。

**這一欄才是重點** —— 它讓不同大小的 cohort 可以直接比較。

<br>

---

<br>

## Part B — 讀懂這張表

### B1 — 一月 vs 二月

- 第 0 個月：一月 cohort 每人 100.00，二月 cohort 每人 40.00
- 第 1 個月：一月累計 116.67，二月累計 60.00

**一月 cohort 看起來比較好。** 但這個結論可靠嗎？

回答：
- 一月 cohort 只有 3 人，二月只有 2 人。**樣本這麼小，差異有意義嗎？**
- 一月的 `month_n = 2` 那格跳到 293.33，是因為 user 3 一筆買了 500。**一個人就佔了 57%。**
- 你會怎麼跟行銷解釋這張表？**你會建議他們據此加碼一月的行銷渠道嗎？**

### B2 — 未成熟格子（又來了）

假設今天是 `2026-03-31`。

- 二月 cohort 有 `month_n = 2` 的資料嗎？
- 一月 cohort 有，二月沒有。**這是「二月 cohort 表現差」還是「時間還沒到」？**
- 怎麼在報表上區分？

> 這和 [5-01](../01-the-retention-matrix) Part C2 是同一個陷阱。
> **所有 cohort 分析都是三角形的**，而三角形的空白處最容易被誤讀。

### B3 — 沒消費的人

user 5 註冊了但從沒消費。

- 他有進 `cohort_size` 嗎？（應該要）
- 他有進 `revenue` 嗎？（不該）
- **如果分母漏掉他，`cum_per_user` 會怎樣？** 算一次「只用有消費的人當分母」的版本，比較差多少。
- 這兩個指標分別叫什麼？（提示：ARPU vs ARPPU）

### B4 — 缺月

一月 cohort 如果 `month_n = 1` 完全沒有消費，你的查詢會輸出那一行嗎？

- 應該輸出嗎？（累計曲線斷一格會怎樣？）
- 用 [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的骨架心法補齊。
- 補齊之後，`cumulative` 那一欄會有什麼改變？（提示：window function 需要連續的行才能正確累計）

<br>

---

<br>

## Part C — 實務

### C1 — 完整矩陣

輸出標準的 cohort 矩陣（橫軸 `month_n`，一列一個 cohort），用 Pivot 呈現：

```
   cohort   | size |   m0   |   m1   |   m2   |  m3
------------+------+--------+--------+--------+------
 2026-01-01 |    3 | 100.00 | 116.67 | 293.33 |
 2026-02-01 |    2 |  40.00 |  60.00 |        |
```

用 [Phase 2-01](../../phase-2-aggregation-limits/01-one-query-four-subtotals) / 基礎 Phase 6 的 Pivot 技巧。

### C2 — LTV 預測

行銷問：「一月 cohort 的 12 個月 LTV 會是多少？」

- 你只有 3 個月的資料。**能回答嗎？**
- 如果要外推，你需要什麼假設？
- **這是 SQL 問題還是統計問題？** 面試時你會怎麼回應這個要求？

### C3 — 規模與增量

- 5 年的資料、1000 萬會員，這張表要跑多久？
- Cohort 矩陣的**歷史格子會變嗎**？（一月 cohort 的 m0 明天會改變嗎？）
- 根據上一題的答案，設計一個增量更新策略。

<br>

---

<br>

## 面試官的追問

> 1. 「為什麼要用 per-user 而不是總營收？舉一個用總營收會做出錯誤決策的例子。」
>
> 2. 「如果 cohort 要用『首次消費月份』而不是『註冊月份』來分，查詢要改哪裡？兩種分法分別回答什麼問題？」
>
> 3. 「怎麼比較兩個 cohort 的曲線『形狀』而不只是絕對值？」
>
> 4. 「退款怎麼處理？負數的 amount 會讓累計曲線下降，這樣對嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 月份偏移為什麼要先截月</summary>

**錯誤做法**：`(purchase_date - signup_date) / 30`

user 1：註冊 `01-10`，消費 `02-03` → 相差 24 天 → `24/30 = 0` → 被算成「第 0 個月」。

但 `02-03` 明明是**二月**，相對一月註冊就是**第 1 個月**。

**正確做法**：兩邊都截到月初再算月份差。

```sql
(date_part('year',  age(date_trunc('month', p.purchase_date),
                        date_trunc('month', m.signup_date))) * 12
 + date_part('month', age(date_trunc('month', p.purchase_date),
                          date_trunc('month', m.signup_date))))::int AS month_n
```

比較簡潔的等價寫法：

```sql
(date_part('year',  p.purchase_date) - date_part('year',  m.signup_date)) * 12
+ (date_part('month', p.purchase_date) - date_part('month', m.signup_date))
```

**心法：cohort 分析比的是「日曆月份的距離」，不是「經過了幾天」。**

</details>

<details>
<summary>Hint 2 — 完整骨架</summary>

```sql
WITH cohorts AS (
    SELECT date_trunc('month', signup_date)::date AS cohort, COUNT(*) AS cohort_size
    FROM members GROUP BY 1
),
tagged AS (
    SELECT date_trunc('month', m.signup_date)::date AS cohort,
           ((date_part('year',  p.purchase_date) - date_part('year',  m.signup_date)) * 12
            + (date_part('month', p.purchase_date) - date_part('month', m.signup_date)))::int AS month_n,
           p.amount
    FROM purchases p
    JOIN members m ON m.id = p.user_id
),
agg AS (
    SELECT cohort, month_n, SUM(amount) AS revenue
    FROM tagged GROUP BY cohort, month_n
)
SELECT a.cohort, c.cohort_size, a.month_n, a.revenue,
       SUM(a.revenue) OVER (PARTITION BY a.cohort ORDER BY a.month_n) AS cumulative,
       ROUND(SUM(a.revenue) OVER (PARTITION BY a.cohort ORDER BY a.month_n) / c.cohort_size, 2) AS cum_per_user
FROM agg a
JOIN cohorts c ON c.cohort = a.cohort
ORDER BY a.cohort, a.month_n;
```

`SUM(...) OVER (PARTITION BY cohort ORDER BY month_n)` 用的就是**預設 frame**（`UNBOUNDED PRECEDING AND CURRENT ROW`）—— [Phase 3-01](../../phase-3-window-deep-water/01-the-last-value-that-lied) 教的那件事，這裡剛好是我們要的累計行為。

</details>

<details>
<summary>Hint 3 — ARPU vs ARPPU</summary>

- **ARPU**（Average Revenue Per User）= 總營收 / **所有**用戶數 → 分母含 user 5
- **ARPPU**（Average Revenue Per **Paying** User）= 總營收 / **有付費的**用戶數 → 分母不含 user 5

一月 cohort 第 0 個月：
- ARPU = 300 / **3** = **100.00**
- ARPPU = 300 / **2** = **150.00**（user 3 那時還沒買）

**兩個都是正確的指標，回答不同的問題**：
- ARPU 衡量「整體變現效率」（含沒付費的人）
- ARPPU 衡量「付費用戶的價值」

**報表上混用這兩個是災難** —— 用 ARPPU 的數字去乘總用戶數，會嚴重高估營收預測。

B3 想訓練的就是：**看到一個「平均」，先問分母是誰。** 這是 [Phase 2-05](../../phase-2-aggregation-limits/05-the-weighted-average-trap) 的延續。

</details>

<details>
<summary>Hint 4 — B4 缺月為什麼會壞掉累計</summary>

假設一月 cohort 的 `month_n = 1` 沒有任何消費，`agg` 就不會產生那一行。

結果：

```
 month_n | revenue | cumulative
---------+---------+------------
       0 |  300.00 |     300.00
       2 |  530.00 |     830.00     ← 直接從 0 跳到 2
```

`cumulative` 的**數值仍然正確**（累計和不受影響），但：
- 畫成折線圖會變成一條斜線直接連過去，看不出中間那個月是零
- 如果要算「平均每月成長率」，分母的月數就錯了
- 要和另一個 cohort 逐月對齊比較時，格子對不上

**修法**：用 `generate_series` 造出 `month_n` 骨架，`CROSS JOIN` cohort，再 `LEFT JOIN` 實際資料補零 —— 完全是 [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的做法。

**注意**：骨架的長度不能寫死，每個 cohort 能觀察到的月數不同（一月 cohort 比二月多一個月）。這就是 B2 的未成熟格子問題 —— 骨架要按「該 cohort 到今天為止經過了幾個月」動態產生。

</details>
