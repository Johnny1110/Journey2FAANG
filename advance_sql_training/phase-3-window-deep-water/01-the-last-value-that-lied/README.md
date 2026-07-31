# Phase 3-01 — The LAST_VALUE That Lied

> **難度**：★★★★☆
> **核心技巧**：預設 frame（`RANGE UNBOUNDED PRECEDING AND CURRENT ROW`）、`FIRST_VALUE` / `LAST_VALUE`
> **對應基礎題**：[LC 534. Game Play Analysis III](../../../sql_training/game_play_analysis_iii)（你當初的 `SUM() OVER` 累計）

<br>

---

<br>

## Interview Context

> *面試官：*「客戶價值分析要每個客戶的**第一筆**和**最後一筆**訂單金額。
>
> 工程師用了 `FIRST_VALUE` 和 `LAST_VALUE`，看起來很對稱。但 `FIRST_VALUE` 是對的，`LAST_VALUE` 回傳的**永遠是當前這一行的金額**。
>
> 他以為是 PostgreSQL 的 bug。
>
> 不是 bug。告訴我為什麼。」

<br>

這一題是 window function 的**分水嶺**。答不出來的人，代表他只會背 `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` 這個咒語，不知道 `OVER()` 裡面到底發生什麼事。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    created_at  DATE NOT NULL
);

INSERT INTO orders (id, customer_id, amount, created_at) VALUES
(1, 1, 100.00, '2026-01-05'),
(2, 1, 250.00, '2026-02-10'),
(3, 1,  80.00, '2026-03-15'),
(4, 1, 600.00, '2026-04-20'),
(5, 2, 900.00, '2026-01-08'),
(6, 2, 150.00, '2026-02-14'),
(7, 3, 320.00, '2026-03-01');
```

<br>

---

<br>

## The Broken Query

```sql
SELECT customer_id, created_at, amount,
       FIRST_VALUE(amount) OVER (PARTITION BY customer_id ORDER BY created_at) AS first_val,
       LAST_VALUE(amount)  OVER (PARTITION BY customer_id ORDER BY created_at) AS last_val
FROM orders
ORDER BY customer_id, created_at;
```

**實際輸出：**

```
 customer_id | created_at | amount | first_val | last_val
-------------+------------+--------+-----------+----------
           1 | 2026-01-05 | 100.00 |    100.00 |   100.00
           1 | 2026-02-10 | 250.00 |    100.00 |   250.00     ← 應該是 600.00
           1 | 2026-03-15 |  80.00 |    100.00 |    80.00     ← 應該是 600.00
           1 | 2026-04-20 | 600.00 |    100.00 |   600.00
           2 | 2026-01-08 | 900.00 |    900.00 |   900.00     ← 應該是 150.00
           2 | 2026-02-14 | 150.00 |    900.00 |   150.00
```

`last_val` 每一行都等於 `amount`。

<br>

---

<br>

## Part A — 預設 frame

### A1 — 先講定義

查 PostgreSQL 文件，回答：

- 當 `OVER()` 裡**有** `ORDER BY` 但**沒有**寫 frame 子句時，預設的 frame 是什麼？把完整語法寫出來。
- 當 `OVER()` 裡**沒有** `ORDER BY` 時，預設 frame 又是什麼？
- **這兩個預設值不一樣。** 這是整個 window function 最容易踩的坑。

### A2 — 推導

用 A1 的答案解釋：

- 為什麼 `FIRST_VALUE` 是對的？（frame 的第一行永遠是誰？）
- 為什麼 `LAST_VALUE` 「說謊」？（frame 的最後一行是誰？）
- **一句話總結**：`LAST_VALUE` 沒有說謊，它誠實地回傳了 `______` 的最後一行。

### A3 — 三種修法

寫出三種都能得到正確 `last_val` 的方法：

| # | 方法 |
|---|------|
| 1 | 明確指定 frame 到 `UNBOUNDED FOLLOWING` |
| 2 | 反轉排序方向，改用 `FIRST_VALUE` |
| 3 | 完全不用 `LAST_VALUE`（想想別的聚合或 `NTH_VALUE`） |

三種都跑一次，確認 customer 1 得到 600.00、customer 2 得到 150.00。

### A4 — 為什麼是 `RANGE` 不是 `ROWS`

預設 frame 用的是 `RANGE`。

- 本題的 `created_at` 沒有重複值，所以 `RANGE` 和 `ROWS` 結果相同。**證明這件事**（把預設 frame 改寫成顯式的 `ROWS` 版本，確認結果一樣）。
- 如果 customer 1 有**兩筆訂單在同一天**，`RANGE` 和 `ROWS` 的結果會不會不同？先預測，再自己插一筆測資驗證。
- 這是下一題（[3-02](../02-rows-vs-range-vs-groups)）的主題，先建立直覺。

<br>

---

<br>

## Part B — 同一個坑，你早就踩過了

### B1 — `SUM OVER` 的真相

跑這個：

```sql
SELECT customer_id, created_at, amount,
       SUM(amount) OVER (PARTITION BY customer_id)                     AS sum_a,
       SUM(amount) OVER (PARTITION BY customer_id ORDER BY created_at) AS sum_b
FROM orders ORDER BY customer_id, created_at;
```

結果：

```
 customer_id | created_at | amount |  sum_a  |  sum_b
-------------+------------+--------+---------+---------
           1 | 2026-01-05 | 100.00 | 1030.00 |  100.00
           1 | 2026-02-10 | 250.00 | 1030.00 |  350.00
           1 | 2026-03-15 |  80.00 | 1030.00 |  430.00
           1 | 2026-04-20 | 600.00 | 1030.00 | 1030.00
```

回答：

- 兩個查詢只差一個 `ORDER BY`，為什麼一個是**總和**、一個是**累計和**？
- **你在基礎訓練寫「running total」時，是不是以為是 `ORDER BY` 讓它變成累計的？** 真正的原因是什麼？
- 如果我要「累計和」但**不想**排序，做得到嗎？如果我要「總和」但**需要** `ORDER BY`（例如同時還要算 `ROW_NUMBER`），怎麼寫？

> **這一題的價值在這裡**：你之前寫的每一個 `SUM() OVER (ORDER BY ...)` 都能跑對，但你可能一直不知道為什麼。
> 現在你知道了 —— 是**預設 frame** 在做事，`ORDER BY` 只是觸發了它。

### B2 — 哪些函數受 frame 影響

把 window function 分成兩類：

| 受 frame 影響 | 不受 frame 影響 |
|--------------|----------------|
| ? | ? |

從 `ROW_NUMBER` / `RANK` / `DENSE_RANK` / `LAG` / `LEAD` / `SUM` / `AVG` / `COUNT` / `MAX` / `MIN` / `FIRST_VALUE` / `LAST_VALUE` / `NTH_VALUE` / `NTILE` 裡分類。

**並說明理由** —— 為什麼有些函數寫了 frame 也沒用？

### B3 — 一個實際會出事的例子

寫一個查詢：每個客戶的「**目前為止的最高單筆金額**」（running max）和「**整個歷史的最高單筆金額**」。

兩者都用 `MAX() OVER (...)`，但 frame 不同。驗證 customer 1 的兩欄分別是：

```
 running_max | overall_max
-------------+-------------
      100.00 |      600.00
      250.00 |      600.00
      250.00 |      600.00
      600.00 |      600.00
```

<br>

---

<br>

## 面試官的追問

> 1. 「`WINDOW` 子句（`WINDOW w AS (...)`）是什麼？什麼時候該用？」
>
> 2. 「`RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` 和不寫 `ORDER BY` 的預設 frame，結果一樣嗎？計畫一樣嗎？」
>
> 3. 「`EXCLUDE CURRENT ROW` 是什麼？舉一個需要它的場景。」
>
> 4. 「window function 是在 `WHERE` 之前還是之後執行？所以為什麼不能寫 `WHERE ROW_NUMBER() OVER (...) = 1`？要怎麼繞？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 兩個預設值</summary>

**有 `ORDER BY` 時**，預設 frame 是：

```sql
RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

→ 從分區開頭累積到**當前行**。這就是「累計和」的來源。

**沒有 `ORDER BY` 時**，預設 frame 是：

```sql
RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
```

→ 整個分區。這就是「總和」的來源。

**加一個 `ORDER BY` 會把整個分區的視野縮成「到目前為止」。** 這是 SQL 標準規定的，不是 PostgreSQL 的怪癖。

</details>

<details>
<summary>Hint 2 — LAST_VALUE 為什麼「說謊」</summary>

它沒說謊。frame 是 `[分區開頭, 當前行]`，所以：

- frame 的**第一行** = 分區的第一行 → `FIRST_VALUE` 永遠正確 ✓
- frame 的**最後一行** = **當前行** → `LAST_VALUE` 永遠回傳當前行的值

`FIRST_VALUE` 看起來「對」只是**巧合** —— 因為預設 frame 的起點剛好就是分區起點。

**兩個函數的對稱性是假的，因為預設 frame 本身就不對稱。**

</details>

<details>
<summary>Hint 3 — 三種修法</summary>

```sql
-- 方法 1：明確指定完整 frame
LAST_VALUE(amount) OVER (PARTITION BY customer_id ORDER BY created_at
                         ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)

-- 方法 2：反轉排序，改用 FIRST_VALUE（最常見、最好讀）
FIRST_VALUE(amount) OVER (PARTITION BY customer_id ORDER BY created_at DESC)

-- 方法 3：不用 LAST_VALUE，改用聚合 + 完整 frame
--（注意這不等價：MAX 拿的是最大值，不是最後一筆。只有在「最後一筆恰好最大」時才一樣）
```

**方法 2 是實務上最常用的** —— 少打一堆字，而且意圖清楚。

面試時建議寫方法 1 並口頭說「實務上我會寫方法 2」，等於一次展示兩件事。

</details>

<details>
<summary>Hint 4 — 哪些函數不受 frame 影響</summary>

**不受 frame 影響**：`ROW_NUMBER`、`RANK`、`DENSE_RANK`、`PERCENT_RANK`、`CUME_DIST`、`NTILE`、`LAG`、`LEAD`

這些叫**排名函數**（ranking）和**位移函數**（offset）。它們看的是整個**分區**和 `ORDER BY`，frame 對它們無效 —— 寫了也會被忽略（`LAG`/`LEAD` 甚至不允許寫 frame）。

**受 frame 影響**：所有**聚合函數**當 window function 用時（`SUM`、`AVG`、`COUNT`、`MAX`、`MIN`、`STRING_AGG`…），加上 `FIRST_VALUE`、`LAST_VALUE`、`NTH_VALUE`。

**記憶法**：**會「累積多行算出一個值」的函數才吃 frame**；只是「幫每一行編號或取鄰居」的不吃。

</details>
