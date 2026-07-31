# Phase 6-04 — The Lost Update

> **難度**：★★★★★
> **核心技巧**：Lost Update、隔離級別、原子更新、樂觀鎖 vs 悲觀鎖
> **對應基礎題**：[LC 627. Swap Salary](../../../sql_training/swap_salary)（你當初的 `UPDATE` 是單執行緒的）

<br>

---

<br>

## Interview Context

> *面試官：*「這是我們錢包服務的提款程式碼：
>
> ```sql
> SELECT balance FROM accounts WHERE id = 1;       -- 讀到 1000
> -- 應用層計算 1000 - 300 = 700
> UPDATE accounts SET balance = 700 WHERE id = 1;  -- 寫回
> ```
>
> 昨天有個使用者用兩支手機同時提款 300，各拿到 300 塊，**但帳戶只被扣了 300**。
>
> 白拿 300 塊。告訴我為什麼，然後給我三種修法。」

<br>

**這是併發控制的第一課，也是面試最高頻的題目。** 這一題的三種修法你要能閉著眼睛寫出來，而且講得出各自該用在什麼場景。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id      INT PRIMARY KEY,
    owner   TEXT NOT NULL,
    balance NUMERIC(12,2) NOT NULL,
    version INT NOT NULL DEFAULT 0       -- 樂觀鎖用
);

INSERT INTO accounts (id, owner, balance) VALUES
(1, 'alice', 1000.00),
(2, 'bob',   1000.00);
```

<br>

---

<br>

## Part A — 重現 Lost Update

### A1

兩個 session 同時執行「讀-改-寫」：

```sql
-- Session A 和 Session B 同時跑
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE id = 1;        -- 兩邊都讀到 1000.00
SELECT pg_sleep(0.4);
UPDATE accounts SET balance = (SELECT balance FROM accounts WHERE id = 1) - 300
 WHERE id = 1;
COMMIT;
```

**實測結果**：

```
A read 1000.00
B read 1000.00
final balance = 700.00        ← 應該是 400.00
```

### A2 — 診斷

回答：
- 兩個交易各自「以為」自己做了什麼？
- 為什麼最後只扣了 300？**哪一次更新被弄丟了？**
- 畫出時間軸，標出兩個交易的讀寫時點。
- 這個現象的正式名稱是什麼？

### A3 — 為什麼 READ COMMITTED 不擋

回答：
- READ COMMITTED 保證什麼？
- 它**不**保證什麼？
- 「A 的 `UPDATE` 覆蓋掉 B 的 `UPDATE`」有違反 READ COMMITTED 的定義嗎？

<br>

---

<br>

## Part B — 三種修法

### B1 — 修法一：原子更新（最簡單，優先考慮）

```sql
UPDATE accounts SET balance = balance - 300 WHERE id = 1;
```

兩個 session 同時跑，**實測結果：`final balance = 400.00`** ✓

回答：
- 為什麼這樣就對了？資料庫做了什麼？
- 第二個 `UPDATE` 讀到的 `balance` 是多少？它從哪讀到的？
- **這個修法的限制是什麼？**（提示：如果要先檢查「餘額夠不夠」再決定扣多少呢？）

### B2 — 修法二：樂觀鎖（version 欄位）

```sql
-- 讀
SELECT balance, version FROM accounts WHERE id = 1;     -- balance=1000, version=0

-- 寫（帶上讀到的 version）
UPDATE accounts SET balance = 700, version = version + 1
WHERE id = 1 AND version = 0;                           -- ← 關鍵
```

回答：
- 如果另一個交易先改了，`version` 已經變成 1，這個 `UPDATE` 會怎樣？
- 怎麼知道更新失敗了？（提示：`UPDATE` 影響的列數）
- 應用層要怎麼處理？
- **這個模式叫什麼？為什麼叫「樂觀」？**

### B3 — 修法三：悲觀鎖（`SELECT FOR UPDATE`）

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;   -- 鎖住這一列
-- 應用層計算
UPDATE accounts SET balance = 700 WHERE id = 1;
COMMIT;
```

兩個 session 同時跑，回答：
- Session B 停在哪一行？
- B 等到之後，它 `SELECT` 讀到的 `balance` 是多少？**為什麼不是 1000？**
- **這個修法為什麼叫「悲觀」？**

### B4 — 三者對照

| | 原子更新 | 樂觀鎖 | 悲觀鎖 |
|---|---|---|---|
| 需要額外欄位嗎 | ? | ? | ? |
| 會阻塞其他交易嗎 | ? | ? | ? |
| 需要重試邏輯嗎 | ? | ? | ? |
| 能不能在「讀」和「寫」之間做複雜計算 | ? | ? | ? |
| 衝突頻繁時的表現 | ? | ? | ? |
| 衝突罕見時的表現 | ? | ? | ? |
| **你什麼時候選它** | ? | ? | ? |

<br>

---

<br>

## Part C — 隔離級別

### C1 — REPEATABLE READ

把 A1 改成 `BEGIN ISOLATION LEVEL REPEATABLE READ`，用**原子更新**（`balance = balance - 300`）重跑。

**實測結果**：

```
A read 1000.00
B read 1000.00
ERROR:  could not serialize access due to concurrent update
final balance = 700.00
```

回答：
- 只有一個交易成功了，另一個**報錯**。
- **這比 READ COMMITTED 的靜默錯誤好還是壞？**
- 應用層拿到這個錯誤該做什麼？
- 為什麼 REPEATABLE READ 下連 `balance = balance - 300` 都會失敗？（READ COMMITTED 下它是安全的）

### C2 — 三個隔離級別的行為

用同樣的「讀-改-寫」測試，填完這張表：

| 隔離級別 | 結果 | 有沒有錯誤 | 最終餘額 |
|---------|------|-----------|---------|
| READ COMMITTED | ? | ? | ? |
| REPEATABLE READ | ? | ? | ? |
| SERIALIZABLE | ? | ? | ? |

回答：PostgreSQL 的 READ UNCOMMITTED 是什麼行為？（**查文件，答案可能出乎意料**）

### C3 — 該用哪個隔離級別

回答：
- 為什麼 PostgreSQL 的預設是 READ COMMITTED 而不是更嚴格的？
- 把整個應用切成 SERIALIZABLE 有什麼代價？
- **「用更高的隔離級別」vs「用更好的 SQL 寫法」，你優先選哪個？為什麼？**

<br>

---

<br>

## Part D — 真實系統

### D1 — 餘額該存還是該算

回顧 [Phase 3-07](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) → [Phase 4-05](../../phase-4-recursive-cte/05-running-balance-recursive-edition) → 這一題。

回答：
- Phase 3 說 window function 算不出「有下限的餘額」
- Phase 4 說遞迴 CTE 算得出來，但每次都要從頭走一遍
- **這一題說：真實系統把餘額「存」在欄位裡。**

三種做法的取捨是什麼？填完：

| | 每次從交易明細算 | 存在 `accounts.balance` | 兩者都有 |
|---|---|---|---|
| 讀取速度 | ? | ? | ? |
| 併發寫入的難度 | ? | ? | ? |
| 資料能不能對不上 | ? | ? | ? |
| 稽核與追溯 | ? | ? | ? |

### D2 — 對帳

如果同時存 `accounts.balance` **和**交易明細，兩者可能會對不上。

- 寫一個對帳查詢：比對 `accounts.balance` 和「交易明細的總和 + 期初」
  （這是 [Phase 1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) 的技巧！）
- 多久跑一次？
- 對不上的時候，**相信哪一個？**

### D3 — 完整設計

寫出你會怎麼設計一個「不會白送錢」的提款流程，包含：

- schema（含約束）
- 提款的完整 SQL（含餘額不足的處理）
- 併發保護機制
- 對帳機制

<br>

---

<br>

## 面試官的追問

> 1. 「Lost Update、Dirty Read、Non-repeatable Read、Phantom Read 分別是什麼？各個隔離級別擋掉哪些？」
>
> 2. 「PostgreSQL 的 MVCC 是怎麼運作的？為什麼 `UPDATE` 實際上是 `DELETE` + `INSERT`？」
>
> 3. 「樂觀鎖的 `version` 欄位可以用 `updated_at` 時間戳代替嗎？有什麼風險？」
>
> 4. 「如果同一個帳戶每秒有 1000 筆交易，三種修法哪一種撐得住？還有別的辦法嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — Lost Update 的時間軸</summary>

```
時間 →
A:  BEGIN ── SELECT(1000) ──────────── UPDATE(SET 700) ── COMMIT
B:      BEGIN ── SELECT(1000) ──────────── UPDATE(SET 700) ── COMMIT
                    ↑                            ↑
             兩邊都讀到 1000           兩邊都寫入 700，後者覆蓋前者
```

A 以為：1000 − 300 = 700 ✓
B 以為：1000 − 300 = 700 ✓
真實：兩人各拿 300（共 600），但帳戶只少了 300。

**這沒有違反 READ COMMITTED**。READ COMMITTED 只保證「不會讀到未提交的資料」，它**完全不保證**「你讀到的值在你寫回去之前沒被別人改過」。

正式名稱：**Lost Update（更新遺失）**。

</details>

<details>
<summary>Hint 2 — 為什麼原子更新有效</summary>

```sql
UPDATE accounts SET balance = balance - 300 WHERE id = 1;
```

`balance - 300` 是**在資料庫內部、持有該列的行鎖時**計算的。

執行順序：
1. A 的 `UPDATE` 取得 id=1 的行鎖，讀到 1000，寫入 700，提交
2. B 的 `UPDATE` 想取得同一個行鎖 → **等待**
3. A 提交後，B 拿到鎖，**重新讀取**該列（READ COMMITTED 下 `UPDATE` 會重讀最新版本）→ 讀到 **700** → 寫入 400 ✓

**關鍵：讀和寫在同一個語句、同一個鎖的保護下完成。** 應用層從來沒有機會拿著過期的值。

**限制**：只適用於「新值可以由舊值直接算出」的情況。如果要先判斷「餘額夠不夠」再決定行為（例如不足就拒絕並記錄失敗原因），就要：

```sql
UPDATE accounts SET balance = balance - 300
WHERE id = 1 AND balance >= 300              -- ← 把條件也放進 UPDATE
RETURNING balance;
```

回傳 0 列 = 餘額不足。**把判斷推進 `WHERE` 裡**，就還是原子的。

（這正是 [Phase 3-07](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) 那個「餘額不得為負」規則在真實系統的實作方式。）

</details>

<details>
<summary>Hint 3 — 為什麼 REPEATABLE READ 下原子更新也會失敗</summary>

READ COMMITTED 下，`UPDATE` 遇到被其他交易鎖住的列時，會等待、然後**重讀最新版本**再套用條件。

REPEATABLE READ 下，交易看到的是**交易開始時的快照**。當它發現要更新的列在快照之後被別的交易改過了，它**不能**默默用新版本（那會破壞可重複讀的保證），也不能用舊版本（那會覆蓋別人的修改）。

**唯一的選擇是放棄**：

```
ERROR:  could not serialize access due to concurrent update
```

**這比 READ COMMITTED 的靜默覆蓋好** —— 你拿到一個明確的錯誤，可以重試。

**但代價是你必須寫重試邏輯**。所有用 REPEATABLE READ 或 SERIALIZABLE 的應用，都必須有「捕捉序列化失敗並重試整個交易」的機制。沒有這個機制就切高隔離級別，只是把靜默錯誤換成了使用者看到的 500 錯誤。

</details>

<details>
<summary>Hint 4 — 三種修法怎麼選</summary>

| | 原子更新 | 樂觀鎖 | 悲觀鎖 |
|---|---|---|---|
| 額外欄位 | 不用 | 要 `version` | 不用 |
| 阻塞別人 | 短暫（語句層級） | **不阻塞** | **會，整個交易期間** |
| 需要重試 | 不用 | **要** | 不用 |
| 讀寫間能做複雜計算 | **不能** | 能 | 能 |
| 衝突頻繁時 | 好 | 差（一直重試） | 好（排隊但穩定） |
| 衝突罕見時 | 好 | **最好** | 浪費 |

**選擇順序**：

1. **能用原子更新就用原子更新** —— 最簡單、最快、不用重試。八成的情況都適用（含把條件塞進 `WHERE` 的變形）。
2. **需要在讀寫之間做應用層計算、且衝突罕見** → 樂觀鎖。典型場景：後台編輯表單（兩個人同時編輯同一筆資料的機率很低）。
3. **衝突頻繁、或必須保證一定成功不能重試** → 悲觀鎖。典型場景：熱門商品的庫存扣減、[6-02](../02-the-job-queue-that-double-processed) 的工作佇列。

**面試時的標準回答**：「我會先看能不能寫成原子更新。如果一定要在應用層計算，我會問這個資源的衝突頻率 —— 罕見就用樂觀鎖配重試，頻繁就用 `SELECT FOR UPDATE`。」

</details>
