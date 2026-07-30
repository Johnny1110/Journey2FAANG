# Phase 2-07 — The COUNT That Lied

> **難度**：★★★★☆
> **核心技巧**：JOIN 扇出（fan-out）放大、`COUNT(*)` vs `COUNT(col)` vs `COUNT(DISTINCT)`、預聚合
> **對應基礎題**：[LC 1068. Product Sales Analysis I](../../../sql_training/product_sales_analysis_i) + [LC 577. Employee Bonus](../../../sql_training/employee_bonus)

<br>

---

<br>

## Interview Context

> *面試官：*「客戶總覽報表：每個客戶的訂單數、評論數、總消費金額。
>
> 這個查詢上線半年了。上週業務跟財務吵起來 —— 業務系統顯示 alice 消費了 1200，財務系統顯示 600。
>
> 我查了資料，**財務是對的**。
>
> 但這個 SQL 我看不出哪裡錯，而且對其他客戶算出來都是對的。你來看看。」

<br>

**「對其他客戶都是對的」是這題最惡毒的地方。** 這種 bug 可以在正式環境活好幾年。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    amount      NUMERIC(10,2) NOT NULL
);

CREATE TABLE reviews (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    rating      INT NOT NULL
);

INSERT INTO customers (id, name) VALUES
(1, 'alice'), (2, 'bob'), (3, 'carol'), (4, 'dave');

INSERT INTO orders (id, customer_id, amount) VALUES
(101, 1, 100.00),
(102, 1, 100.00),     -- ← 和 101 金額相同，記住這個
(103, 1, 400.00),
(104, 2, 250.00);

INSERT INTO reviews (id, customer_id, rating) VALUES
(201, 1, 5),
(202, 1, 3),
(203, 3, 4);
```

<br>

### 真實情況

| 客戶 | 訂單數 | 評論數 | 總消費 |
|------|--------|--------|--------|
| alice | 3 | 2 | 600.00 |
| bob | 1 | 0 | 250.00 |
| carol | 0 | 1 | 0.00 |
| dave | 0 | 0 | 0.00 |

<br>

---

<br>

## The Broken Query

```sql
SELECT c.name,
       COUNT(o.id)   AS orders,
       COUNT(r.id)   AS reviews,
       SUM(o.amount) AS revenue
FROM customers c
LEFT JOIN orders  o ON o.customer_id = c.id
LEFT JOIN reviews r ON r.customer_id = c.id
GROUP BY c.id, c.name
ORDER BY c.id;
```

**實際輸出：**

```
 name  | orders | reviews | revenue
-------+--------+---------+---------
 alice |      6 |       6 | 1200.00     ← 全錯
 bob   |      1 |       0 |  250.00     ← 對
 carol |      0 |       1 |  (NULL)     ← 對
 dave  |      0 |       0 |  (NULL)     ← 對
```

<br>

---

<br>

## Part A — 診斷扇出

### A1 — 先看中間結果

把 `GROUP BY` 和聚合拿掉，只跑 JOIN 本身：

```sql
SELECT c.name, o.id AS order_id, o.amount, r.id AS review_id
FROM customers c
LEFT JOIN orders  o ON o.customer_id = c.id
LEFT JOIN reviews r ON r.customer_id = c.id
ORDER BY c.id, o.id, r.id;
```

alice 產生了幾行？**手動列出來。**

### A2 — 為什麼是 6

alice 有 3 筆訂單、2 則評論。

- 推導出 `3 × 2 = 6` 的過程。
- 這在關聯代數裡叫什麼？
- **寫出通式**：一個客戶有 m 筆訂單、n 則評論，JOIN 後會有幾行？當 m=0 或 n=0 時呢？

### A3 — 為什麼其他人是對的

bob（1 筆訂單、0 評論）、carol（0 訂單、1 評論）、dave（0/0）算出來都對。

**用 A2 的通式解釋為什麼。**

然後回答：**什麼條件下這個 bug 才會顯現？** 這解釋了為什麼它能在正式環境活半年。

### A4 — `COUNT(*)` vs `COUNT(col)`

把查詢改成同時輸出 `COUNT(*)` 和 `COUNT(o.id)`：

```
 name  | count_star | count_order_id
-------+------------+----------------
 alice |          6 |              6
 bob   |          1 |              1
 carol |          1 |              0      ← 差在這
 dave  |          1 |              0      ← 和這
```

- carol 和 dave 的 `COUNT(*)` 為什麼是 1？
- 為什麼 `COUNT(o.id)` 是 0？
- **`LEFT JOIN` + `COUNT(*)` 幾乎永遠是 bug。** 說明為什麼，以及什麼時候例外。

<br>

---

<br>

## Part B — 三種修法，兩種是錯的

### B1 — `DISTINCT` 修法

```sql
SELECT c.name,
       COUNT(DISTINCT o.id) AS orders,
       COUNT(DISTINCT r.id) AS reviews,
       SUM(DISTINCT o.amount) AS revenue
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
LEFT JOIN reviews r ON r.customer_id = c.id
GROUP BY c.id, c.name;
```

跑跑看。`orders` 和 `reviews` 現在是 **3** 和 **2** —— 對了。

但 `revenue` 是 **500.00**，正確答案是 **600.00**。

- 為什麼 `SUM(DISTINCT)` 是 500？
- alice 的訂單金額是 100、100、400 —— **這個資料是我故意設計的。** 為什麼？
- **寫出這句結論**：`DISTINCT` 能救 `COUNT`，但救不了 `______`，因為 `______`。

### B2 — 預聚合修法（正解）

先各自聚合，再 JOIN：

```sql
SELECT c.name,
       COALESCE(o.n, 0)     AS orders,
       COALESCE(r.n, 0)     AS reviews,
       COALESCE(o.total, 0) AS revenue
FROM customers c
LEFT JOIN (SELECT customer_id, COUNT(*) AS n, SUM(amount) AS total
           FROM orders GROUP BY customer_id) o ON o.customer_id = c.id
LEFT JOIN (SELECT customer_id, COUNT(*) AS n
           FROM reviews GROUP BY customer_id) r ON r.customer_id = c.id
ORDER BY c.id;
```

驗證它產生正確的 3 / 2 / 600.00。

回答：**為什麼這樣就不會扇出？** 關鍵字是「基數」（cardinality）。

### B3 — 相關子查詢修法

用純量子查詢再寫一版：

```sql
SELECT c.name,
       (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.id) AS orders,
       ...
```

- 這樣對嗎？
- 跑 `EXPLAIN` 對比 B2。哪一個快？為什麼？
- 客戶數 100 萬時哪一個比較好？客戶數 100 時呢？

### B4 — `LATERAL` 修法

用 [Phase 1-05](../../phase-1-join-dark-side/05-top-n-four-ways) 學的 `LEFT JOIN LATERAL` 再寫一版。

四種寫法（DISTINCT / 預聚合 / 相關子查詢 / LATERAL）做一張對照表：正確性、可讀性、效能、可擴充性（如果要再加第三張表呢？）。

<br>

---

<br>

## Part C — 稽核

### C1 — 通用檢查

寫一個**通用的扇出偵測查詢**：給定一個 JOIN，判斷它是不是一對多。

思路：`SELECT COUNT(*) FROM a JOIN b ...` 和 `SELECT COUNT(DISTINCT a.pk) FROM a JOIN b ...` 一不一樣。

### C2 — 回頭看自己的答案

打開你基礎訓練的 [LC 577. Employee Bonus](../../../sql_training/employee_bonus) 和 [LC 1068. Product Sales Analysis I](../../../sql_training/product_sales_analysis_i)。

- 那些題目有沒有多表 JOIN 之後聚合？
- 如果測資裡某個 employee 有兩筆 bonus，你的答案會不會出錯？
- **LeetCode 判你通過，是因為你寫對了，還是因為測資剛好是一對一？**

<br>

---

<br>

## 面試官的追問

> 1. 「你怎麼在**寫查詢之前**就知道會不會扇出？」
>    （提示：看 schema —— 主鍵、唯一約束、外鍵）
>
> 2. 「如果 `SUM(DISTINCT amount)` 不能用，那有沒有任何情況 `SUM(DISTINCT)` 是正確的？」
>
> 3. 「B2 的預聚合寫法，如果 `orders` 有 10 億行，這個子查詢會很慢。怎麼優化？」
>
> 4. 「這個報表要加上『最近一次下單日期』和『平均評分』。四種寫法哪些要大改？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — alice 的 6 行長什麼樣</summary>

| name | order_id | amount | review_id |
|------|----------|--------|-----------|
| alice | 101 | 100.00 | 201 |
| alice | 101 | 100.00 | 202 |
| alice | 102 | 100.00 | 201 |
| alice | 102 | 100.00 | 202 |
| alice | 103 | 400.00 | 201 |
| alice | 103 | 400.00 | 202 |

每一筆訂單被複製了 2 次（評論數），每一則評論被複製了 3 次（訂單數）。

`SUM(o.amount)` = (100+100) + (100+100) + (400+400) = **1200** = 真實值 600 × 2。

**通式**：m 筆訂單 × n 則評論 → `max(m,1) × max(n,1)` 行（`LEFT JOIN` 讓 0 變成 1）。

bug 只在 **m ≥ 2 且 n ≥ 2** 時顯現。任一邊是 0 或 1，乘積就等於另一邊 —— 結果碰巧正確。

</details>

<details>
<summary>Hint 2 — 兩張表互相扇出</summary>

`orders` 和 `reviews` 之間**沒有任何關聯**，它們只是各自連到 `customers`。

當你把兩張「一對多」的表同時 JOIN 到同一張表上，兩邊會互相做**笛卡兒積**。

這叫 **fan-out（扇出）** 或 **fan trap**。

**判斷法則**：從主表出發，如果 JOIN 路徑上有**兩條或以上**的「一對多」分支，就會扇出。一條分支不會。

</details>

<details>
<summary>Hint 3 — 為什麼 SUM(DISTINCT) = 500</summary>

alice 的訂單金額被扇出成：100, 100, 100, 100, 400, 400

`SUM(DISTINCT ...)` 先對**值**去重 → `{100, 400}` → 100 + 400 = **500**

問題是：alice 本來就有**兩筆不同的訂單**都是 100 元（訂單 101 和 102）。`DISTINCT` 分不出「扇出複製的 100」和「本來就存在的第二筆 100」—— 它只看得到值，看不到來源。

**結論**：`DISTINCT` 能救 `COUNT`（因為 `COUNT(DISTINCT o.id)` 去重的是**主鍵**，主鍵天生唯一），但救不了 `SUM` / `AVG`（因為它們去重的是**度量值**，度量值本來就會重複）。

這也是為什麼我把 alice 的訂單設成 100、100、400 —— 如果設成 100、200、300，`SUM(DISTINCT)` 會**碰巧算對**，你就學不到這一課了。

</details>

<details>
<summary>Hint 4 — 為什麼預聚合不會扇出</summary>

```sql
LEFT JOIN (SELECT customer_id, COUNT(*) AS n, SUM(amount) AS total
           FROM orders GROUP BY customer_id) o ON o.customer_id = c.id
```

子查詢 `GROUP BY customer_id` 之後，每個 `customer_id` **只剩一行** —— 它變成了對 `customers` 的**一對一**關係。

兩個一對一的 JOIN 不可能扇出。

**心法**：把「一對多」在 JOIN **之前**壓成「一對一」，就永遠不會扇出。這也是 star schema 裡 fact table 預聚合的核心原理。

</details>
