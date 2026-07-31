# Phase 4-05 — The Running Balance, Recursive Edition

> **難度**：★★★★★
> **核心技巧**：用遞迴 CTE 表達「逐行狀態機」
> **前置題**：[Phase 3-07. The Running Balance With a Floor](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) —— **先做完那題再來**

<br>

---

<br>

## Interview Context

> *面試官：*「上次你告訴我 window function 做不到這題，而且解釋得不錯。
>
> 現在寫出來。」

<br>

**這一題是 [Phase 3-07](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) 的答案。** 資料完全一樣，方便你對照。

如果你還沒做 3-07，**先回去做** —— 直接看這題你只會學到一個 SQL 模板，不會學到「什麼時候該用它」。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id              INT PRIMARY KEY,
    owner           VARCHAR(30) NOT NULL,
    opening_balance NUMERIC(12,2) NOT NULL
);

CREATE TABLE transactions (
    id          INT PRIMARY KEY,
    account_id  INT NOT NULL REFERENCES accounts(id),
    amount      NUMERIC(12,2) NOT NULL,
    occurred_at TIMESTAMP NOT NULL
);

INSERT INTO accounts (id, owner, opening_balance) VALUES
(1, 'alice', 100.00),
(2, 'bob',    50.00);

INSERT INTO transactions (id, account_id, amount, occurred_at) VALUES
(1, 1,   50.00, '2026-03-01 09:00'),
(2, 1, -200.00, '2026-03-02 09:00'),      -- 超支 → 拒絕
(3, 1,   30.00, '2026-03-03 09:00'),
(4, 1, -100.00, '2026-03-04 09:00'),
(5, 1, -100.00, '2026-03-05 09:00'),      -- 超支 → 拒絕
(6, 1,   20.00, '2026-03-06 09:00'),
(7, 2,  -80.00, '2026-03-01 10:00'),      -- 超支 → 拒絕
(8, 2,   40.00, '2026-03-02 10:00'),
(9, 2,  -60.00, '2026-03-03 10:00');
```

<br>

### 目標輸出

```
 account_id | rn | amount  | outcome  | balance | rejected_so_far
------------+----+---------+----------+---------+-----------------
          1 |  0 |         | opening  |  100.00 |               0
          1 |  1 |   50.00 | applied  |  150.00 |               0
          1 |  2 | -200.00 | REJECTED |  150.00 |               1
          1 |  3 |   30.00 | applied  |  180.00 |               1
          1 |  4 | -100.00 | applied  |   80.00 |               1
          1 |  5 | -100.00 | REJECTED |   80.00 |               2
          1 |  6 |   20.00 | applied  |  100.00 |               2
          2 |  0 |         | opening  |   50.00 |               0
          2 |  1 |  -80.00 | REJECTED |   50.00 |               1
          2 |  2 |   40.00 | applied  |   90.00 |               1
          2 |  3 |  -60.00 | applied  |   30.00 |               1
```

<br>

---

<br>

## Part A — 寫出來

### A1 — 先解決「下一筆是哪一筆」

遞迴要一次前進一筆交易。但 `transactions` 的 `id` 不保證連續、也不保證按帳戶分組。

- 你需要一個「每個帳戶內從 1 開始的連號」。用什麼產生？
- 這一步該放在遞迴 CTE 的**裡面**還是**外面**？為什麼？

### A2 — 非遞迴項

遞迴的起點是**期初餘額**，不是第一筆交易。

寫出非遞迴項，注意輸出 `rn = 0` 的那一行。

> ⚠️ **你一定會踩到型別錯誤。** 兩個都會遇到：
>
> ```
> ERROR:  recursive query "walk" column 2 has type integer in non-recursive term but type bigint overall
> ERROR:  recursive query "walk" column 3 has type numeric(12,2) in non-recursive term but type numeric overall
> ```
>
> 第一個是因為 `ROW_NUMBER()` 回傳 `bigint` 而你寫了 `0`。
> 第二個是因為 `NUMERIC(12,2)` 和運算後的 `NUMERIC` 不同型。
>
> **兩個都要在非遞迴項顯式轉型。** 這是遞迴 CTE 最常見的入門障礙，值得記住。

### A3 — 遞迴項

每一步做三件事：
1. 用**上一步算出的 balance** 判斷這筆會不會超支
2. 決定新的 balance（套用或維持）
3. 記錄 outcome

寫出來，驗證結果和上表完全一致。

### A4 — 加上累計計數

`rejected_so_far` 這一欄：到目前為止被拒絕了幾筆。

它也必須在遞迴裡累加 —— **不能事後用 window function 算**。為什麼？

<br>

---

<br>

## Part B — 對照 3-07

### B1

把 [3-07](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) 的天真版和這一題的正解**放在同一個查詢**裡並排：

```
 rn | amount  | naive_balance | true_balance | outcome
----+---------+---------------+--------------+----------
  1 |   50.00 |        150.00 |       150.00 | applied
  2 | -200.00 |        -50.00 |       150.00 | REJECTED
  3 |   30.00 |        -20.00 |       180.00 | applied
  4 | -100.00 |       -120.00 |        80.00 | applied
  5 | -100.00 |       -220.00 |        80.00 | REJECTED
  6 |   20.00 |       -200.00 |       100.00 | applied
```

### B2

回答：
- 兩者從第幾筆開始分歧？
- 分歧之後還會再收斂嗎？為什麼？
- alice 的最終餘額：天真版 −200.00，正解 100.00。**差了 300 —— 這 300 是怎麼來的？**

### B3 — 回填你的 3-07 答案

回到 [3-07](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) 的 `answer.sql`，把 Part C1 那個「卡住的地方」補完。

<br>

---

<br>

## Part C — 代價

### C1 — 為什麼慢

遞迴 CTE 一次只能前進**一輪**。

- alice 有 6 筆交易 → 遞迴幾輪？
- 如果一個帳戶有 100 萬筆交易 → 幾輪？
- **不同帳戶之間可以平行嗎？** 遞迴 CTE 會平行處理它們嗎？（跑 `EXPLAIN` 確認）

### C2 — 實測

產生一批測試資料，測量遞迴 CTE 的實際成本：

```sql
-- 1 個帳戶，5000 筆交易
INSERT INTO accounts VALUES (3, 'stress', 1000.00);
INSERT INTO transactions (id, account_id, amount, occurred_at)
SELECT 1000 + g, 3,
       (random() * 400 - 200)::NUMERIC(12,2),
       TIMESTAMP '2026-01-01' + (g || ' minutes')::INTERVAL
FROM generate_series(1, 5000) g;
```

- 對這個帳戶跑你的遞迴查詢，記錄執行時間
- 對照 `SUM() OVER` 的天真版執行時間
- **差幾倍？**
- 把交易數加到 50000 再測一次 —— 時間是線性成長還是更差？

### C3 — 替代方案

回答：

- 用 PL/pgSQL 寫一個迴圈函數，會比遞迴 CTE 快嗎？為什麼？
- 如果這是每晚的批次作業，你會用 SQL 做嗎？
- **真實的銀行系統怎麼處理餘額？** 餘額是算出來的還是存起來的？
- 如果存起來，`UPDATE accounts SET balance = balance - 300 WHERE id = 1` 在高併發下有什麼問題？

> 最後一題的答案在 [Phase 6](../../README.md#phase-6dml併發與資料正確性)。
> **Phase 3 說 window 做不到，Phase 4 說遞迴做得到，Phase 6 會說：兩個真實系統都不用。**
> 這條線是故意鋪的 —— 面試時能把三個層次講完整，你就贏了。

<br>

---

<br>

## 面試官的追問

> 1. 「如果規則改成『超支就扣到剛好 0』（部分成交），還需要遞迴嗎？」
>
> 2. 「如果要支援『事後撤銷某一筆交易然後重算』，你的設計會怎麼變？」
>
> 3. 「遞迴 CTE 的中間結果會佔多少記憶體？`work_mem` 不夠時會發生什麼？」
>
> 4. 「這個查詢能不能寫成增量的 —— 每天只算當天新增的交易？需要什麼前提？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 完整骨架</summary>

```sql
WITH RECURSIVE ord AS (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY occurred_at) AS rn
    FROM transactions t
),
walk AS (
    SELECT a.id                    AS account_id,
           0::bigint               AS rn,            -- ← 對齊 ROW_NUMBER 的 bigint
           a.opening_balance::numeric AS balance,    -- ← 拿掉 (12,2) 的精度限制
           NULL::numeric           AS amount,
           'opening'::text         AS outcome,
           0                       AS rejected_so_far
    FROM accounts a
    UNION ALL
    SELECT w.account_id,
           o.rn,
           CASE WHEN w.balance + o.amount < 0 THEN w.balance
                ELSE w.balance + o.amount END,
           o.amount,
           CASE WHEN w.balance + o.amount < 0 THEN 'REJECTED'
                ELSE 'applied' END,
           w.rejected_so_far + CASE WHEN w.balance + o.amount < 0 THEN 1 ELSE 0 END
    FROM walk w
    JOIN ord o ON o.account_id = w.account_id
              AND o.rn = w.rn + 1                    -- ← 一次前進一筆
)
SELECT account_id, rn, amount, outcome, balance, rejected_so_far
FROM walk
ORDER BY account_id, rn;
```

**`o.rn = w.rn + 1` 是整個查詢的心臟** —— 它保證一次只前進一步，而且下一步用得到上一步的 `balance`。

</details>

<details>
<summary>Hint 2 — 為什麼 rn 要在遞迴外面算</summary>

先說一個容易誤會的事：**PostgreSQL 其實「允許」你在遞迴項裡寫 window function** —— 不會報錯。

但它幾乎一定是錯的。因為遞迴項每一輪的輸入**只有上一輪產生的那幾行**（work table），不是整張表。所以：

```sql
-- 這段不會報錯，但會無限迴圈
WITH RECURSIVE w AS (
    SELECT 1::bigint AS n
    UNION ALL
    SELECT ROW_NUMBER() OVER () FROM w WHERE n < 3
) SELECT * FROM w;
```

每一輪 work table 只有 1 行，所以 `ROW_NUMBER() OVER ()` 永遠回傳 **1**，`n` 永遠是 1，`n < 3` 永遠成立 → **跑不完**。

**這比報錯更危險** —— 報錯你馬上知道，無限迴圈你要等到生產環境才發現。

所以 `ROW_NUMBER()` 必須在一個獨立的 CTE（`ord`）裡對**整張表**先算好，遞迴只負責走訪。

**真正會報錯的限制**（各自試一次記住錯誤訊息）：

| 限制 | 錯誤訊息 |
|------|---------|
| 聚合函數 | `aggregate functions are not allowed in a recursive query's recursive term` |
| `ORDER BY` / `LIMIT` | `ORDER BY in a recursive query is not implemented` |
| 遞迴項在 outer join 被連接的那一側 | `recursive reference to query "w" must not appear within an outer join` |
| 遞迴項引用自己超過一次 | `recursive reference to query "t" must not appear more than once` |

**心法**：不報錯 ≠ 可以用。遞迴項裡任何「需要看到整個資料集」的運算，語意上都是錯的 —— 它只看得到上一輪的那幾行。

</details>

<details>
<summary>Hint 3 — 為什麼 rejected_so_far 不能事後算</summary>

看起來可以：拿到結果之後 `SUM(CASE WHEN outcome='REJECTED' THEN 1 ELSE 0 END) OVER (...)`。

**這一題確實可以** —— 因為 `outcome` 已經是遞迴算出來的結果，事後累加只是統計。

但如果規則變成「**連續被拒絕 3 次就凍結帳戶**」，那 `rejected_so_far` 就會回頭影響後續的判斷 —— 它成為狀態的一部分，必須在遞迴裡維護。

**判準**：這個累計值**會不會影響後續的決策**？
- 不會 → 事後算（比較快，遞迴的每一輪更輕）
- 會 → 必須放進遞迴的狀態裡

A4 想問的就是這個分辨能力。

</details>

<details>
<summary>Hint 4 — B2 的 300 從哪來</summary>

天真版把兩筆被拒絕的交易也算進去了：

- 交易 #2：−200.00（實際被拒絕）
- 交易 #5：−100.00（實際被拒絕）

合計 −300.00。

天真版最終餘額 = 100（期初）+ 50 − 200 + 30 − 100 − 100 + 20 = **−200**
正解最終餘額 = −200 + 300 = **100** ✓

**這個 300 就是「被拒絕的交易總額」** —— 也是為什麼你不能事後修正：你必須先知道哪些被拒絕，而那取決於當下的餘額，而餘額又取決於之前哪些被拒絕。循環相依，只能逐步解開。

</details>
