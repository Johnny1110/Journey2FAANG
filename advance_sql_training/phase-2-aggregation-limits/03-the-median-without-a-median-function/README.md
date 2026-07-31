# Phase 2-03 — The Median Without a Median Function

> **難度**：★★★★☆
> **核心技巧**：Ordered-Set Aggregate、`PERCENTILE_CONT` vs `PERCENTILE_DISC`、手寫中位數
> **對應基礎題**：[LC 176. Second Highest Salary](../../../sql_training/second_highest_salary)（你當初的排序取值練習）

<br>

---

<br>

## Interview Context

> *面試官：*「HR 要一份各部門薪資報告。他們原本看的是**平均薪資**，但 Marketing 部門的平均是 35 萬，而部門裡四個人有三個領不到 20 萬 —— 因為有一個人領 90 萬。
>
> HR 說：『我要看中位數。』
>
> 兩個要求：
> 1. 用 PostgreSQL 內建函數寫一版
> 2. **不准用任何中位數相關的內建函數**，再寫一版
>
> 第二版才是我真正想看的。」

<br>

「不准用內建函數」是中位數題的標準考法 —— 因為 MySQL 沒有 `PERCENTILE_CONT`，而面試官想看你**理解中位數的定義**。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS employees;

CREATE TABLE employees (
    id         INT PRIMARY KEY,
    name       VARCHAR(50) NOT NULL,
    department VARCHAR(30) NOT NULL,
    salary     NUMERIC(10,2)          -- ← 可為 NULL：實習生還沒定薪
);

INSERT INTO employees (id, name, department, salary) VALUES
-- Engineering：5 人（奇數）
(1,'e1','Engineering',100000),(2,'e2','Engineering',200000),(3,'e3','Engineering',300000),
(4,'e4','Engineering',400000),(5,'e5','Engineering',500000),
-- Sales：4 人（偶數）
(6,'s1','Sales',100000),(7,'s2','Sales',200000),(8,'s3','Sales',300000),(9,'s4','Sales',400000),
-- HR：1 人
(10,'h1','HR',500000),
-- Support：2 人，薪資相同
(11,'p1','Support',300000),(12,'p2','Support',300000),
-- Marketing：4 人，有一個離群值
(13,'m1','Marketing',100000),(14,'m2','Marketing',200000),
(15,'m3','Marketing',200000),(16,'m4','Marketing',900000),
-- Intern：2 人，其中一人薪資是 NULL
(17,'i1','Intern',NULL),(18,'i2','Intern',50000);
```

<br>

### 正確答案

```
 department  | headcount | with_salary | median_cont | median_disc |   mean
-------------+-----------+-------------+-------------+-------------+-----------
 Engineering |         5 |           5 |      300000 |      300000 | 300000.00
 HR          |         1 |           1 |      500000 |      500000 | 500000.00
 Intern      |         2 |           1 |       50000 |       50000 |  50000.00
 Marketing   |         4 |           4 |      200000 |      200000 | 350000.00
 Sales       |         4 |           4 |      250000 |      200000 | 250000.00
 Support     |         2 |           2 |      300000 |      300000 | 300000.00
```

<br>

> 盯著 **Sales** 看：`median_cont = 250000` 但 `median_disc = 200000`。
> 再看 **Marketing**：中位數 20 萬，平均 35 萬。這就是 HR 要換指標的原因。
> 最後看 **Intern**：`headcount = 2` 但 `with_salary = 1`。中位數怎麼算？

<br>

---

<br>

## Part A — 用內建函數

### A1

用 `PERCENTILE_CONT(0.5)` 和 `PERCENTILE_DISC(0.5)` 寫出上面的報表。

注意語法：這兩個是 **ordered-set aggregate**，寫法和一般聚合函數不同 —— `WITHIN GROUP (ORDER BY ...)`。

### A2 — 兩者差在哪

Sales 部門的薪資是 `100000, 200000, 300000, 400000`（偶數筆）。

- `PERCENTILE_CONT` 回傳 250000，它是怎麼算出來的？
- `PERCENTILE_DISC` 回傳 200000，它是怎麼挑的？
- **哪一個回傳的值「一定真實存在於資料裡」？**
- 如果要算「員工薪資中位數」給 HR 談薪水用，你選哪一個？如果要算「中位數房價」呢？

### A3 — NULL 怎麼處理

Intern 部門有 2 人，其中 1 人 `salary` 是 NULL。

- `PERCENTILE_CONT` 回傳 50000 —— 它是把 NULL 當成 0，還是忽略它？
- 用 `COUNT(*)` 和 `COUNT(salary)` 驗證你的答案。
- 這個行為對嗎？如果 HR 問「Intern 的中位數薪資」，50000 是誠實的答案嗎？你會怎麼在報表上呈現？

### A4 — 其他百分位

同一個語法可以算任何百分位。加上 P25、P75，並算出**四分位距**（IQR = P75 − P25）。

用 IQR 找出 Marketing 部門的離群值（常見定義：`> P75 + 1.5 × IQR`）。

<br>

---

<br>

## Part B — 手寫中位數（重點）

**不准用 `PERCENTILE_CONT` / `PERCENTILE_DISC` / `MODE`。**

### B1 — 先定義

用文字寫出中位數的定義，**分奇偶兩種情況**。這一步不要跳，面試時你要先講定義再寫 SQL。

### B2 — 雙向排名法

核心技巧：對每一組**同時**算出「由小到大的排名」和「由大到小的排名」。

```sql
ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary)      AS asc_rn,
ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS desc_rn
```

觀察 Engineering（5 人）和 Sales（4 人）各行的 `asc_rn` / `desc_rn`，回答：

- 奇數筆時，中位數那一行的 `asc_rn` 和 `desc_rn` 有什麼關係？
- 偶數筆時，中間**兩行**的 `asc_rn` 和 `desc_rn` 有什麼關係？
- **能不能找出一個條件式，同時涵蓋奇偶兩種情況？**

### B3 — 寫出來

用 B2 的洞察寫出中位數查詢，結果必須和 A1 的 `PERCENTILE_CONT` **完全一致**。

別忘了處理 `salary IS NULL`。

### B4 — 第二種寫法

用完全不同的思路再寫一版。任選：

- `OFFSET` / `LIMIT` 配合 `COUNT`
- `NTILE(2)` 的邊界
- 自連接計數法（對每個值，數有幾個比它小、幾個比它大）

比較兩種寫法的**可讀性**與**在 100 萬行時的效能**。

### B5 — 移植性

你 B3 的寫法能直接搬到 MySQL 8 嗎？MySQL 5.7（沒有 window function）呢？

如果不能，在 MySQL 5.7 你會怎麼算中位數？

<br>

---

<br>

## 面試官的追問

> 1. 「為什麼 `PERCENTILE_CONT` 不能寫成 `PERCENTILE_CONT(salary, 0.5)`？`WITHIN GROUP` 這個語法存在的意義是什麼？」
>
> 2. 「`PERCENTILE_CONT` 可以當 window function 用嗎？`PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary) OVER (PARTITION BY department)` 合法嗎？」
>
> 3. 「中位數可以增量計算嗎？如果我有一個每秒進一萬筆的即時儀表板，你會怎麼做？」
>    （提示：t-digest / 近似演算法 —— 講得出方向就是加分）
>
> 4. 「平均數、中位數、眾數，什麼情況下該用哪一個？舉一個用錯會出事的例子。」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 兩個 PERCENTILE 的定義</summary>

- **`PERCENTILE_DISC(0.5)`（discrete，離散）**：回傳資料集中**實際存在**的某一個值 —— 第一個累積分布 ≥ 0.5 的值。偶數筆時取**偏小**的那個。
- **`PERCENTILE_CONT(0.5)`（continuous，連續）**：在相鄰兩個值之間做**線性插值**。偶數筆時回傳中間兩者的平均，這個值**可能不存在於資料裡**。

Sales = `100000, 200000, 300000, 400000`：
- `DISC` → 200000（真實存在）
- `CONT` → (200000 + 300000) / 2 = 250000（不存在於資料中）

「中位數房價」通常用 `DISC`（要是一間真實的房子）；「中位數薪資」統計上用 `CONT`。

</details>

<details>
<summary>Hint 2 — 雙向排名的魔法</summary>

Engineering（5 人）依薪資排序：

| salary | asc_rn | desc_rn |
|--------|--------|---------|
| 100000 | 1 | 5 |
| 200000 | 2 | 4 |
| **300000** | **3** | **3** | ← 中位數，兩個排名相等
| 400000 | 4 | 2 |
| 500000 | 5 | 1 |

Sales（4 人）：

| salary | asc_rn | desc_rn |
|--------|--------|---------|
| 100000 | 1 | 4 |
| **200000** | **2** | **3** | ← 中間兩行
| **300000** | **3** | **2** | ←
| 400000 | 4 | 1 |

奇數筆：`asc_rn = desc_rn`
偶數筆：`asc_rn = desc_rn ± 1`

**統一條件**：`asc_rn BETWEEN desc_rn - 1 AND desc_rn + 1`，然後對選中的行取 `AVG(salary)`。

奇數筆選中 1 行，`AVG` 就是它自己；偶數筆選中 2 行，`AVG` 就是插值 —— **一個條件式吃下兩種情況**。

</details>

<details>
<summary>Hint 3 — 骨架</summary>

```sql
WITH ranked AS (
    SELECT department, salary,
           ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary)      AS asc_rn,
           ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS desc_rn
    FROM employees
    WHERE salary IS NOT NULL          -- ← 想清楚為什麼要這一行
)
SELECT department, AVG(salary) AS median
FROM ranked
WHERE asc_rn BETWEEN desc_rn - 1 AND desc_rn + 1
GROUP BY department
ORDER BY department;
```

> **為什麼 `WHERE salary IS NOT NULL` 要放在 CTE 裡而不是外面？**
> 因為 `ROW_NUMBER()` 會把 NULL 也編號（PostgreSQL 預設 `NULLS LAST`），排名就歪了。
> 這和 [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的「條件放 `ON` 還是 `WHERE`」是同一種思維：**過濾的時機決定結果**。

</details>

<details>
<summary>Hint 4 — 為什麼要 ORDER BY 兩次</summary>

有人會想：只算 `asc_rn`，然後用 `COUNT(*) OVER (PARTITION BY department)` 拿到組大小，再判斷中間位置。

那也可以：

```sql
WHERE asc_rn IN ((cnt + 1) / 2, (cnt + 2) / 2)      -- 整數除法
```

奇數 `cnt=5` → `(6)/2=3, (7)/2=3` → 只選第 3 行
偶數 `cnt=4` → `(5)/2=2, (6)/2=3` → 選第 2、3 行

**整數除法在這裡做了和雙向排名一樣的事。** 兩種寫法都對，B4 可以拿這個當第二解。

</details>
