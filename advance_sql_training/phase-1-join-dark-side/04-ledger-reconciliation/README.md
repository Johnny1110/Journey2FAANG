# Phase 1-04 — Ledger Reconciliation

> **難度**：★★★★☆
> **核心技巧**：FULL OUTER JOIN、`IS DISTINCT FROM`、NULL-safe 比較、`COALESCE` 補鍵
> **對應基礎題**：[LC 175. Combine Two Tables](../../../sql_training/combine_2_tables)（基礎 LEFT JOIN）

<br>

---

<br>

## Interview Context

> *面試官：*「每天早上財務都要做**對帳**：我們自己的帳本 vs 銀行的對帳單。三種情況要抓出來：
>
> 1. 我們有記帳、銀行沒收到 → **可能是漏付**
> 2. 銀行有紀錄、我們沒記帳 → **可能是被盜刷**
> 3. 兩邊都有但**金額不同** → **一定有問題**
>
> 財務現在是用 Excel 手動比對，一天要花兩小時。幫我用一個查詢解決。
>
> 對了，銀行的 API 偶爾會回傳**金額欄位是 NULL** 的紀錄 — 那代表交易還在清算中。」

<br>

最後那句話是這題的殺著。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS internal_ledger;
DROP TABLE IF EXISTS bank_statement;

CREATE TABLE internal_ledger (
    txn_ref   VARCHAR(20) PRIMARY KEY,
    amount    NUMERIC(12,2),
    booked_on DATE NOT NULL
);

CREATE TABLE bank_statement (
    txn_ref    VARCHAR(20) PRIMARY KEY,
    amount     NUMERIC(12,2),      -- ← 可為 NULL：清算中
    settled_on DATE NOT NULL
);

INSERT INTO internal_ledger (txn_ref, amount, booked_on) VALUES
('TXN-001', 1500.00, '2026-03-01'),
('TXN-002',  890.50, '2026-03-01'),
('TXN-003', 2300.00, '2026-03-02'),
('TXN-004',   45.00, '2026-03-02'),   -- 銀行沒有
('TXN-005', 1200.00, '2026-03-03'),
('TXN-007',    0.00, '2026-03-04');   -- 金額 0，銀行那邊是 NULL

INSERT INTO bank_statement (txn_ref, amount, settled_on) VALUES
('TXN-001', 1500.00, '2026-03-01'),
('TXN-002',  890.50, '2026-03-02'),   -- 金額對，但結算日晚一天
('TXN-003', 2300.50, '2026-03-02'),   -- 金額差 0.50
('TXN-005', 1200.00, '2026-03-03'),
('TXN-006',  675.25, '2026-03-03'),   -- 我們沒記帳
('TXN-007',    NULL, '2026-03-04');   -- 清算中
```

<br>

### 正確答案應該是

```
+---------+-----------------+-----------------+-------------+------------------+
| txn_ref | internal_amount | bank_amount     | diff        | status           |
+---------+-----------------+-----------------+-------------+------------------+
| TXN-001 | 1500.00         | 1500.00         | 0.00        | MATCHED          |
| TXN-002 | 890.50          | 890.50          | 0.00        | MATCHED          |
| TXN-003 | 2300.00         | 2300.50         | -0.50       | AMOUNT_MISMATCH  |
| TXN-004 | 45.00           | (NULL)          | (NULL)      | MISSING_IN_BANK  |
| TXN-005 | 1200.00         | 1200.00         | 0.00        | MATCHED          |
| TXN-006 | (NULL)          | 675.25          | (NULL)      | MISSING_IN_LEDGER|
| TXN-007 | 0.00            | (NULL)          | (NULL)      | AMOUNT_MISMATCH  |
+---------+-----------------+-----------------+-------------+------------------+
```

<br>

> **盯著 TXN-007 看三秒鐘。** 我們記 `0.00`，銀行是 `NULL`。這**不是** MATCHED。但大多數人寫出來的查詢會把它判成 MATCHED —— 而且**不會報錯**，就這樣安靜地混進財務報表裡。

<br>

---

<br>

## Your Task

在 `answer.sql` 中完成：

### Q1 — 為什麼一定要 FULL OUTER JOIN

用 `LEFT JOIN` 會漏掉哪些情況？用 `RIGHT JOIN` 呢？如果不用 `FULL OUTER JOIN`，你要怎麼組合出同樣結果？（提示：`UNION`）— 寫出來，然後說明為什麼 `FULL OUTER JOIN` 更好。

### Q2 — 寫出對帳查詢

輸出上面的完整結果表。三個必須處理的點：

- **`txn_ref` 欄位怎麼來？** FULL OUTER JOIN 之後，`a.txn_ref` 和 `b.txn_ref` 各自都可能是 NULL。
- **怎麼分辨「這一邊沒資料」和「這一邊有資料但值是 NULL」？**
- **`status` 的判斷順序**很重要，想清楚 `CASE WHEN` 的分支順序。

### Q3 — 抓出 TXN-007

先用天真的寫法 `a.amount <> b.amount` 判斷金額不符，看看 TXN-007 被判成什麼。

然後說明：
- `0.00 <> NULL` 求值是什麼？
- `WHERE` / `CASE WHEN` 對這個結果怎麼處理？
- 用 `IS DISTINCT FROM` 重寫。它和 `<>` 的真值表差在哪？

### Q4 — `IS DISTINCT FROM` 完整真值表

填完這張表：

| a | b | `a = b` | `a <> b` | `a IS NOT DISTINCT FROM b` | `a IS DISTINCT FROM b` |
|---|---|---------|----------|---------------------------|------------------------|
| 1 | 1 | ? | ? | ? | ? |
| 1 | 2 | ? | ? | ? | ? |
| 1 | NULL | ? | ? | ? | ? |
| NULL | NULL | ? | ? | ? | ? |

**這張表是這一題的精華。** 記熟它，它會在你未來每一次寫對帳、去重、diff 的時候救你。

### Q5 — 商業判斷

TXN-002 兩邊金額相同但**結算日差一天**。你的查詢判它 MATCHED。

- 這是對的嗎？
- 面試官現在說：「差超過 2 天要標成 `SETTLEMENT_DELAY`。」改你的查詢。
- 如果財務說「金額差 0.01 以內算浮點誤差，可以接受」，怎麼改？這樣改有什麼風險？

<br>

---

<br>

## 面試官的追問

> 1. 「`COALESCE(a.txn_ref, b.txn_ref)` — 如果 `txn_ref` 本身可能是 NULL 呢？你的查詢會怎樣？」
>
> 2. 「FULL OUTER JOIN 的執行計畫是什麼？可以用 Hash Join 嗎？可以用 Nested Loop 嗎？」
>
> 3. 「兩張表各 1000 萬筆，這個對帳查詢要跑多久？你會怎麼優化？如果只需要對『昨天』的帳呢？」
>
> 4. 「如果 `txn_ref` 在銀行那邊有**重複**（同一筆交易被回報兩次），你的查詢會發生什麼事？怎麼防？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 分辨「沒有這一行」vs「有這一行但值是 NULL」</summary>

FULL OUTER JOIN 之後，`b.amount IS NULL` 有**兩種可能**：

1. 銀行根本沒有這筆交易（沒有匹配的行）
2. 銀行有這筆交易，但 `amount` 欄位是 NULL

要分辨，看**主鍵**：`b.txn_ref IS NULL` 才代表「這一邊沒有這行」。因為 `txn_ref` 是 PRIMARY KEY，本身不可能是 NULL — 它是 NULL 就一定是 JOIN 補出來的。

這就是為什麼 `CASE WHEN` 的分支順序要先判斷 `b.txn_ref IS NULL`，再判斷金額。

</details>

<details>
<summary>Hint 2 — CASE WHEN 的分支順序</summary>

```sql
CASE
    WHEN b.txn_ref IS NULL THEN 'MISSING_IN_BANK'
    WHEN a.txn_ref IS NULL THEN 'MISSING_IN_LEDGER'
    WHEN a.amount IS DISTINCT FROM b.amount THEN 'AMOUNT_MISMATCH'
    ELSE 'MATCHED'
END
```

`CASE WHEN` 是**由上而下第一個 TRUE 就返回**。順序錯了結果就錯。

</details>

<details>
<summary>Hint 3 — IS DISTINCT FROM 的心智模型</summary>

把 `IS DISTINCT FROM` 想成「**把 NULL 當成一個普通的值來比較**」：

- `NULL IS DISTINCT FROM NULL` → FALSE（兩個 NULL「相同」）
- `1 IS DISTINCT FROM NULL` → TRUE（不同）
- `1 IS DISTINCT FROM 1` → FALSE

它**永遠回傳 TRUE 或 FALSE，絕不回傳 UNKNOWN**。這就是它的價值 — 你的 `CASE WHEN` 不會再有分支被 UNKNOWN 靜靜跳過。

</details>

<details>
<summary>Hint 4 — 骨架</summary>

```sql
SELECT
    COALESCE(a.txn_ref, b.txn_ref) AS txn_ref,
    a.amount AS internal_amount,
    b.amount AS bank_amount,
    a.amount - b.amount AS diff,
    CASE ... END AS status
FROM internal_ledger a
FULL OUTER JOIN bank_statement b ON a.txn_ref = b.txn_ref
ORDER BY 1;
```

`diff` 欄位在有 NULL 時會是 NULL — 這是預期行為（未知金額無法算差額），還是你想 `COALESCE` 成 0？想清楚再決定，並在註解裡說明你的選擇。

</details>
