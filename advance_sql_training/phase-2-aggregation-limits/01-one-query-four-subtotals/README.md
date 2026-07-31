# Phase 2-01 — One Query, Four Subtotals

> **難度**：★★★★☆
> **核心技巧**：`GROUPING SETS` / `ROLLUP` / `CUBE`、`GROUPING()` 辨識小計行
> **對應基礎題**：[LC 1179. Reformat Department Table](../../../sql_training/reformat_department_table)（你當初的報表格式化練習）

<br>

---

<br>

## Interview Context

> *面試官：*「CEO 每週看的營收報表要：**每個區域每個產品的明細**、**每個區域的小計**、以及**總計**，全部在同一張表裡。
>
> 現在的工程師寫了三個查詢再 `UNION ALL` 起來，這張表掃了三次。資料量長大之後這個報表要跑 40 秒。
>
> 用**一次掃描**做完。
>
> 喔還有 — 我們有些線上訂單抓不到區域，`region` 欄位是 NULL。這個你要處理一下。」

<br>

最後那句是這題的核心。**當資料本身就有 NULL，小計行的 NULL 要怎麼分辨？**

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    id      INT PRIMARY KEY,
    region  VARCHAR(20),              -- ← 可為 NULL：抓不到區域的線上訂單
    product VARCHAR(20) NOT NULL,
    amount  NUMERIC(10,2) NOT NULL
);

INSERT INTO sales (id, region, product, amount) VALUES
(1, 'APAC', 'A', 100.00),
(2, 'APAC', 'B', 200.00),
(3, 'EMEA', 'A', 150.00),
(4, 'EMEA', 'B',  50.00),
(5, NULL,   'A', 300.00),   -- ← 未知區域（資料本身的 NULL）
(6, NULL,   'B', 100.00);   -- ← 未知區域
```

<br>

---

<br>

## Part A — 一次掃描產生小計

### A1 — 先寫出「笨方法」

用三個 `SELECT` + `UNION ALL` 寫出目標報表（明細 / 區域小計 / 總計）。

跑 `EXPLAIN ANALYZE`，回答：**這張表被掃描了幾次？**

（這一步不要跳過。你要先感受到痛，才知道 `ROLLUP` 省下了什麼。）

### A2 — 改用 `ROLLUP`

用 `GROUP BY ROLLUP(region, product)` 重寫。

跑 `EXPLAIN ANALYZE`，對比 A1：掃描次數、執行時間、計畫節點（找找看 `GroupAggregate` / `MixedAggregate`）。

<br>

### 你會得到這 10 行：

```
 region | product | revenue
--------+---------+---------
 APAC   | A       |  100.00
 APAC   | B       |  200.00
 APAC   | (NULL)  |  300.00
 EMEA   | A       |  150.00
 EMEA   | B       |   50.00
 EMEA   | (NULL)  |  200.00
 (NULL) | A       |  300.00
 (NULL) | B       |  100.00
 (NULL) | (NULL)  |  400.00     ← ？
 (NULL) | (NULL)  |  900.00     ← ？
```

<br>

---

<br>

## Part B — 兩個一模一樣的 NULL

### B1 — 找出問題

最後兩行的 `region` 和 `product` **都是 NULL，看起來完全一樣**，但一個是 400、一個是 900。

請說明這兩行**各自代表什麼**。

### B2 — 為什麼會這樣

推導出來：`ROLLUP(region, product)` 展開成哪幾個 grouping set？（提示：3 個）

然後說明每一行是從哪個 grouping set 產生的，為什麼會撞在一起。

### B3 — 用 `GROUPING()` 分辨

`GROUPING(col)` 回傳 0 或 1。查文件確認它的定義，然後回答：

- 對 `400.00` 那一行，`GROUPING(region)` 和 `GROUPING(product)` 各是多少？
- 對 `900.00` 那一行呢？
- **為什麼 `GROUPING(region)` 可以分辨「資料的 NULL」和「小計的 NULL」，但 `region IS NULL` 不行？**

### B4 — 產出可讀的報表

改寫你的查詢，加上一個 `row_type` 欄位，值為 `detail` / `region subtotal` / `GRAND TOTAL`，並且把「未知區域」顯示成 `(unknown)` 而不是空白。

預期輸出：

```
 region    | product | revenue |    row_type
-----------+---------+---------+-----------------
 APAC      | A       |  100.00 | detail
 APAC      | B       |  200.00 | detail
 EMEA      | A       |  150.00 | detail
 EMEA      | B       |   50.00 | detail
 (unknown) | A       |  300.00 | detail
 (unknown) | B       |  100.00 | detail
 APAC      | (all)   |  300.00 | region subtotal
 EMEA      | (all)   |  200.00 | region subtotal
 (unknown) | (all)   |  400.00 | region subtotal
 (all)     | (all)   |  900.00 | GRAND TOTAL
```

> **注意排序**：`ORDER BY region` 會把小計行和明細行混在一起。想想怎麼讓小計永遠排在該組的最後、總計排在最下面。

### B5 — `GROUPING()` 的多欄位形式

`GROUPING(region, product)` 傳入兩個欄位時回傳一個**位元遮罩**（bit mask）整數。

- 四種組合（00、01、10、11）各對應什麼十進位值？
- 本題的 10 行各自的 `GROUPING(region, product)` 是多少？
- 用它寫一個比 B4 更簡潔的 `CASE`。

<br>

---

<br>

## Part C — ROLLUP vs CUBE vs GROUPING SETS

### C1

把 `ROLLUP(region, product)` 改成 `CUBE(region, product)`。

- 行數從 **10** 變成 **12**。多出來的 2 行是什麼？
- 用 grouping set 的角度說明 `ROLLUP` 和 `CUBE` 的差異。
- `ROLLUP(a, b, c)` 產生幾個 grouping set？`CUBE(a, b, c)` 呢？寫出通式。

### C2

用 `GROUPING SETS` 手動寫出和 `ROLLUP(region, product)` **完全等價**的查詢。

### C3

現在需求變成：「要明細、要**產品**小計、要總計，**但不要區域小計**」。

`ROLLUP` 做得到嗎？`CUBE` 呢？用 `GROUPING SETS` 寫出來。

**這就是 `GROUPING SETS` 存在的理由** —— 講清楚它。

<br>

---

<br>

## 面試官的追問

> 1. 「`ROLLUP` 為什麼只要掃一次表就能算出所有層級？它內部怎麼做的？」
>    （提示：`EXPLAIN` 裡的 `MixedAggregate` / `GroupAggregate` 節點）
>
> 2. 「如果我要在 `ROLLUP` 的結果上再加一欄『該區域佔總營收的百分比』，怎麼寫？」
>
> 3. 「`HAVING` 可以用在 `ROLLUP` 上嗎？如果我只想看小計行，`HAVING` 要怎麼寫？」
>
> 4. 「MySQL 有 `ROLLUP` 嗎？語法一樣嗎？有 `CUBE` 嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — ROLLUP 展開成什麼</summary>

`GROUP BY ROLLUP(region, product)` 等價於：

```sql
GROUP BY GROUPING SETS (
    (region, product),   -- 明細
    (region),            -- 區域小計
    ()                   -- 總計
)
```

`ROLLUP` 是**階層式**的：從最細一路彙總到最粗，n 個欄位產生 **n+1** 個 grouping set。

`CUBE(region, product)` 則是**所有組合**：

```sql
GROUP BY GROUPING SETS (
    (region, product),
    (region),
    (product),           -- ← ROLLUP 沒有這個
    ()
)
```

n 個欄位產生 **2ⁿ** 個 grouping set。

</details>

<details>
<summary>Hint 2 — 兩個 (NULL, NULL) 從哪來</summary>

- `400.00` 來自 grouping set **`(region)`**：`region` 是真的 NULL（未知區域），`product` 被彙總掉所以顯示 NULL。
  → 它是「**未知區域這一組的小計**」。
- `900.00` 來自 grouping set **`()`**：兩欄都被彙總掉。
  → 它是「**總計**」。

`region IS NULL` 對這兩行都是 TRUE，所以分不出來。`GROUPING(region)` 才能：
- 400 那行：`region` **在** grouping set 裡 → `GROUPING(region) = 0`
- 900 那行：`region` **不在** grouping set 裡 → `GROUPING(region) = 1`

**`GROUPING()` 問的不是「值是不是 NULL」，而是「這個欄位有沒有參與這一行的分組」。**

</details>

<details>
<summary>Hint 3 — 位元遮罩</summary>

`GROUPING(a, b)` = `GROUPING(a) * 2 + GROUPING(b)`

| GROUPING(region) | GROUPING(product) | 遮罩值 | 意義 |
|---|---|---|---|
| 0 | 0 | **0** | 明細 |
| 0 | 1 | **1** | 區域小計 |
| 1 | 0 | 2 | 產品小計（`ROLLUP` 不會產生） |
| 1 | 1 | **3** | 總計 |

所以：

```sql
CASE GROUPING(region, product)
    WHEN 0 THEN 'detail'
    WHEN 1 THEN 'region subtotal'
    WHEN 3 THEN 'GRAND TOTAL'
END
```

排序也用它：`ORDER BY GROUPING(region, product), region NULLS LAST, product NULLS LAST` —— 明細在前、小計次之、總計最後。

</details>

<details>
<summary>Hint 4 — 顯示 (unknown) 和 (all)</summary>

```sql
CASE WHEN GROUPING(region) = 1 THEN '(all)'
     WHEN region IS NULL       THEN '(unknown)'
     ELSE region END AS region
```

**分支順序很重要** —— 先判斷 `GROUPING()`，再判斷 `IS NULL`。反過來寫的話，總計行會被標成 `(unknown)`。

</details>
