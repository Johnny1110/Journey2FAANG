# Phase 3-06 — Rolling 7-Day Average With Missing Days

> **難度**：★★★★☆
> **核心技巧**：`RANGE BETWEEN INTERVAL` vs `ROWS BETWEEN`、缺漏日期、分母的定義
> **對應基礎題**：[LC 1321. Restaurant Growth](../../../sql_training/restaurant_growth)（你當初的 7 日移動平均）

<br>

---

<br>

## Interview Context

> *面試官：*「營運要一張『7 日移動平均營收』的趨勢圖。
>
> 你在基礎訓練寫過這種題，我知道。所以這次我加一個條件：**有些日子完全沒有交易**（假日、系統維護）。
>
> 給我一個數字，然後告訴我為什麼是這個數字 —— 因為我等一下會給你另外兩個也『對』的答案。」

<br>

這一題沒有唯一解。**它的目的是讓你發現「7 日移動平均」這句話有三種合理解讀，而它們的差距大到會改變決策。**

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS daily_revenue;

CREATE TABLE daily_revenue (
    day     DATE PRIMARY KEY,
    revenue NUMERIC(10,2) NOT NULL
);

INSERT INTO daily_revenue (day, revenue) VALUES
('2026-03-01',  100.00),
('2026-03-02',  200.00),
('2026-03-03',  300.00),
--  3/04、3/05 沒有資料
('2026-03-06',  600.00),
('2026-03-07',  700.00),
--  3/08、3/09、3/10 沒有資料
('2026-03-11', 1100.00),
('2026-03-12', 1200.00);
```

<br>

**只有 7 行，涵蓋 12 天。缺了 5 天。**

<br>

---

<br>

## Part A — 三個都「對」的答案

以 **2026-03-11** 這一天為例，「過去 7 天的移動平均營收」有三種算法：

### A1 — `ROWS BETWEEN 6 PRECEDING`

```sql
AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
```

跑出來 3/11 是 **500.00**。

回答：
- 這個 frame 涵蓋了哪幾行？把它們列出來。
- 這 7 行橫跨了幾個**日曆天**？
- **所以這個數字回答的是什麼問題？**「過去 7 天」還是「過去 7 筆」？

### A2 — `RANGE BETWEEN INTERVAL '6 days' PRECEDING`

```sql
AVG(revenue) OVER (ORDER BY day RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW)
```

跑出來 3/11 是 **800.00**。

回答：
- 這個 frame 涵蓋了哪幾行？
- 分母是多少？
- **所以這個數字回答的是什麼問題？**

### A3 — 骨架補零

先用 `generate_series` 造出完整 12 天的日期骨架，缺漏日補 `0`，再套 `ROWS BETWEEN 6 PRECEDING`。

跑出來 3/11 是 **342.86**。

回答：
- 分母是多少？
- **所以這個數字回答的是什麼問題？**

### A4 — 對照

把三個答案並排：

| 算法 | 3/11 的值 | 分母 | 它回答的問題 |
|------|----------|------|-------------|
| `ROWS 6 PRECEDING` | 500.00 | ? | ? |
| `RANGE 6 days` | 800.00 | ? | ? |
| 骨架補零 | 342.86 | ? | ? |

**500 和 342.86 差了 46%。** 如果這是「營收是否成長」的判斷依據，三個算法會給出不同的商業結論。

寫出：**你會選哪一個？在什麼情境下你會改選另一個？**

<br>

---

<br>

## Part B — 為什麼 `ROWS` 是最危險的

### B1

`ROWS BETWEEN 6 PRECEDING` 是最多人寫的版本（包括你基礎訓練的答案）。

- 當資料**每天都有**時，它是對的嗎？
- 當資料**有缺漏**時，它的 frame 會怎麼漂移？
- **最危險的地方**：它不會報錯，也不會回傳 NULL，它只是安靜地算了一個「過去 11 個日曆天」的平均，然後標題寫「7 日移動平均」。

### B2 — 漂移的證據

寫一個查詢，對每一行輸出：

- `ROWS BETWEEN 6 PRECEDING` 的 frame 實際橫跨了幾個日曆天
- frame 內有幾行

驗證 3/11 那一行橫跨了 **11 天**而不是 7 天。

（提示：`MIN(day) OVER (...)` 配同樣的 frame）

### B3 — 前幾行的問題

看 3/01 那一行：`ROWS BETWEEN 6 PRECEDING` 只找得到 1 行，所以平均 = 100.00。

- 這是「7 日移動平均」嗎？
- 報表的**前 6 天**是不是都不該顯示？
- 怎麼在 SQL 裡處理？（提示：`COUNT(*) OVER (...)` 配同樣 frame，不足 7 就給 NULL）

<br>

---

<br>

## Part C — 完整解法

### C1

寫出一個查詢，同時輸出三種算法的結果，讓營運可以對照：

```
    day     | revenue | rows_avg | range_avg | spine_avg
------------+---------+----------+-----------+-----------
 2026-03-11 | 1100.00 |   500.00 |    800.00 |    342.86
 2026-03-12 | 1200.00 |   600.00 |    900.00 |    514.29
```

### C2 — 加上「資料完整度」

在報表上加一欄 `days_with_data`：這 7 天裡實際有幾天有交易。

**這一欄的價值**：看到 `342.86 (3/7 days)` 的人，會知道這個平均是被 4 個零拉低的。看到 `800.00 (3 days)` 的人，會知道分母只有 3。

> **報表上的數字要能自我說明。** 一個沒有 context 的平均值，比沒有數字更危險。

### C3 — 這是 Phase 2-05 的回聲

回想 [Phase 2-05](../../phase-2-aggregation-limits/05-the-weighted-average-trap)：`AVG(AVG())` 的問題是**分母定義錯了**。

這一題的問題是什麼？用一句話把兩題連起來。

<br>

---

<br>

## Part D — 一個免費的 bug

### D1

跑這個查詢，你覺得 3/11 會是多少？

```sql
WITH spine AS (
    SELECT generate_series('2026-03-01'::date, '2026-03-12'::date, '1 day')::date AS day
),
filled AS (
    SELECT s.day, COALESCE(r.revenue, 0) AS revenue
    FROM spine s LEFT JOIN daily_revenue r USING (day)
)
SELECT day, revenue,
       ROUND(AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS avg7
FROM filled
WHERE day IN ('2026-03-11', '2026-03-12');       -- ← 只想看最後兩天
```

**先預測，再執行。**

它回傳 `1100.00` 和 `1150.00`，不是 `342.86` 和 `514.29`。

### D2

為什麼？

- SQL 的邏輯執行順序裡，`WHERE` 和 window function 誰先？
- 所以 `AVG(...) OVER (...)` 是在幾行上計算的？
- 怎麼修？

> **這是 window function 最常見的實務 bug**，比 `LAST_VALUE` 還常見。
> 你想「只看最後幾天」，結果把 window 的輸入也砍掉了。
>
> 這也回答了 [3-01](../01-the-last-value-that-lied) 面試官追問 4 的那個問題：為什麼不能寫 `WHERE ROW_NUMBER() OVER (...) = 1`。

<br>

---

<br>

## 面試官的追問

> 1. 「`RANGE BETWEEN INTERVAL '6 days' PRECEDING` 是哪個 PostgreSQL 版本開始支援的？MySQL 8 支援嗎？」
>
> 2. 「如果 `day` 欄位是 `TIMESTAMP` 而不是 `DATE`，`RANGE BETWEEN INTERVAL '6 days'` 的行為會有什麼不同？」
>
> 3. 「7 日移動平均要每天算一次，資料表有 10 年的歷史。每次都全表掃描嗎？」
>
> 4. 「如果要算的是 7 日移動**中位數**而不是平均，window function 做得到嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 三個 frame 的內容</summary>

資料行（依日期）：`03-01, 03-02, 03-03, 03-06, 03-07, 03-11, 03-12`

**3/11 是第 6 行。**

`ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`
→ 往回數 6 **行**，但前面只有 5 行，所以 frame = 全部 6 行
→ `100, 200, 300, 600, 700, 1100` = 3000 / **6** = **500.00**
→ 橫跨 03-01 ~ 03-11 = **11 個日曆天**

`RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW`
→ 日期落在 `[03-05, 03-11]` 的行
→ `600, 700, 1100` = 2400 / **3** = **800.00**
→ 橫跨正好 7 個日曆天，但只有 3 天有資料

**骨架補零**
→ `[03-05, 03-11]` 的 7 天，缺漏補 0
→ `0, 600, 700, 0, 0, 0, 1100` = 2400 / **7** = **342.86**

**分子都是 2400（後兩者），差別只在分母：3 還是 7。**

</details>

<details>
<summary>Hint 2 — 該選哪一個</summary>

| 情境 | 選擇 | 理由 |
|------|------|------|
| 「平均每天賺多少」 | **骨架補零（342.86）** | 沒交易的日子營收就是 0，必須進分母 |
| 「有交易的日子平均賺多少」 | `RANGE`（800.00） | 分母只算有營業的日子 |
| 「最近 7 筆交易日的平均」 | `ROWS`（500.00） | 分析交易日趨勢，不管日曆 |

**`ROWS` 幾乎永遠不是你要的** —— 除非你能保證資料每天都有，或者你真的想要「最近 N 筆」而不是「最近 N 天」。

面試時的標準答案：**「這取決於缺漏的那幾天是『沒營業』還是『沒資料』。前者該補 0，後者該排除 —— 這兩件事在資料庫裡長得一模一樣，我需要問清楚。」**

</details>

<details>
<summary>Hint 3 — 加上資料完整度</summary>

```sql
SELECT day, revenue,
  ROUND(AVG(revenue) OVER w, 2) AS range_avg,
  COUNT(*)           OVER w     AS days_with_data,
  MIN(day)           OVER w     AS window_from
FROM daily_revenue
WINDOW w AS (ORDER BY day RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW)
ORDER BY day;
```

用 `WINDOW` 子句把重複的 frame 定義抽出來 —— 三個聚合共用同一個 `w`，改一次就好。

**這是 [3-01](../01-the-last-value-that-lied) 面試官追問 1 的答案**：當你要在同一個查詢裡重複用相同的 window 定義，用 `WINDOW` 子句。

</details>

<details>
<summary>Hint 4 — D1 為什麼是 1100 和 1150</summary>

SQL 的邏輯執行順序：

```
FROM → WHERE → GROUP BY → HAVING → WINDOW → SELECT → ORDER BY → LIMIT
                  ↑                    ↑
              先在這裡砍掉          window 才在這裡算
```

`WHERE day IN ('2026-03-11','2026-03-12')` **先**把 12 行砍成 2 行，`AVG(...) OVER (...)` **才**在這 2 行上計算：

- 3/11：frame 只有自己 → 1100 / 1 = **1100.00**
- 3/12：frame 是這 2 行 → (1100+1200) / 2 = **1150.00**

修法：把 window 計算包進子查詢或 CTE，`WHERE` 放外層。

```sql
WITH w AS (SELECT day, revenue, AVG(...) OVER (...) AS avg7 FROM filled)
SELECT * FROM w WHERE day IN ('2026-03-11','2026-03-12');
```

**心法：window function 需要完整的資料集才能算對。任何過濾都要在它之後做。**

</details>
