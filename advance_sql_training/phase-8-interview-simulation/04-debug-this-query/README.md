# Phase 8-04 — Debug This Query

> **難度**：★★★★★
> **會用到**：[1-01 NULL](../../phase-1-join-dark-side/01-the-null-that-ate-your-results)、[1-07 ON vs WHERE](../../phase-1-join-dark-side/07-the-report-with-missing-rows)、[2-07 扇出](../../phase-2-aggregation-limits/07-the-count-that-lied)、[7-06 BETWEEN](../../phase-7-optimization-deep-water/06-partition-pruning-gone-wrong)
> **性質**：這是**唯一一題有標準答案**的 Phase 8 題目

<br>

---

<br>

## Interview Context

> *面試官：*「這是我們的月報表查詢，跑了一年了。
>
> 上個月財務說數字對不上，但沒人找得出問題。
>
> 你有 20 分鐘。**找出所有 bug。**」

<br>

**這一題有 5 個 bug**，全部都是你在 Phase 1~7 學過的。

它們的共同特徵：**查詢不會報錯，結果看起來完全合理。**

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS refunds;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    id      INT PRIMARY KEY,
    name    TEXT NOT NULL,
    country TEXT,                                  -- 可為 NULL
    is_test BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    status      TEXT NOT NULL,                     -- 'paid' / 'cancelled'
    amount      NUMERIC(10,2) NOT NULL,
    ordered_at  TIMESTAMPTZ NOT NULL
);

CREATE TABLE refunds (
    id       INT PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id),
    amount   NUMERIC(10,2) NOT NULL
);

CREATE TABLE reviews (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(id),
    rating      INT NOT NULL
);

INSERT INTO customers VALUES
(1,'alice','TW',false),
(2,'bob','TW',false),
(3,'carol','JP',false),
(4,'dave',NULL,false),            -- country 是 NULL
(5,'test_acct','TW',true);        -- 測試帳號

INSERT INTO orders VALUES
(101,1,'paid',100.00,'2026-03-05 10:00'),
(102,1,'paid',100.00,'2026-03-10 10:00'),      -- 和 101 同金額
(103,1,'paid',400.00,'2026-03-20 10:00'),
(104,2,'paid',250.00,'2026-03-15 10:00'),
(105,3,'paid',300.00,'2026-03-31 14:00'),      -- 3/31 下午
(106,4,'paid',150.00,'2026-03-18 10:00'),
(107,5,'paid',999.00,'2026-03-12 10:00'),      -- 測試帳號的訂單
(108,2,'cancelled',500.00,'2026-03-22 10:00'); -- 已取消

INSERT INTO refunds VALUES (201,101,30.00),(202,103,50.00);
INSERT INTO reviews VALUES (301,1,5),(302,1,3),(303,2,4),(304,3,5);
```

<br>

---

<br>

## The Query

需求：**2026 年 3 月，各國的「下單客戶數 / 訂單數 / 淨營收（扣退款）/ 平均評分」，排除測試帳號。**

```sql
SELECT COALESCE(c.country,'(unknown)')          AS country,
       COUNT(*)                                  AS customers,
       COUNT(o.id)                               AS orders,
       SUM(o.amount) - COALESCE(SUM(rf.amount),0) AS net_revenue,
       ROUND(AVG(rv.rating),2)                    AS avg_rating
FROM customers c
LEFT JOIN orders  o  ON o.customer_id  = c.id
LEFT JOIN refunds rf ON rf.order_id    = o.id
LEFT JOIN reviews rv ON rv.customer_id = c.id
WHERE o.ordered_at BETWEEN '2026-03-01' AND '2026-03-31'
  AND c.id NOT IN (SELECT id FROM customers WHERE is_test)
GROUP BY 1
ORDER BY 1;
```

<br>

### 它的輸出

```
  country  | customers | orders | net_revenue | avg_rating
-----------+-----------+--------+-------------+------------
 (unknown) |         1 |      1 |      150.00 |
 TW        |         8 |      8 |     1790.00 |       4.00
```

### 正確答案

```
  country  | customers | orders | net_revenue
-----------+-----------+--------+-------------
 (unknown) |         1 |      1 |      150.00
 JP        |         1 |      1 |      300.00
 TW        |         2 |      4 |      770.00
```

<br>

> **JP 整個不見了。TW 的客戶數多了 4 倍，營收多了 1020 元。**

<br>

---

<br>

## Part A — 找出 bug（40 分）

### A1

**先不要往下看。** 給自己 20 分鐘，找出所有問題並記錄。

每找到一個，寫出：
1. **哪一行**有問題
2. **為什麼**錯
3. **它造成什麼具體症狀**（對照上面兩張表）
4. **怎麼修**

### A2 — 逐項驗證

對你找到的每一個 bug，**寫一個獨立的小查詢證明它確實存在**。

例如懷疑 `BETWEEN` 有問題：

```sql
SELECT count(*) FROM orders WHERE ordered_at BETWEEN '2026-03-01' AND '2026-03-31';
SELECT count(*) FROM orders WHERE ordered_at >= '2026-03-01' AND ordered_at < '2026-04-01';
```

**不能只憑「看起來怪」就說是 bug** —— 要有證據。

### A3 — 症狀對應

填完這張表（每個 bug 對應到哪個錯誤數字）：

| 症狀 | 是哪個 bug 造成的 |
|------|-----------------|
| JP 整列消失 | ? |
| TW 的 `customers` = 8（應為 2） | ? |
| TW 的 `orders` = 8（應為 4） | ? |
| TW 的 `net_revenue` = 1790（應為 770） | ? |
| `(unknown)` 的 `avg_rating` 是空的 | ? |

**注意最後一個** —— 它到底是 bug 還是正確行為？

<br>

---

<br>

## Part B — 修正（30 分）

### B1

寫出**完全正確**的查詢，輸出必須和「正確答案」逐格相符。

### B2 — 為什麼不能一個一個修

回答：
- 如果你只修 `BETWEEN`，JP 會回來，但 TW 的數字修好了嗎？
- **扇出（fan-out）能靠加 `DISTINCT` 修好嗎？** 試一次（`COUNT(DISTINCT)` / `SUM(DISTINCT)`），看 `net_revenue` 變成多少。
- 為什麼 `SUM(DISTINCT o.amount)` 也是錯的？（提示：訂單 101 和 102 都是 100.00）

> 這是 [2-07 Part B1](../../phase-2-aggregation-limits/07-the-count-that-lied) 的結論在真實報表裡的樣子：
> **`DISTINCT` 能救 `COUNT`，救不了 `SUM`。**

### B3 — 正確的結構

**這個查詢的根本問題不是「哪一行寫錯」，是結構錯了。**

回答：
- 三個 `LEFT JOIN` 掛在同一張表上，為什麼必然出問題？
- 正確的結構應該是什麼？（提示：預聚合）
- 你的 B1 用了幾個 CTE？各自負責什麼？

<br>

---

<br>

## Part C — 防禦（20 分）

### C1 — 自我檢查查詢

寫出**三個**驗證查詢，讓這種錯誤下次能被自動抓到：

- 各國營收加總 = 全站營收？
- 各國客戶數加總 = 有下單的客戶總數？
- 報表的訂單數 = 明細表的訂單數？

> 這是 [2-06 Part B1](../../phase-2-aggregation-limits/06-histogram-with-empty-buckets) 的「直方圖對帳」和
> [1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) 的對帳思維第三次出現。
> **任何會被拿去做決策的彙總查詢，都該附帶對帳檢查。**

### C2 — Code review 檢查表

寫一份**報表 SQL 的 review 檢查表**，涵蓋這 5 個 bug 的類型。

格式：

```
□ 有沒有多個一對多的 JOIN 掛在同一張表上？（扇出）
□ ...
```

### C3 — 這個 bug 為什麼活了一年

回答：
- 為什麼財務直到上個月才發現？
- 什麼情況下這個查詢**會碰巧正確**？
- **哪一種 bug 最難被發現？為什麼？**

<br>

---

<br>

## Part D — 延伸（10 分）

### D1

需求方現在要加一欄「**該國的平均客單價**」。

- 在你 B1 的正確結構上加，容易嗎？
- 在原本的錯誤結構上加，會發生什麼？
- **這說明了什麼？**

### D2

回答：如果這是你的同事寫的 PR，你會怎麼給回饋？

（提示：不要只說「這裡錯了」—— 說明**為什麼**、以及**怎麼避免下次再犯**）

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 五個 bug（真的想清楚了再看）</summary>

**Bug 1：`BETWEEN` 在 `TIMESTAMPTZ` 上漏掉最後一天**

```sql
WHERE o.ordered_at BETWEEN '2026-03-01' AND '2026-03-31'
```

`'2026-03-31'` 被解讀成 `2026-03-31 00:00:00` → 訂單 105（3/31 **14:00**）被排除 → **JP 整列消失**。

實測：`BETWEEN` 抓到 7 筆，半開區間抓到 8 筆。

修：`>= '2026-03-01' AND < '2026-04-01'`（[7-06](../../phase-7-optimization-deep-water/06-partition-pruning-gone-wrong)）

<br>

**Bug 2：扇出（fan-out）**

`orders` 和 `reviews` 都是一對多掛在 `customers` 上 → 互相做笛卡兒積。

alice 有 3 筆訂單 × 2 則評論 = **6 列**。加上 refunds 又是一層。

→ `orders` 被灌水、`SUM(o.amount)` 被灌水。

修：**預聚合**（[2-07 Part B2](../../phase-2-aggregation-limits/07-the-count-that-lied)）

<br>

**Bug 3：`COUNT(*)` 數的是 JOIN 後的列數**

`COUNT(*)` 在 `GROUP BY country` 之後數的是**該組的列數**，不是客戶數 → TW 得到 8。

修：`COUNT(DISTINCT c.id)`，或（更好）在預聚合的結構上直接 `COUNT(*)`。

<br>

**Bug 4：漏掉 `status = 'paid'`**

訂單 108 是 `cancelled`（500.00），卻被算進營收。

修：`WHERE o.status = 'paid'`（**但要放對位置** —— 見 Bug 5）

<br>

**Bug 5：`WHERE` 放在 `LEFT JOIN` 的右表欄位上**

```sql
LEFT JOIN orders o ON ...
WHERE o.ordered_at BETWEEN ...          -- ← 把 LEFT JOIN 降級成 INNER JOIN
```

沒有訂單的客戶會被整個濾掉。本題「只列有下單的國家」剛好想要這個效果，**所以它碰巧不影響結果** ——
但這是**意圖不明確**的寫法，而且一旦需求改成「所有國家都要列出」就會壞掉。

（[1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的核心教訓）

</details>

<details>
<summary>Hint 2 — 正確的查詢</summary>

```sql
WITH o AS (                              -- 訂單預聚合：每客戶一列
    SELECT customer_id,
           count(*)    AS n_orders,
           sum(amount) AS gross
    FROM orders
    WHERE status = 'paid'
      AND ordered_at >= '2026-03-01' AND ordered_at < '2026-04-01'
    GROUP BY customer_id
),
r AS (                                   -- 退款預聚合：每客戶一列
    SELECT ord.customer_id, sum(rf.amount) AS refunded
    FROM refunds rf
    JOIN orders ord ON ord.id = rf.order_id
    WHERE ord.status = 'paid'
      AND ord.ordered_at >= '2026-03-01' AND ord.ordered_at < '2026-04-01'
    GROUP BY ord.customer_id
)
SELECT COALESCE(c.country,'(unknown)') AS country,
       count(*)                        AS customers,
       sum(o.n_orders)                 AS orders,
       sum(o.gross) - COALESCE(sum(r.refunded),0) AS net_revenue
FROM customers c
JOIN o      ON o.customer_id = c.id     -- INNER：只要有下單的客戶
LEFT JOIN r ON r.customer_id = c.id     -- LEFT：可能沒退款
WHERE NOT c.is_test
GROUP BY 1
ORDER BY 1;
```

**結構的關鍵**：把每個「一對多」在 JOIN **之前**壓成「一對一」。
壓完之後，`c` 對 `o`、`c` 對 `r` 都是一對一 → **不可能扇出**。

`JOIN o`（INNER）明確表達「只要有下單的客戶」——比用 `LEFT JOIN` + `WHERE` 隱含地達到同樣效果清楚得多。

**`avg_rating` 我拿掉了** —— 因為它需要第三個一對多聚合。要加的話再開一個 CTE，
**但要先問需求方：「平均評分」是該國所有客戶的評分，還是只有三月有下單的客戶的評分？**（這是 D1 的伏筆）

</details>

<details>
<summary>Hint 3 — 為什麼 DISTINCT 修不好</summary>

試著用 `DISTINCT` 修：

```sql
COUNT(DISTINCT c.id)    AS customers,      -- ✅ 修好了：2
COUNT(DISTINCT o.id)    AS orders,         -- ✅ 修好了：4
SUM(DISTINCT o.amount)  AS gross           -- ❌ 還是錯
```

alice 的訂單金額是 **100, 100, 400**。

`SUM(DISTINCT o.amount)` 先對**值**去重 → `{100, 400}` → 500，而正確答案是 **600**。

**`DISTINCT` 去重的是「值」，但 alice 本來就有兩筆真實的 100 元訂單。** 它分不出「扇出複製的 100」和「本來就存在的第二筆 100」。

**這就是為什麼測資裡訂單 101 和 102 都是 100.00** —— 如果設成 100 和 200，`SUM(DISTINCT)` 會**碰巧算對**，你就學不到這一課。

**結論**（[2-07](../../phase-2-aggregation-limits/07-the-count-that-lied) Hint 3 的原話）：
`DISTINCT` 能救 `COUNT`（因為它去重的是**主鍵**，主鍵天生唯一），救不了 `SUM`/`AVG`（它們去重的是**度量值**，度量值本來就會重複）。

</details>

<details>
<summary>Hint 4 — C3 為什麼活了一年</summary>

**它在什麼情況下碰巧正確？**

- 客戶只有 1 筆訂單 **且** 0~1 則評論 → 不扇出
- 沒有人在月底最後一天下單 → `BETWEEN` 不漏
- 沒有取消的訂單 → 沒有 `status` 問題

**小公司初期這三個條件經常成立** —— 訂單少、評論少、月底剛好沒單。查詢從第一天就是錯的，但輸出一直是對的。

**隨著業務成長，這三個條件逐一失效** —— 而且是**漸進**的：這個月多算 2%，下個月多算 5%……
沒有人會注意到一個緩慢上升的營收數字有問題。

**最難發現的是哪一個？**

**扇出**。因為：
- `BETWEEN` 漏資料 → 整列消失，比較容易被注意到（「JP 呢？」）
- `status` 沒過濾 → 數字偏高但穩定，對帳時能抓到
- **扇出 → 倍數隨著「每個客戶的訂單數 × 評論數」浮動**，每個月的膨脹比例都不一樣，看起來就像正常的業務波動

**這就是為什麼 C1 的對帳查詢這麼重要**：
`各國營收加總` vs `全站營收` 這種不變式檢查，能在任何一種 bug 出現時立刻亮紅燈 ——
**而且不需要你事先知道會出什麼 bug。**

</details>
