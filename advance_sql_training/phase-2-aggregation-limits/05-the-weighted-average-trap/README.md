# Phase 2-05 — The Weighted Average Trap

> **難度**：★★★☆☆
> **核心技巧**：`AVG(AVG())` 的謬誤、加權平均、聚合不可組合性
> **對應基礎題**：[LC 1321. Restaurant Growth](../../../sql_training/restaurant_growth)（你當初的移動平均練習）

<br>

---

<br>

## Interview Context

> *面試官：*「我們的 BI 儀表板有兩個數字對不起來。
>
> 『各區域平均客單價』那張圖顯示 APAC 1000、EMEA 10、NA 100。下面的『全公司平均客單價』顯示 **370**。
>
> 但財務部門自己算出來是 **33.25**。
>
> 儀表板的 SQL 是先算各區平均，再對這三個數字取平均。財務是拿總營收除以總訂單數。
>
> **誰對？為什麼差了 11 倍？**」

<br>

這是資料工程面試的經典題。答錯的人多到嚇人 —— 因為 `AVG(AVG(x))` 看起來太合理了。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS regional_orders;

CREATE TABLE regional_orders (
    id     SERIAL PRIMARY KEY,
    region VARCHAR(20) NOT NULL,
    amount NUMERIC(10,2) NOT NULL
);

-- APAC：1 筆大單
INSERT INTO regional_orders (region, amount)
SELECT 'APAC', 1000.00;

-- EMEA：99 筆小單
INSERT INTO regional_orders (region, amount)
SELECT 'EMEA', 10.00 FROM generate_series(1, 99);

-- NA：20 筆中單
INSERT INTO regional_orders (region, amount)
SELECT 'NA', 100.00 FROM generate_series(1, 20);
```

<br>

### 各區域狀況

```
 region | n  |  total  | avg_order
--------+----+---------+-----------
 APAC   |  1 | 1000.00 |   1000.00
 EMEA   | 99 |  990.00 |     10.00
 NA     | 20 | 2000.00 |    100.00
```

### 兩個「平均」

```
 avg_of_avgs |  true_avg
-------------+-----------
      370.00 |     33.25
```

<br>

---

<br>

## Part A — 診斷

### A1

寫出兩個查詢，各自產生 **370.00** 和 **33.25**。

### A2 — 誰對？

回答：
- 「全公司平均客單價」的**正確定義**是什麼？
- 370 這個數字**有沒有任何意義**？如果有，它回答的是什麼問題？
- 用一句話向 PM 解釋為什麼儀表板是錯的。

### A3 — 為什麼會差 11 倍

370 = `(1000 + 10 + 100) / 3`

推導出來：`AVG(AVG(x))` 隱含了什麼假設？這個假設在本題被違反到什麼程度？

**寫出這句結論**：`AVG(AVG(x))` 只有在 `______` 時才等於 `AVG(x)`。

### A4 — 一般化

`AVG` 是**不可組合**（non-decomposable）的聚合 —— 不能對部分結果再聚合一次。

把常見聚合分成兩類：

| 可組合（對子結果再聚合仍正確） | 不可組合 |
|------|---------|
| ? | ? |

從 `SUM` / `COUNT` / `AVG` / `MIN` / `MAX` / `COUNT(DISTINCT)` / `MEDIAN` / `STDDEV` 裡分類，**並說明每一個的理由**。

> 這一題答得好，面試官會知道你做過真正的資料工程 —— 這正是 pre-aggregation、rollup table、OLAP cube 設計的核心考量。

<br>

---

<br>

## Part B — 加權平均

### B1

如果一定要**從各區域的平均值**算出全公司平均（例如你只拿得到彙總後的資料，原始明細已經被刪掉了），你需要什麼額外資訊？

寫出加權平均的公式，並用 SQL 實作，驗證結果等於 33.25。

### B2 — 現實場景

假設有一張每日彙總表：

```sql
CREATE TABLE daily_regional_summary (
    day        DATE,
    region     VARCHAR(20),
    order_cnt  INT,
    avg_amount NUMERIC(10,2)      -- 只存了平均，沒存總額
);
```

- 從這張表能不能正確算出「本月全公司平均客單價」？
- 能不能正確算出「本月 APAC 的中位數客單價」？
- **這張彙總表的 schema 設計有什麼問題？你會怎麼改？**

### B3 — 學分加權

再看一個場景：學生成績。

```sql
DROP TABLE IF EXISTS grades;
CREATE TABLE grades (
    student  VARCHAR(20),
    course   VARCHAR(20),
    credits  INT,
    score    NUMERIC(5,2)
);

INSERT INTO grades VALUES
('alice','Calculus',    4, 60.00),
('alice','PE',          1, 100.00),
('alice','Literature',  1, 100.00),
('bob',  'Calculus',    4, 90.00),
('bob',  'PE',          1, 60.00),
('bob',  'Literature',  1, 60.00);
```

- 用 `AVG(score)` 算，alice 和 bob 誰的成績好？
- 用**學分加權**算呢？
- 兩種算法給出相反的結論。**哪一種是「對」的？這是技術問題還是政策問題？**

<br>

---

<br>

## Part C — 找出你自己寫過的 bug

### C1

回去看你基礎訓練裡所有用到 `AVG` 的答案。找出**至少一題**：如果題目改成「先分組算平均、再算總平均」，你當初的寫法會不會出錯？

如果找不到，說明為什麼那些題目**結構上**不會踩到這個坑。

### C2

寫一個**通用的檢查查詢**：給定任意分組欄位，同時輸出 `AVG(AVG())` 和真實 `AVG()`，以及兩者的差異百分比。

這個查詢可以拿來稽核你們公司現有的儀表板。

<br>

---

<br>

## 面試官的追問

> 1. 「如果各區域的訂單數**完全相同**，`AVG(AVG())` 還會錯嗎？證明給我看。」
>
> 2. 「`MEDIAN(MEDIAN(x))` 呢？也是錯的嗎？比 `AVG` 更錯還是更不錯？」
>
> 3. 「Data warehouse 常見的 pre-aggregation table，為什麼一定要存 `SUM` 和 `COUNT` 而不是存 `AVG`？」
>
> 4. 「`STDDEV` 可以從分組結果組合回去嗎？需要存什麼？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 兩個查詢</summary>

```sql
-- 370.00：對平均取平均（錯）
WITH per_region AS (
    SELECT region, AVG(amount) AS a FROM regional_orders GROUP BY region
)
SELECT ROUND(AVG(a), 2) AS avg_of_avgs FROM per_region;

-- 33.25：總和除以總筆數（對）
SELECT ROUND(AVG(amount), 2) AS true_avg,
       ROUND(SUM(amount) / COUNT(*), 2) AS same_thing
FROM regional_orders;
```

`AVG(amount)` 本身就是 `SUM/COUNT`，所以第二個查詢的兩欄必然相同。

</details>

<details>
<summary>Hint 2 — 為什麼是 11 倍</summary>

`AVG(AVG(x))` 把每一組當成**權重相等**的一票。

本題三組的實際權重是 1 : 99 : 20 —— 極度不均。APAC 只有 1 筆訂單，卻在 `avg_of_avgs` 裡佔了 1/3 的權重，硬是把整體拉到 370。

**結論**：`AVG(AVG(x))` 只有在**每一組的行數完全相同**時才等於 `AVG(x)`。

換個講法：`AVG(AVG())` 算的是「**各區域的平均表現**」（每區一票），不是「**平均每一筆訂單**」。前者是有意義的指標（比較區域），但它不能叫「全公司平均客單價」。

</details>

<details>
<summary>Hint 3 — 可組合性</summary>

| 可組合 | 為什麼 |
|--------|--------|
| `SUM` | 子總和再相加 = 總和 |
| `COUNT` | 子計數再相加 = 總計數 |
| `MIN` / `MAX` | 子極值的極值 = 總極值 |

| 不可組合 | 為什麼 |
|---------|--------|
| `AVG` | 需要 `SUM` 和 `COUNT` 兩個量；只給平均值資訊不足 |
| `COUNT(DISTINCT)` | 跨組可能有重複值，無法相加 |
| `MEDIAN` / 百分位 | 需要完整分布，中位數的中位數毫無意義 |
| `STDDEV` | 需要 `SUM(x)`、`SUM(x²)`、`COUNT` 三個量才能重組 |

**這就是為什麼 OLAP cube 和 rollup table 存的是 `SUM` + `COUNT` 而不是 `AVG`** —— 存了可組合的量，任何層級的平均都能正確推導出來；存了 `AVG` 就永久失去了重組的能力。

</details>

<details>
<summary>Hint 4 — 加權平均</summary>

```sql
WITH per_region AS (
    SELECT region, COUNT(*) AS n, AVG(amount) AS a
    FROM regional_orders GROUP BY region
)
SELECT ROUND(SUM(a * n) / SUM(n), 2) AS weighted_avg FROM per_region;
```

`SUM(a * n)` 把平均值還原成總和，`SUM(n)` 是總筆數 —— 等於繞回 `SUM/COUNT`。

**這證明了一件事：你需要的不是「平均」，而是產生平均的那兩個量。**

</details>
