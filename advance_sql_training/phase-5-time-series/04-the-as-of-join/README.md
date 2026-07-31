# Phase 5-04 — The As-Of Join

> **難度**：★★★★★
> **核心技巧**：Point-in-time 正確性、as-of join（`LATERAL` / `DISTINCT ON` / window）
> **對應基礎題**：[LC 1164. Product Price at a Given Date](../../../sql_training/product_price_at_a_given_date)（你當初查的是**單一**指定日期）

<br>

---

<br>

## Interview Context

> *面試官：*「財務發現我們的海外營收報表和實際入帳差了 **27%**。
>
> 我們的訂單有歐元和日圓，報表要換算成美金。工程師的做法是：join 到匯率表拿**最新**的匯率。
>
> 你覺得問題在哪？」

<br>

**「用今天的匯率換算去年的訂單」** —— 這個錯誤在金融、電商、保險系統裡到處都是，而且因為報表**看起來完全正常**，通常要到對帳時才被發現。

正確的做法叫 **as-of join**：對每一筆訂單，取「**在訂單當下有效**」的那筆匯率。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS fx_orders;
DROP TABLE IF EXISTS fx_rates;

CREATE TABLE fx_rates (
    currency    CHAR(3) NOT NULL,
    rate_date   DATE NOT NULL,           -- 這個匯率從哪一天開始生效
    rate_to_usd NUMERIC(12,6) NOT NULL,
    PRIMARY KEY (currency, rate_date)
);

CREATE TABLE fx_orders (
    id         INT PRIMARY KEY,
    order_date DATE NOT NULL,
    amount     NUMERIC(12,2) NOT NULL,
    currency   CHAR(3) NOT NULL
);

INSERT INTO fx_rates (currency, rate_date, rate_to_usd) VALUES
('EUR','2026-01-01', 1.100000),
('EUR','2026-03-01', 1.050000),
('EUR','2026-06-01', 1.150000),
('JPY','2026-01-01', 0.007000),
('JPY','2026-04-01', 0.006500);

INSERT INTO fx_orders (id, order_date, amount, currency) VALUES
(1, '2026-02-15',   100.00, 'EUR'),
(2, '2026-03-05',   100.00, 'EUR'),
(3, '2026-07-01',   100.00, 'EUR'),
(4, '2026-02-01', 10000.00, 'JPY'),
(5, '2026-05-01', 10000.00, 'JPY'),
(6, '2025-12-01',   100.00, 'EUR');   -- ← 早於任何匯率紀錄
```

<br>

### 兩種算法

```
 id | order_date | 幣別 |  金額    | 天真版(最新匯率) | 正確版(as-of)
----+------------+------+----------+------------------+---------------
  1 | 2026-02-15 | EUR  |   100.00 |           115.00 |        110.00
  2 | 2026-03-05 | EUR  |   100.00 |           115.00 |        105.00
  3 | 2026-07-01 | EUR  |   100.00 |           115.00 |        115.00
  4 | 2026-02-01 | JPY  | 10000.00 |            65.00 |         70.00
  5 | 2026-05-01 | JPY  | 10000.00 |            65.00 |         65.00
  6 | 2025-12-01 | EUR  |   100.00 |           115.00 |        (NULL)
----+------------+------+----------+------------------+---------------
                            合計   |           590.00 |        465.00
```

<br>

---

<br>

## Part A — 重現錯誤

### A1

寫出天真版：先取每個幣別的最新匯率，再 join。

確認總額是 **590.00**。

### A2

回答：
- 訂單 1 用了哪一天的匯率？它**應該**用哪一天的？
- 為什麼訂單 3 和 5 的兩種算法**碰巧相同**？
- **6 筆訂單裡有 3 筆碰巧正確。** 這對「發現這個 bug」有什麼影響？

<br>

---

<br>

## Part B — As-Of Join

### B1 — 定義

用一句話定義 as-of join：

> 對左表的每一行，從右表取出「`rate_date` **小於等於** `order_date` 的所有列中，`rate_date` **最大**的那一筆」。

寫出三種實作：

| # | 方法 |
|---|------|
| 1 | `LEFT JOIN LATERAL (... ORDER BY rate_date DESC LIMIT 1) ON true` |
| 2 | 相關子查詢（`WHERE rate_date = (SELECT MAX(...) ...)`) |
| 3 | window function（把 orders 和 rates `UNION` 起來，用 `LAST_VALUE` / `LAG` 填補） |

三種都要跑出 465.00。

### B2 — 效能對比

`EXPLAIN (ANALYZE, BUFFERS)` 三種寫法。

- 加上 `CREATE INDEX ON fx_rates (currency, rate_date DESC);` 之後呢？
- 哪一種能有效利用索引？
- **這是 [Phase 1-05](../../phase-1-join-dark-side/05-top-n-four-ways) 的 LATERAL vs Window 對決重演。** 結論一樣嗎？

### B3 — 訂單 6

訂單 6 的日期早於所有匯率紀錄。

- `LEFT JOIN LATERAL ... ON true` 回傳什麼？
- 改成 `CROSS JOIN LATERAL` 會怎樣？（實測：6 筆變幾筆？）
- **總額 465.00 裡有沒有包含訂單 6？** `SUM` 遇到 NULL 的行為是什麼？
- 財務看到 465.00，他知道有一筆訂單被靜靜跳過了嗎？

### B4 — 該怎麼處理找不到匯率

寫出**三種**處理策略，並說明各自適合什麼情境：

1. 用最早的可用匯率往前補
2. 標記成 `UNCONVERTIBLE` 並在報表上單獨列出
3. 讓查詢直接失敗

**面試時你會推薦哪一種？為什麼？**

> 提示：財務報表的第一原則是「**寧可報錯，不可靜靜地少算**」。

<br>

---

<br>

## Part C — 邊界與設計

### C1 — 匯率當天生效嗎

`fx_rates` 有 `('EUR', '2026-03-01', 1.05)`。

- 一筆 `2026-03-01` 的訂單該用 1.10 還是 1.05？
- 你的 `<=` 和 `<` 會給出不同答案。**哪一個對？**
- 這是技術問題還是商業問題？你會怎麼問財務？

### C2 — 改成區間表

現在的 schema 只有 `rate_date`（生效起日），有效區間是隱含的。

改成顯式的 `valid_from` / `valid_to` 會有什麼好處和壞處？

> 這正是 [5-05](../05-scd-type-2-point-query) 的主題 —— **先想想，下一題會正式處理。**

### C3 — 時間戳而非日期

如果匯率是**每分鐘**更新（`rate_at TIMESTAMP`），而訂單也有精確時間戳：

- 你的 as-of join 要改什麼？
- 資料量從 5 筆變成每天 1440 筆 × 多幣別，效能會怎樣？
- **這種「對每一筆訂單找最近的一筆報價」在金融業叫什麼？** 為什麼專用的時序資料庫（kdb+、TimescaleDB）會內建這個操作？

<br>

---

<br>

## Part D — 更廣的意義

### D1 — 哪些欄位需要 as-of

回答：下列情境哪些需要 point-in-time 正確性？

| 情境 | 需要 as-of 嗎？ |
|------|----------------|
| 訂單金額換算匯率 | ? |
| 訂單顯示商品「目前」價格 | ? |
| 發票上的商品價格 | ? |
| 使用者的「目前」會員等級 | ? |
| 訂單享有的折扣（依當時會員等級） | ? |
| 業務員的「目前」所屬部門 | ? |
| 業績歸屬（依成交當時的部門） | ? |

**歸納出一個判準**：什麼時候該存快照、什麼時候該 as-of join？

### D2 — 更根本的解法

回答：
- 為什麼很多系統選擇在訂單成立時就把 `usd_amount` **寫死**存進訂單表？
- 這樣做的好處是什麼？壞處是什麼？（提示：匯率報錯了要怎麼修？）
- **as-of join 和快照欄位，你會怎麼選？**

<br>

---

<br>

## 面試官的追問

> 1. 「as-of join 和一般 join 在關聯代數上的差別是什麼？」
>
> 2. 「如果左表有 1000 萬筆訂單、右表有 100 萬筆匯率，你會怎麼優化？」
>
> 3. 「有沒有辦法用一次排序 + window function 做完 as-of join，不用對每筆訂單查一次？」
>
> 4. 「如果匯率資料**遲到**了（訂單當下還沒有那天的匯率，隔天才補進來），報表要怎麼處理？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — LATERAL 版本</summary>

```sql
SELECT o.id, o.order_date, o.amount, o.currency,
       r.rate_date AS rate_used,
       ROUND(o.amount * r.rate_to_usd, 2) AS usd
FROM fx_orders o
LEFT JOIN LATERAL (
    SELECT f.rate_date, f.rate_to_usd
    FROM fx_rates f
    WHERE f.currency = o.currency
      AND f.rate_date <= o.order_date        -- ← 只看訂單當下「已經存在」的匯率
    ORDER BY f.rate_date DESC                -- ← 取最接近的
    LIMIT 1
) r ON true
ORDER BY o.id;
```

三個要素缺一不可：
- `f.rate_date <= o.order_date` —— **不能用未來的資料**
- `ORDER BY f.rate_date DESC LIMIT 1` —— 取最新的那一筆有效匯率
- `LEFT JOIN ... ON true` —— 找不到匯率時**保留訂單**

配 `CREATE INDEX ON fx_rates (currency, rate_date DESC)`，每筆訂單只要一次索引查找 —— 這是 [Phase 1-05](../../phase-1-join-dark-side/05-top-n-four-ways) 學的 LATERAL + 索引模式。

</details>

<details>
<summary>Hint 2 — 為什麼 3 筆碰巧正確</summary>

- **訂單 3**（`2026-07-01` EUR）：它在最後一次匯率變動（`2026-06-01`）**之後**，所以「最新匯率」剛好就是「當時的匯率」。
- **訂單 5**（`2026-05-01` JPY）：同理，在 `2026-04-01` 之後。
- **訂單 6**：天真版給了 115.00（用最新 EUR 匯率），正確版給 NULL —— **這不是「碰巧正確」，是天真版憑空捏造了一個數字。**

**最近期的訂單一定是對的** —— 這就是為什麼這個 bug 特別難發現：

工程師測試時通常用最新的資料，而最新的資料永遠正確。**只有回頭看歷史報表時才會發現不對。**

**歸納**：任何「用當前狀態解讀歷史事件」的 bug，都有這個特徵 —— 越新的資料越正確，越舊的資料錯得越離譜。

</details>

<details>
<summary>Hint 3 — Window function 版本</summary>

把兩張表 `UNION` 成一條時間軸，然後用 LOCF（前值填補）：

```sql
WITH tl AS (
    SELECT currency, rate_date AS d, rate_to_usd,
           NULL::int AS order_id, NULL::numeric AS amount
    FROM fx_rates
    UNION ALL
    SELECT currency, order_date, NULL::numeric,      -- ← 這個 ::numeric 不能省，見下方
           id, amount
    FROM fx_orders
),
filled AS (
    SELECT *,
           COUNT(rate_to_usd) OVER (PARTITION BY currency
                                    ORDER BY d, (order_id IS NOT NULL)
                                    ROWS UNBOUNDED PRECEDING) AS grp
    FROM tl
)
SELECT order_id, amount, currency,
       FIRST_VALUE(rate_to_usd) OVER (PARTITION BY currency, grp
                                      ORDER BY d, (order_id IS NOT NULL)) AS rate
FROM filled
WHERE order_id IS NOT NULL
ORDER BY order_id;
```

驗證結果：`110 / 105 / 115 / 70 / 65 / NULL` —— 和 LATERAL 版完全一致。

> ⚠️ **`NULL::numeric` 那個轉型不能省。**
> 寫成裸的 `NULL`，`UNION ALL` 的型別解析會讓整個 `rate_to_usd` 欄位變成 NULL，
> 查詢**不報錯**但每一筆 rate 都是空的。
> 這和 [Phase 4](../../README.md#phase-4遞迴-cte-進階--圖樹與展開) 的遞迴 CTE 型別陷阱是同一家族：
> **集合運算（`UNION` / 遞迴）的欄位型別要顯式對齊，否則會安靜地壞掉。**

**核心技巧和 [5-06](../06-days-with-no-sales) 的 LOCF 完全相同**：用 `COUNT(非空欄位) OVER (...)` 產生分組編號，同一組內 `FIRST_VALUE` 就是最近一筆非空值。

排序的 tie-breaker `(order_id IS NOT NULL)` 很重要 —— 同一天有匯率也有訂單時，**匯率必須排在訂單前面**（先生效才能用）。這對應 C1 的 `<=` vs `<` 問題。

訂單 6（早於所有匯率）的 `grp` 會是 **0**，而 grp=0 這一組裡沒有任何匯率列 → `FIRST_VALUE` 回傳 NULL。**邊界自動處理好了**，不用特別寫 `CASE`。

優點：只要**一次排序**掃完所有訂單，不用每筆查一次 —— 這是面試官追問 3 的答案，訂單量很大時遠勝 LATERAL。

</details>

<details>
<summary>Hint 4 — D1 的判準</summary>

| 情境 | as-of？ | 理由 |
|------|--------|------|
| 訂單換算匯率 | ✅ | 交易當下的事實，不能被之後的匯率改變 |
| 商品「目前」價格 | ❌ | 問的就是現在，直接查最新 |
| **發票上**的商品價格 | ✅ | 法律文件，必須凍結在開立當下 |
| 使用者「目前」會員等級 | ❌ | 問的就是現在 |
| 訂單享有的折扣 | ✅ | 依成交當時的等級，事後升級不能追溯 |
| 業務員「目前」部門 | ❌ | 問的就是現在 |
| 業績歸屬 | ✅ | 依成交當時的部門，換部門不能把舊業績帶走 |

**判準**：

> **問題是關於「現在的狀態」→ 查最新。**
> **問題是關於「某個歷史事件當下的事實」→ as-of join 或存快照。**

一個好用的檢查句：**「如果這個維度值明天改了，這個數字應該跟著變嗎？」**
- 應該變 → 查最新
- **不應該變** → point-in-time

D2 的答案：實務上高價值、不可變的欄位（發票金額、成交匯率）通常**直接存快照** —— 因為它讀取快、語意明確、而且不怕維度表被改壞。代價是匯率報錯時要回頭修訂單資料（而且要留修訂軌跡）。

**as-of join 適合分析場景，快照適合交易場景。**

</details>
