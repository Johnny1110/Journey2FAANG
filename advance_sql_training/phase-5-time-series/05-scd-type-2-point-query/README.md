# Phase 5-05 — SCD Type 2 Point Query

> **難度**：★★★★☆
> **核心技巧**：緩慢變化維度、`valid_from` / `valid_to` 區間語意、**重疊與缺口稽核**
> **對應基礎題**：[LC 1164. Product Price at a Given Date](../../../sql_training/product_price_at_a_given_date)

<br>

---

<br>

## Interview Context

> *面試官：*「我們的商品價格用 SCD Type 2 存 —— 每次改價新增一列，帶生效區間。
>
> 昨天客服回報：同一張歷史訂單，重算金額時**跑出兩個不同的價格**。
>
> 而且另一個商品重算時**完全查不到價格**。
>
> 兩個問題都給我找出來，然後告訴我怎麼防。」

<br>

[5-04](../04-the-as-of-join) 處理的是「只有生效起日」的表。這一題處理**顯式區間**的表 —— 它更清楚，但也多了兩種新的壞法：**區間重疊**和**區間缺口**。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS product_price_scd;

CREATE TABLE product_price_scd (
    product_id INT NOT NULL,
    price      NUMERIC(10,2) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to   DATE                    -- NULL = 目前仍有效
);

INSERT INTO product_price_scd (product_id, price, valid_from, valid_to) VALUES
-- P1：乾淨的歷史（半開區間，首尾相接）
(1, 10.00, '2026-01-01', '2026-03-01'),
(1, 12.00, '2026-03-01', '2026-06-01'),
(1, 15.00, '2026-06-01', NULL),
-- P2：二月有一個缺口
(2, 20.00, '2026-01-01', '2026-02-01'),
(2, 25.00, '2026-03-01', NULL),
-- P3：三月有重疊  ← 客服看到兩個價格的元兇
(3, 30.00, '2026-01-01', '2026-04-01'),
(3, 35.00, '2026-03-01', NULL),
-- P4：只有一列，一直有效
(4, 40.00, '2026-01-01', NULL);
```

<br>

---

<br>

## Part A — 重現兩個 bug

### A1 — 查 `2026-03-15` 的價格

```sql
SELECT product_id, price, valid_from, valid_to
FROM product_price_scd
WHERE DATE '2026-03-15' >= valid_from
  AND (valid_to IS NULL OR DATE '2026-03-15' < valid_to)
ORDER BY product_id, valid_from;
```

你會得到 **5 行**，但只有 4 個商品：

```
 product_id | price | valid_from |  valid_to
------------+-------+------------+------------
          1 | 12.00 | 2026-03-01 | 2026-06-01
          2 | 25.00 | 2026-03-01 |
          3 | 30.00 | 2026-01-01 | 2026-04-01     ← 兩行
          3 | 35.00 | 2026-03-01 |                ← 兩行
          4 | 40.00 | 2026-01-01 |
```

回答：
- **P3 為什麼有兩行？**
- 如果這個查詢是拿來 join 訂單表算金額，會發生什麼事？
  （提示：這就是 [Phase 2-07](../../phase-2-aggregation-limits/07-the-count-that-lied) 的扇出）
- 一個「點查詢」回傳兩行，**這算 SQL 寫錯還是資料壞了？**

### A2 — 查 `2026-02-15` 的價格

用 `LEFT JOIN` 保證四個商品都出現：

```
 product_id | price
------------+-------
          1 | 10.00
          2 |               ← 查不到
          3 | 30.00
          4 | 40.00
```

回答：
- **P2 為什麼查不到？**
- 商品在 2026-02-15 真的沒有價格嗎？還是資料漏了？
- 如果訂單金額算不出來，系統該怎麼反應？（回想 [5-04](../04-the-as-of-join) Part B4）

<br>

---

<br>

## Part B — 稽核

### B1 — 找出所有重疊

寫一個查詢，找出 `product_price_scd` 中所有**區間重疊**的列對。

預期只有 P3：

```
 product_id |   a_from   |    a_to    |   b_from   | b_to
------------+------------+------------+------------+------
          3 | 2026-01-01 | 2026-04-01 | 2026-03-01 |
```

> 這是 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 的區間重疊條件**第三次**出現。
> 差別是這裡的 `valid_to` 可能是 NULL（代表無限大）—— 想清楚怎麼處理。

### B2 — 找出所有缺口

寫一個查詢，找出所有**時間缺口**。

預期只有 P2：

```
 product_id |  gap_from  |   gap_to
------------+------------+------------
          2 | 2026-02-01 | 2026-03-01
```

提示：用 `LEAD(valid_from)` 比對當前列的 `valid_to`。

### B3 — 其他該檢查的

除了重疊和缺口，一個健康的 SCD2 表還該滿足什麼？寫出稽核查詢：

- 每個 `product_id` 最多只能有**一列** `valid_to IS NULL`
- `valid_from < valid_to`（不能有負長度或零長度區間）
- 不能有**孤兒**（`product_id` 不存在於商品主檔）

### B4 — 把稽核變成常態

回答：
- 這三個稽核查詢該多久跑一次？
- 能不能做成資料庫約束，讓壞資料**寫不進去**？哪些做得到、哪些做不到？
- PostgreSQL 的 `EXCLUDE` 約束能擋掉重疊嗎？寫出 DDL。
  （這是 [Phase 6](../../README.md#phase-6dml併發與資料正確性) 的內容 —— 先預習）

<br>

---

<br>

## Part C — 區間語意

### C1 — 半開還是閉

P1 的相鄰兩列是 `[01-01, 03-01)` 和 `[03-01, 06-01)` —— `03-01` 這天用**哪一個價格**？

- 你的 `WHERE` 用 `< valid_to` 還是 `<= valid_to`？
- 兩種寫法對 `2026-03-01` 這天分別給出什麼？
- **如果用閉區間 `<=`，P1 在 03-01 這天會回傳幾行？**（自己測）
- 為什麼 SCD2 的業界慣例是**半開區間** `[from, to)`？

### C2 — `valid_to` 用 NULL 還是 `9999-12-31`

目前用 `NULL` 表示「仍然有效」。

比較兩種做法：

| | `valid_to = NULL` | `valid_to = '9999-12-31'` |
|---|---|---|
| 查詢條件寫起來 | ? | ? |
| 索引效率 | ? | ? |
| 重疊偵測 | ? | ? |
| 語意清晰度 | ? | ? |

**你會選哪一個？**

### C3 — 用 `daterange` 型別

PostgreSQL 有 `daterange`。改寫 schema：

```sql
valid_period daterange NOT NULL
```

- 點查詢怎麼寫？（`@>` 運算子）
- 重疊偵測怎麼寫？（`&&`）
- 「仍然有效」怎麼表示？
- **這樣改之後，B1 的稽核查詢還需要嗎？**

<br>

---

<br>

## Part D — 建立 SCD2

### D1

上游只給你一張**變更記錄檔**（每次改價一列，只有生效日）：

```sql
DROP TABLE IF EXISTS price_changes;
CREATE TABLE price_changes (
    product_id  INT NOT NULL,
    price       NUMERIC(10,2) NOT NULL,
    changed_on  DATE NOT NULL,
    PRIMARY KEY (product_id, changed_on)
);

INSERT INTO price_changes VALUES
(1, 10.00, '2026-01-01'), (1, 12.00, '2026-03-01'), (1, 15.00, '2026-06-01'),
(4, 40.00, '2026-01-01');
```

寫一個查詢，把它轉換成正確的 SCD2 表（產生 `valid_to`）。

**核心技巧**：`LEAD(changed_on)` —— 下一次變更的日期就是這一列的 `valid_to`，最後一列是 NULL。

### D2 — 驗證

寫出驗證查詢，確認 D1 產生的結果：
- 沒有重疊
- 沒有缺口
- 每個商品恰好一列 `valid_to IS NULL`

**用 B1、B2、B3 的稽核查詢直接跑** —— 如果你的稽核寫得夠通用，這一步應該零成本。

### D3 — 增量

明天上游又送來新的變更記錄。

- 你要怎麼更新 SCD2 表？
- 原本 `valid_to IS NULL` 的那一列要怎麼處理？
- **這個 `UPDATE` + `INSERT` 在併發下安全嗎？**（[Phase 6](../../README.md#phase-6dml併發與資料正確性) 的伏筆）

<br>

---

<br>

## 面試官的追問

> 1. 「SCD Type 1 / 2 / 3 / 6 分別是什麼？什麼時候用哪一種？」
>
> 2. 「SCD2 表要怎麼建索引才能讓點查詢快？」
>
> 3. 「如果要查『整個三月每一天的價格』而不是單一天，查詢怎麼寫？」
>
> 4. 「訂單表該存 `product_id` 還是存 SCD2 的代理鍵（surrogate key）？兩種設計的差別？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 重疊偵測（含 NULL 邊界）</summary>

```sql
SELECT a.product_id, a.valid_from AS a_from, a.valid_to AS a_to,
       b.valid_from AS b_from, b.valid_to AS b_to
FROM product_price_scd a
JOIN product_price_scd b
  ON a.product_id = b.product_id
 AND a.valid_from < b.valid_from                                    -- 去重 + 排除自我配對
 AND a.valid_from < COALESCE(b.valid_to, 'infinity'::date)
 AND b.valid_from < COALESCE(a.valid_to, 'infinity'::date);
```

三個重點：
- `COALESCE(valid_to, 'infinity')` —— NULL 代表無限遠，`date` 型別支援 `'infinity'`
- `a.valid_from < b.valid_from` —— [Phase 1-06](../../phase-1-join-dark-side/06-the-self-join-that-counted-twice) 的對稱去重
- 重疊條件 `a.start < b.end AND b.start < a.end` —— [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 推導過

**同一個條件，第三次出現。** 到這裡應該不用想就寫得出來了。

</details>

<details>
<summary>Hint 2 — 缺口偵測</summary>

```sql
SELECT product_id, valid_to AS gap_from, next_from AS gap_to
FROM (
    SELECT product_id, valid_to,
           LEAD(valid_from) OVER (PARTITION BY product_id ORDER BY valid_from) AS next_from
    FROM product_price_scd
) t
WHERE valid_to IS NOT NULL
  AND next_from IS NOT NULL
  AND next_from > valid_to;               -- 下一段的起點晚於這一段的終點 = 缺口
```

`valid_to IS NOT NULL` 排除「目前有效」那一列（它後面本來就沒有東西）。
`next_from IS NOT NULL` 排除最後一列。

**注意 `>` 不是 `>=`**：`next_from = valid_to` 是**首尾相接**（正常），`next_from > valid_to` 才是缺口。

</details>

<details>
<summary>Hint 3 — 為什麼業界用半開區間</summary>

用**閉區間** `[from, to]` 的話，相鄰兩段要寫成：

```
[2026-01-01, 2026-02-28]
[2026-03-01, 2026-05-31]
```

問題：
- 你必須知道「上一段的結束日 = 下一段的開始日 **減一天**」—— 而「減一天」對日期可以，對 `TIMESTAMP` 就變成減一秒？減一微秒？**沒有正確答案**
- 閏年、月底、時區都會咬你
- 相接的判斷變成 `next_from = valid_to + 1`，多一層算術

用**半開區間** `[from, to)`：

```
[2026-01-01, 2026-03-01)
[2026-03-01, 2026-06-01)
```

- 相接就是 `next_from = valid_to`，**完全不用做算術**
- 對 `DATE` 和 `TIMESTAMP` 語意完全一致
- 沒有「重複的邊界日」—— `03-01` 只屬於後面那一段

**這和 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 的會議室、[Phase 2-06](../../phase-2-aggregation-limits/06-histogram-with-empty-buckets) 的 `width_bucket` 是同一個道理：半開區間讓相鄰的東西剛好接上，不重不漏。**

</details>

<details>
<summary>Hint 4 — D1 用 LEAD 建 SCD2</summary>

```sql
SELECT product_id, price,
       changed_on AS valid_from,
       LEAD(changed_on) OVER (PARTITION BY product_id ORDER BY changed_on) AS valid_to
FROM price_changes
ORDER BY product_id, valid_from;
```

**一行 `LEAD` 就完成了。** 下一次變更的日期，正好就是這一段的結束（半開區間）；最後一列的 `LEAD` 是 NULL，正好就是「目前有效」。

**這個結構天生不可能有重疊或缺口** —— 因為每一段的終點就是下一段的起點，由同一個排序決定。

**所以 D2 的驗證應該全部通過**，而 A 部分那些壞資料（P2 的缺口、P3 的重疊）只可能來自「手動 INSERT/UPDATE 維護 SCD2 表」。

**這是 D 部分真正想教的**：與其寫稽核去抓壞資料，不如**用一個結構上不可能出錯的方式產生它**。
和 [Phase 1-02](../../phase-1-join-dark-side/02-price-tier-assignment) Hint 4 的「讓錯誤狀態無法被表達」是同一個原則。

</details>
