# Phase 1-01 — The NULL That Ate Your Results

> **難度**：★★★☆☆
> **核心技巧**：Anti-Join 三寫法、三值邏輯（Three-Valued Logic）
> **對應基礎題**：[LC 183. Customers Who Never Order](../../../sql_training/customers_who_never_order)

<br>

---

<br>

## Interview Context

> *面試官：*「這個查詢是我們電商後台的『從未下單客戶』報表，跑了兩年都正常。上週我們上線了**訪客結帳（guest checkout）**功能 — 沒有帳號也能買東西。從那天開始，這張報表每天都回傳 **0 筆**。
>
> 但資料庫裡明明還有從來沒買過東西的註冊用戶。工程師檢查了資料，沒有任何一筆資料遺失。
>
> 發生什麼事？」

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id   INT PRIMARY KEY,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT,                    -- ← 可為 NULL：訪客結帳沒有帳號
    amount      NUMERIC(10,2) NOT NULL,
    created_at  DATE NOT NULL
);

INSERT INTO customers (id, name) VALUES
(1, 'Alice'),
(2, 'Bob'),
(3, 'Carol'),
(4, 'Dave'),
(5, 'Eve'),
(6, 'Frank');

INSERT INTO orders (id, customer_id, amount, created_at) VALUES
(101, 1,    250.00,  '2026-01-05'),
(102, 2,     99.00,  '2026-01-07'),
(103, 2,   1200.00,  '2026-02-11'),
(104, NULL,  45.00,  '2026-02-14'),    -- ← 訪客結帳（上週上線的新功能）
(105, 3,   3000.00,  '2026-03-02'),
(106, NULL, 780.00,  '2026-03-19');    -- ← 訪客結帳
```

<br>

### 正確答案應該是

```
+-------+
| name  |
+-------+
| Dave  |
| Eve   |
| Frank |
+-------+
```

<br>

---

<br>

## The Broken Query

這是跑了兩年的原始查詢：

```sql
SELECT name
FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);
```

**實際回傳：0 筆。**

<br>

---

<br>

## Your Task

在 `answer.sql` 中完成：

### Q1 — 逐步推導，為什麼回傳 0 筆？

不要只說「因為有 NULL」。請把 `4 NOT IN (1, 2, 2, NULL, 3, NULL)` 這個運算式**展開成 `AND` 連接的比較式**，逐項寫出每一項的求值結果（TRUE / FALSE / UNKNOWN），並說明 `WHERE` 子句對 UNKNOWN 的處理規則。

### Q2 — 保留 `NOT IN` 的修法

不改變 `NOT IN` 結構的前提下修好它。（至少寫出一種）

### Q3 — 另外兩種 Anti-Join 寫法

用 `NOT EXISTS` 和 `LEFT JOIN ... IS NULL` 各寫一版，都要回傳正確的 3 筆。

### Q4 — 你會選哪一種？為什麼？

比較這三種寫法的：
- **語意安全性**（哪一種在 schema 改變時最不容易出錯）
- **可讀性**
- **執行計畫**（實際跑 `EXPLAIN` 看看 PostgreSQL 分別產生什麼 join 節點）

### Q5 — 邊界情境

回答以下三題：

1. 如果 `orders` 表是**空的**，三種寫法各回傳什麼？
2. 如果把 `customer_id` 改成 `NOT NULL`，三種寫法的**結果**會一致嗎？**執行計畫**會一致嗎？
3. `NOT IN` 的子查詢如果回傳的是**空集合**（0 筆），`x NOT IN ()` 求值是什麼？和有 NULL 的情況有什麼本質差異？

<br>

---

<br>

## 面試官的追問

> 1. 「`IN` 遇到 NULL 也會有問題嗎？還是只有 `NOT IN`？」
>
> 2. 「如果我在子查詢加上 `WHERE customer_id IS NOT NULL`，是不是就等價於 `NOT EXISTS` 了？有沒有任何情況不等價？」
>
> 3. 「你說 `NOT EXISTS` 比較安全。那為什麼還有這麼多人寫 `NOT IN`？`NOT IN` 有什麼場合是更好的？」
>
> 4. 「`LEFT JOIN ... WHERE x IS NULL` 這種寫法，如果 `orders.customer_id` 有大量重複值，會有什麼問題？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 三值邏輯的真值表</summary>

SQL 的 `AND` 運算：

| A | B | A AND B |
|---|---|---------|
| TRUE | TRUE | TRUE |
| TRUE | UNKNOWN | **UNKNOWN** |
| FALSE | UNKNOWN | **FALSE** |
| UNKNOWN | UNKNOWN | UNKNOWN |

而 `WHERE` 只放行 **TRUE**。UNKNOWN 和 FALSE 一樣被丟掉。

</details>

<details>
<summary>Hint 2 — NOT IN 到底展開成什麼</summary>

`x NOT IN (a, b, c)` 等價於：

```
NOT (x = a OR x = b OR x = c)
```

用 De Morgan 展開：

```
x <> a AND x <> b AND x <> c
```

現在把其中一個換成 NULL，想想 `x <> NULL` 求值是什麼。

</details>

<details>
<summary>Hint 3 — 為什麼 NOT EXISTS 不會有這個問題</summary>

`NOT EXISTS` 判斷的是「**子查詢有沒有回傳任何一行**」，這是一個純粹的 TRUE/FALSE 問題，不涉及值的比較。

子查詢內部的 `o.customer_id = c.id` 遇到 NULL 時求值為 UNKNOWN，該行不被 `WHERE` 放行 → 子查詢就是回傳 0 行 → `NOT EXISTS` 是 TRUE。

**NULL 在子查詢內部就被消化掉了，不會外洩到外層的邏輯判斷。**

</details>

<details>
<summary>Hint 4 — 空集合 vs 含 NULL 集合</summary>

`x NOT IN ()` — 空集合的 `AND` 是空真值（vacuous truth），結果是 **TRUE**（所有客戶都回傳）。

`x NOT IN (NULL)` — 結果是 **UNKNOWN**（沒有客戶回傳）。

這兩個是**相反**的行為，而且都不是直覺答案。這就是為什麼資深工程師避開 `NOT IN`。

</details>
