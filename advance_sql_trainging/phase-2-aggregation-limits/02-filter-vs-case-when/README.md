# Phase 2-02 — FILTER vs CASE WHEN

> **難度**：★★★☆☆
> **核心技巧**：`FILTER (WHERE ...)` 子句、條件聚合、`COUNT` 對 NULL 的行為
> **對應基礎題**：[LC 1907. Count Salary Categories](../../../sql_training/count_salary_categories)（你當初的 `CASE WHEN` 條件分組）

<br>

---

<br>

## Interview Context

> *面試官：*「這是我們營運儀表板的查詢。上週產品經理說『已完成訂單數』看起來怪怪的 —— 這個數字**永遠等於總訂單數**。
>
> 工程師說他測過了，`CASE WHEN` 寫得沒問題。
>
> 你看一下。順便告訴我 PostgreSQL 有沒有更好的寫法。」

<br>

這一題的 bug **每天都在正式環境裡發生**，而且不會報錯。看你能不能在 30 秒內指出來。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL,
    status      VARCHAR(20),              -- ← 可為 NULL：舊資料沒有狀態欄位
    amount      NUMERIC(10,2) NOT NULL,
    paid_with   VARCHAR(20),              -- ← 可為 NULL：未付款
    created_at  DATE NOT NULL
);

INSERT INTO orders (id, customer_id, status, amount, paid_with, created_at) VALUES
(1,  1, 'completed', 100.00, 'card',   '2026-03-01'),
(2,  1, 'completed', 250.00, 'card',   '2026-03-02'),
(3,  2, 'completed', 300.00, 'paypal', '2026-03-03'),
(4,  3, 'completed',  50.00, 'card',   '2026-03-04'),
(5,  2, 'pending',   120.00, 'card',   '2026-03-05'),
(6,  4, 'pending',    80.00, 'paypal', '2026-03-06'),
(7,  1, 'pending',   200.00, NULL,     '2026-03-07'),
(8,  3, 'cancelled', 400.00, 'card',   '2026-03-08'),
(9,  5, 'cancelled',  60.00, NULL,     '2026-03-09'),
(10, 4, NULL,         90.00, 'card',   '2026-03-10');   -- ← status 是 NULL
```

<br>

### 真實分布

```
 status    | count
-----------+-------
 completed |     4
 pending   |     3
 cancelled |     2
 (NULL)    |     1
```

<br>

---

<br>

## The Broken Query

```sql
SELECT COUNT(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
       COUNT(*) AS total_orders
FROM orders;
```

**回傳：`completed_orders = 10`, `total_orders = 10`。**

<br>

---

<br>

## Part A — 抓出 bug

### A1

為什麼 `completed_orders` 是 10 不是 4？

關鍵在 `COUNT()` 的定義。回答：
- `COUNT(expr)` 到底在數什麼？
- `CASE WHEN status='completed' THEN 1 ELSE 0 END` 對第 5 筆（pending）求值是什麼？
- 那個值會被 `COUNT` 算進去嗎？

**寫出這句結論**：`COUNT()` 數的是 `______`，不是 `______`。

### A2

寫出**四種**都回傳 4 的正確寫法：

| # | 寫法 |
|---|------|
| 1 | 拿掉 `ELSE 0` 的 `COUNT(CASE ...)` |
| 2 | `SUM(CASE ... THEN 1 ELSE 0 END)` |
| 3 | `COUNT(*) FILTER (WHERE ...)` |
| 4 | `SUM(1) FILTER (WHERE ...)` 或其他你想到的 |

### A3

`SUM(CASE ... THEN 1 ELSE 0 END)` 是正確的，但它和 `COUNT(*) FILTER` 在**沒有任何一筆符合條件**時行為不同。

建一張空表或加一個不存在的條件測測看，回答：
- `SUM(CASE ...)` 回傳什麼？
- `COUNT(*) FILTER (...)` 回傳什麼？
- 這個差異在報表上會造成什麼問題？怎麼防？

<br>

---

<br>

## Part B — `FILTER` 的威力

### B1 — 一次查詢做完整個儀表板

用 `FILTER` 寫出一個查詢，一次算出：

- 總訂單數
- 各狀態的訂單數（completed / pending / cancelled / 未知）
- 已完成訂單的總金額
- 已完成訂單的平均金額
- 用信用卡付款的已完成訂單數
- 有下過已完成訂單的**不重複客戶數**

然後用 `CASE WHEN` 寫一次同樣的東西，比較兩者的行數與可讀性。

### B2 — `AVG` 的陷阱

比較這三個：

```sql
AVG(amount) FILTER (WHERE status = 'completed')
AVG(CASE WHEN status = 'completed' THEN amount END)
AVG(CASE WHEN status = 'completed' THEN amount ELSE 0 END)
```

前兩個都回傳 **175.00**，第三個回傳 **70.00**。

- 為什麼第三個不一樣？
- 175 和 70 分別是怎麼算出來的？
- **這個錯誤如果出現在「平均客單價」報表上，會導致什麼商業決策錯誤？**

### B3 — `FILTER` + `DISTINCT`

`COUNT(DISTINCT customer_id) FILTER (WHERE status = 'completed')` 回傳 3。

- 用 `CASE WHEN` 寫出等價的版本。
- 哪一種比較好讀？
- `DISTINCT` 和 `FILTER` 的**求值順序**是什麼？（先過濾再去重，還是先去重再過濾？）

<br>

---

<br>

## Part C — NULL 又來了

### C1

跑這兩個：

```sql
SELECT COUNT(*) FILTER (WHERE status <> 'completed')                  AS a,
       COUNT(*) FILTER (WHERE status IS DISTINCT FROM 'completed')    AS b
FROM orders;
```

結果是 **a = 5，b = 6**。

- 差的那一筆是誰？
- 為什麼 `<>` 抓不到它？
- 「非已完成訂單數」到底該是 5 還是 6？**這是技術問題還是商業問題？**

> 這是 [Phase 1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) 的 `IS DISTINCT FROM` 又回來了。
> **同一個 NULL 陷阱，換一個地方咬你。**

### C2

`status` 是 NULL 的那一筆訂單，在你 B1 的儀表板裡跑到哪去了？

如果 PM 說「未知狀態的也要單獨列一欄」，怎麼寫？（`FILTER (WHERE status IS NULL)`）

驗證你的各狀態數字加起來等於總數 —— **報表的自我檢查**。

<br>

---

<br>

## 面試官的追問

> 1. 「`FILTER` 是 PostgreSQL 專屬語法還是 SQL 標準？MySQL 支援嗎？如果要寫可攜的 SQL 你選哪一種？」
>
> 2. 「`FILTER` 和 `CASE WHEN` 的執行計畫一樣嗎？跑 `EXPLAIN` 看看。有效能差異嗎？」
>
> 3. 「`WHERE status = 'completed'` 和 `COUNT(*) FILTER (WHERE status = 'completed')` 差在哪？什麼時候該用 `WHERE`、什麼時候該用 `FILTER`？」
>
> 4. 「`FILTER` 可以用在 window function 上嗎？`SUM(x) FILTER (WHERE ...) OVER (...)` 合法嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — COUNT 到底數什麼</summary>

**`COUNT(expr)` 數的是「`expr` 不為 NULL 的行數」。**

`CASE WHEN status='completed' THEN 1 ELSE 0 END` 對每一行都回傳一個值 —— 符合條件回傳 `1`，不符合回傳 `0`。

**`0` 不是 NULL。** 所以 10 行全部都被數進去。

拿掉 `ELSE 0` 之後，`CASE` 在不符合時回傳 **NULL**（`CASE` 沒有 `ELSE` 時預設就是 NULL），`COUNT` 就會跳過它們 → 4。

這就是為什麼 `SUM(CASE ... ELSE 0)` 是對的（0 加了等於沒加）而 `COUNT(CASE ... ELSE 0)` 是錯的。

</details>

<details>
<summary>Hint 2 — FILTER 的語法</summary>

```sql
SELECT
    COUNT(*)                                            AS total,
    COUNT(*) FILTER (WHERE status = 'completed')        AS completed,
    COUNT(*) FILTER (WHERE status IS NULL)              AS unknown_status,
    SUM(amount) FILTER (WHERE status = 'completed')     AS completed_revenue,
    AVG(amount) FILTER (WHERE status = 'completed')     AS completed_aov,
    COUNT(DISTINCT customer_id) FILTER (WHERE status = 'completed') AS completed_customers
FROM orders;
```

`FILTER` 接在聚合函數**後面**，只影響那一個聚合。它是 SQL:2003 標準，PostgreSQL 9.4+ 支援。

</details>

<details>
<summary>Hint 3 — 175 vs 70</summary>

已完成訂單金額：100, 250, 300, 50 → 4 筆，總和 700。

- `AVG(...) FILTER`：只看那 4 筆 → `700 / 4` = **175**
- `AVG(CASE ... ELSE 0)`：10 筆全參與，其中 6 筆被塞成 0 → `700 / 10` = **70**

**`ELSE 0` 把「不適用」變成了「值為零」。** 前者不該進分母，後者會拉低平均。

這在財報上是災難級的錯誤 —— 平均客單價被低估 60%，可能導致砍掉一個其實賺錢的行銷渠道。

</details>

<details>
<summary>Hint 4 — SUM vs COUNT 的空集合行為</summary>

- `SUM(...)` 對空集合回傳 **NULL**
- `COUNT(...)` 對空集合回傳 **0**

所以「本月完成訂單數」用 `SUM(CASE ...)` 在零訂單的月份會顯示空白而不是 0，報表上很難看，還可能讓下游的計算變成 NULL。

用 `COUNT(*) FILTER`，或 `COALESCE(SUM(...), 0)`。

</details>
