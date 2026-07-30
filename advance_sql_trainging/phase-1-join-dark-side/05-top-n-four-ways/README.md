# Phase 1-05 — Top-3 Orders per Customer, Four Ways

> **難度**：★★★★☆
> **核心技巧**：LATERAL JOIN、`DISTINCT ON`、Window Function、Correlated Subquery — 同一題四種解法的效能對決
> **對應基礎題**：[LC 185. Department Top Three Salaries](../../../sql_training/department_top_three_salaries)（你當初用 `DENSE_RANK`）

<br>

---

<br>

## Interview Context

> *面試官：*「客服後台需要一個功能：點開任何一位客戶，顯示他**最近 3 筆訂單**。
>
> 我知道你會寫 `ROW_NUMBER()`。但這是我們流量最高的 API，一秒 2000 次請求。
>
> 我要你寫出**四種**解法，然後告訴我**在什麼條件下該選哪一種**。這一題我不看你會不會寫，我看你懂不懂為什麼。」

<br>

這是 Phase 1 唯一一題「四個答案都對」的題目。**分數全部落在你的取捨分析。**

<br>

---

<br>

## Table Schema & Testing Data

> ⚠️ 這一題資料量比較大（20 萬筆），建立需要幾秒鐘。**資料量小的話 EXPLAIN 看不出差異，這題就白做了。**

```sql
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE orders (
    id          SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    amount      NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL
);

-- 200 位客戶
INSERT INTO customers (name)
SELECT 'customer_' || g FROM generate_series(1, 200) g;

-- 20 萬筆訂單，平均每位客戶 1000 筆
INSERT INTO orders (customer_id, amount, created_at)
SELECT (random() * 199 + 1)::INT,
       (random() * 1000)::NUMERIC(10,2),
       NOW() - (random() * INTERVAL '365 days')
FROM generate_series(1, 200000);

CREATE INDEX idx_orders_customer_created
    ON orders (customer_id, created_at DESC);

ANALYZE customers;
ANALYZE orders;
```

<br>

### 輸出格式

```
+-------------+--------------+----------+---------------------+------+
| customer_id | name         | order_id | created_at          | rn   |
+-------------+--------------+----------+---------------------+------+
| 1           | customer_1   | 187423   | 2026-07-28 11:04:21 | 1    |
| 1           | customer_1   | 92341    | 2026-07-26 08:15:02 | 2    |
| 1           | customer_1   | 143092   | 2026-07-25 19:33:47 | 3    |
| 2           | customer_2   | ...      | ...                 | 1    |
...
```

<br>

---

<br>

## Your Task

四種解法都寫出來，**每一種都跑 `EXPLAIN (ANALYZE, BUFFERS)`，把輸出貼進 `answer.sql` 的註解裡**。

### 解法 A — Window Function

```sql
-- ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at DESC)
```

你在基礎訓練寫過的那一種。

### 解法 B — LATERAL JOIN

```sql
-- FROM customers c
-- CROSS JOIN LATERAL (SELECT ... FROM orders o WHERE o.customer_id = c.id ORDER BY ... LIMIT 3) x
```

`LATERAL` 讓子查詢可以引用左邊表的欄位。

### 解法 C — Correlated Subquery

用 `WHERE o.id IN (SELECT ... LIMIT 3)` 形式的相關子查詢。

### 解法 D — `DISTINCT ON`（PostgreSQL 專屬）

`DISTINCT ON` 原生只能取**每組第 1 筆**。想辦法讓它取到 3 筆 —— 如果你認為做不到或很醜，就明確說明**為什麼**，以及 `DISTINCT ON` 真正適合的場景是什麼。

<br>

---

<br>

## 分析題（這裡才是分數所在）

### Q1 — 讀計畫

貼出四種解法的 `EXPLAIN (ANALYZE, BUFFERS)`，然後回答：

- 解法 A 的 Scan 節點是什麼？它掃了幾行？
- 解法 B 的 Scan 節點是什麼？它掃了幾行？
- `Buffers: shared hit/read` 的數字差多少？
- **為什麼 A 的索引沒有幫上忙（或只幫了一部分）？**

> **參考數據**（PostgreSQL 18，本題資料集實測）：
> A 的 Index Scan `actual rows=200000`、`Buffers: shared hit=199810 read=769`
> B 的 Index Scan `actual rows=3 loops=200`、`Buffers: shared hit=1200 read=3`
> **緩衝區讀取相差約 167 倍。** 你的數字應該落在同一個量級 — 如果差很多，先檢查索引有沒有建、`ANALYZE` 有沒有跑。

### Q1b — PG 15+ 的 Run Condition

在 A 的計畫裡你會看到這一行：

```
Run Condition: (row_number() OVER w1 <= 3)
```

這是 PostgreSQL 15 加入的優化。查文件或實測回答：

- 它做了什麼？為什麼 WindowAgg 節點的 `actual rows` 是 600 而不是 200000？
- **但下面的 Index Scan 還是 `actual rows=200000`。** 所以這個優化省下了什麼、沒省下什麼？
- 這個優化存在的前提是什麼？（提示：`ROW_NUMBER()` 在 partition 內單調遞增，所以一旦超過 3 就可以跳過該 partition 剩下的行 —— 那如果換成 `RANK()` 呢？`SUM()` 呢？）

> 這一題會讓面試官眼睛一亮：**你不只知道 window function 慢，你知道新版 PG 把它優化到什麼程度、以及為什麼還是贏不了 LATERAL。**

### Q2 — 交叉點在哪

現在資料是「**200 客戶 × 1000 訂單**」。

請推理（不用真的建表，講清楚邏輯即可）：

| 情境 | 你選哪一種？為什麼？ |
|------|-------------------|
| 200 客戶 × 1000 訂單（現況） | ? |
| 50 萬客戶 × 每人 3 筆訂單 | ? |
| 10 客戶 × 每人 500 萬筆訂單 | ? |
| 只要查**單一**客戶的 Top 3（API 實際場景） | ? |

**寫出你判斷的依據公式**，不要只寫結論。

### Q3 — 索引的角色

把索引砍掉：

```sql
DROP INDEX idx_orders_customer_created;
ANALYZE orders;
```

四種解法各自變慢多少倍？**哪一種受影響最大？為什麼？**

（做完記得把索引加回來。）

### Q4 — 並列怎麼辦

如果兩筆訂單的 `created_at` **完全相同**，剛好卡在第 3、4 名：

- `ROW_NUMBER()` 會怎樣？
- `LIMIT 3` 會怎樣？
- 這是不是 bug？如果是，怎麼修？
- 什麼情況下你會改用 `RANK()` / `DENSE_RANK()`？（回去看你基礎訓練的 [department_top_three_salaries](../../../sql_training/department_top_three_salaries) 答案，當時你選對了嗎？）

### Q5 — 沒有訂單的客戶

現在有一位客戶完全沒有訂單。四種解法分別回傳什麼？

如果需求是「沒訂單的客戶也要出現在結果裡，訂單欄位顯示 NULL」，四種解法各要怎麼改？（提示：`CROSS JOIN LATERAL` vs `LEFT JOIN LATERAL`）

<br>

---

<br>

## 面試官的追問

> 1. 「`LATERAL` 和普通子查詢的本質差異是什麼？為什麼普通子查詢不能引用外層的欄位？」
>
> 2. 「`CROSS JOIN LATERAL` 和 `LEFT JOIN LATERAL ... ON true` 差在哪？什麼時候要用後者？」
>
> 3. 「Window function 的執行是在 `WHERE` 之前還是之後？所以為什麼不能寫 `WHERE ROW_NUMBER() OVER (...) <= 3`？」
>
> 4. 「如果這是 MySQL 8 而不是 PostgreSQL，四種解法哪些還能用？」
>
> 5. 「你的 API 一秒 2000 次請求，每次查一個客戶的 Top 3。你會怎麼設計？還要考慮什麼？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — LATERAL 的骨架</summary>

```sql
SELECT c.id, c.name, x.id AS order_id, x.created_at, x.rn
FROM customers c
CROSS JOIN LATERAL (
    SELECT o.id, o.created_at,
           ROW_NUMBER() OVER (ORDER BY o.created_at DESC) AS rn
    FROM orders o
    WHERE o.customer_id = c.id          -- ← 引用了外層的 c.id，這就是 LATERAL 的能力
    ORDER BY o.created_at DESC
    LIMIT 3
) x
ORDER BY c.id, x.rn;
```

關鍵：`WHERE o.customer_id = c.id` 讓子查詢**只掃這個客戶的訂單**，配合 `(customer_id, created_at DESC)` 索引 → 每個客戶只讀 3 行。

200 個客戶 × 3 行 = **600 行**，實測 `Buffers: shared hit=1200 read=3`。

</details>

<details>
<summary>Hint 2 — 為什麼 Window Function 慢</summary>

`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` 必須：

1. 讀取**全部** 20 萬行
2. 依 `(customer_id, created_at)` 排序（本題的索引順序剛好對得上，所以省掉了 Sort 節點 — 沒有索引的話還要多付一次排序）
3. 逐行計算 row_number
4. 丟掉 `rn > 3` 的 199,400 行

**關鍵是第 1 步：不管後面怎麼優化，它都得把 20 萬行從索引裡讀出來。**

PG 15+ 的 `Run Condition` 讓它可以在每個 partition 湊滿 3 筆後跳過該 partition 的剩餘行 —— 但實測 `Buffers` 顯示它**還是讀了 199,810 個緩衝區**。優化省下的是「計算與輸出」，不是「掃描」。

而 LATERAL 只讀 600 行。這就是為什麼在「組多、每組資料量大」的情況下 LATERAL 大勝。

反過來想：如果是「每組只有 3 筆」，window function 只多讀不了幾行，但 LATERAL 要付出 N 次索引查找的固定成本 → window 反而贏。**這就是 Q2 的交叉點。**

</details>

<details>
<summary>Hint 3 — DISTINCT ON 的真正定位</summary>

```sql
SELECT DISTINCT ON (customer_id) customer_id, id, created_at
FROM orders
ORDER BY customer_id, created_at DESC;   -- ORDER BY 必須以 DISTINCT ON 的欄位開頭
```

它只能取**每組第 1 筆**。要取 3 筆，你得先用 window function 算出 `rn` 再 `DISTINCT ON`，那就本末倒置了。

**`DISTINCT ON` 的定位是「每組取一筆」的最短寫法** — Top-1 用它，Top-N 用別的。這個判斷本身就是答案。

</details>

<details>
<summary>Hint 4 — 判斷公式</summary>

令：
- `G` = 組數（客戶數）
- `R` = 每組平均行數
- `N` = 總行數 = `G × R`
- `K` = 每組要取幾筆（這裡是 3）

| 解法 | 大致成本 |
|------|---------|
| Window | `O(N)` 掃描 + 可能的 `O(N log N)` 排序 |
| LATERAL（有索引） | `G × (索引查找 + K)` ≈ `O(G × log R)` |

**LATERAL 勝出的條件：`G × log R << N`，也就是 `R` 大。**

代入現況：`G=200, R=1000` → LATERAL 約 200 × 10 = 2000 單位；Window 約 200,000 單位。**LATERAL 大勝。**

代入「50 萬客戶 × 3 筆」：`G=500000, R=3` → LATERAL 約 500,000 × 2 = 100 萬；Window 約 150 萬 + 排序。**差距不大，window 的簡潔性可能更值得。**

</details>
