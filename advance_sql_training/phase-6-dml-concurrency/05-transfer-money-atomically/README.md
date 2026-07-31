# Phase 6-05 — Transfer Money Atomically

> **難度**：★★★★☆
> **核心技巧**：交易原子性、**死鎖**、鎖順序、`FOR UPDATE` 的正確用法
> **對應基礎題**：[練習題（自設）INSERT INTO SELECT 報表](../../../sql_training/insert_into_select_report)（你當初的多語句 DML）

<br>

---

<br>

## Interview Context

> *面試官：*「轉帳：從 A 扣錢、給 B 加錢。看起來是最簡單的交易範例。
>
> 我們的系統上線三個月都很正常，直到上禮拜開始出現大量 `deadlock detected`。
>
> 查了日誌，發現都是**互相轉帳**的時候發生的 —— A 轉給 B 的同時 B 也在轉給 A。
>
> 為什麼？怎麼修？」

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS transfers;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id      INT PRIMARY KEY,
    owner   TEXT NOT NULL,
    balance NUMERIC(12,2) NOT NULL CHECK (balance >= 0)   -- ← 注意這個約束
);

CREATE TABLE transfers (
    id          SERIAL PRIMARY KEY,
    from_id     INT NOT NULL REFERENCES accounts(id),
    to_id       INT NOT NULL REFERENCES accounts(id),
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    occurred_at TIMESTAMP NOT NULL DEFAULT now(),
    CHECK (from_id <> to_id)
);

INSERT INTO accounts (id, owner, balance) VALUES
(1, 'alice', 1000.00),
(2, 'bob',   1000.00),
(3, 'carol', 1000.00);
```

<br>

---

<br>

## Part A — 原子性基礎

### A1

寫出「從帳戶 1 轉 100 到帳戶 2」的完整交易，包含：
- 扣款
- 入帳
- 寫入 `transfers` 紀錄

### A2 — 為什麼要交易

回答：
- 如果扣款成功但入帳失敗（例如帳戶 2 不存在），沒有交易會怎樣？
- 在你的 SQL 中間插入一個會失敗的語句測試一次，確認 `ROLLBACK` 後餘額沒變。
- **`CHECK (balance >= 0)` 在這裡扮演什麼角色？** 餘額不足時會發生什麼？

### A3 — 餘額不足

帳戶 1 只有 1000，嘗試轉 2000。

- `CHECK` 約束會擋下來嗎？錯誤訊息是什麼？
- **靠 `CHECK` 擋和在應用層先檢查，哪個好？**
- 更好的寫法是把條件放進 `UPDATE`（[6-04](../04-the-lost-update) Hint 2 的技巧）：

```sql
UPDATE accounts SET balance = balance - 2000 WHERE id = 1 AND balance >= 2000;
```

回傳 0 列時要怎麼處理？**怎麼在一個交易裡優雅地中止？**

<br>

---

<br>

## Part B — 死鎖

### B1 — 重現

兩個 session 同時互轉：

```sql
-- Session A：1 → 2
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
SELECT pg_sleep(0.5);
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;

-- Session B：2 → 1（同時執行）
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 2;
SELECT pg_sleep(0.5);
UPDATE accounts SET balance = balance + 100 WHERE id = 1;
COMMIT;
```

**實測結果**：

```
ERROR:  deadlock detected
DETAIL:  Process 417884 waits for ShareLock on transaction 801; blocked by process 417883.
transfer 1->2 committed
```

### B2 — 診斷

畫出鎖的取得順序：

| 時間 | Session A | Session B |
|------|-----------|-----------|
| t1 | 鎖住 ? | |
| t2 | | 鎖住 ? |
| t3 | 想要 ? → **等待** | |
| t4 | | 想要 ? → **等待** |

回答：
- 為什麼會形成循環等待？
- PostgreSQL 怎麼發現死鎖的？（提示：`deadlock_timeout`）
- 誰被犧牲了？PostgreSQL 怎麼決定犧牲哪一個？
- **被犧牲的那個交易，資料有損壞嗎？**

### B3 — 修法：固定鎖順序

```sql
BEGIN;
SELECT id FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;   -- ← 先按固定順序鎖
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

**實測結果**：兩個方向的轉帳**都成功提交**，沒有死鎖。

回答：
- 為什麼「先按 id 排序鎖住兩列」能消除死鎖？
- `ORDER BY id` 裡的 `id` 換成別的欄位可以嗎？**排序依據需要滿足什麼條件？**
- 如果一次要轉帳給 5 個人（一對多），這個技巧還適用嗎？

### B4 — 其他修法

除了固定鎖順序，還有哪些方式可以減少或處理死鎖？各自的取捨？

- 縮短交易長度
- 應用層重試
- 降低隔離級別
- `lock_timeout` / `NOWAIT`
- 用單一語句完成（`UPDATE ... FROM (VALUES ...)`）

**寫出「應用層重試」的完整邏輯** —— 包含重試幾次、要不要退避（backoff）。

<br>

---

<br>

## Part C — 完整實作

### C1

寫出一個**生產等級**的轉帳交易，滿足：

- 原子性（全成功或全失敗）
- 無死鎖（固定鎖順序）
- 餘額不足時明確中止
- 寫入 `transfers` 稽核紀錄
- 不會 Lost Update

### C2 — 包成函數

把 C1 包成 PL/pgSQL 函數：

```sql
CREATE OR REPLACE FUNCTION transfer(p_from INT, p_to INT, p_amount NUMERIC)
RETURNS ... AS $$ ... $$ LANGUAGE plpgsql;
```

回答：
- 函數裡要不要寫 `BEGIN` / `COMMIT`？為什麼？
- 餘額不足時用 `RAISE EXCEPTION` 還是回傳錯誤碼？各自的取捨？
- **函數會自動處理死鎖嗎？**

### C3 — 測試

寫出你會怎麼測試這個轉帳函數：

- 正常轉帳
- 餘額不足
- 轉給自己
- 併發互轉（死鎖情境）
- **不變式檢查**：所有帳戶餘額總和在任何時候都應該不變。寫出這個檢查查詢。

> **最後那個不變式是最有價值的測試。** 不管併發多亂，`SUM(balance)` 必須恆定 —— 這是轉帳系統唯一真正重要的正確性條件。

<br>

---

<br>

## Part D — 規模

### D1 — 熱點帳戶

有一個「平台手續費帳戶」，**每一筆交易都要往它加錢**。

- 這個帳戶會發生什麼事？
- 固定鎖順序能解決嗎？
- **有什麼辦法讓熱點帳戶不成為瓶頸？**
  （提示：想想能不能把一個帳戶拆成 N 個「桶」）

### D2 — 分散式

如果帳戶分散在不同的資料庫分片上，轉帳要怎麼做？

- 兩階段提交（2PC）是什麼？代價？
- Saga pattern 是什麼？它放棄了什麼？
- **為什麼真實的銀行系統其實不用「同步轉帳」？**

<br>

---

<br>

## 面試官的追問

> 1. 「`deadlock_timeout` 預設是多少？調小或調大各有什麼影響？」
>
> 2. 「死鎖和鎖等待逾時（lock timeout）差在哪？」
>
> 3. 「怎麼在正式環境監控死鎖？要看哪些系統表？」
>
> 4. 「`UPDATE accounts SET balance = balance - 100 WHERE id = 1` 這一句會取得什麼鎖？行鎖還是表鎖？什麼模式？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 死鎖的循環等待</summary>

| 時間 | Session A（1→2） | Session B（2→1） |
|------|-----------------|-----------------|
| t1 | `UPDATE id=1` → **取得 row 1 的鎖** | |
| t2 | | `UPDATE id=2` → **取得 row 2 的鎖** |
| t3 | `UPDATE id=2` → 想要 row 2 → **等 B** | |
| t4 | | `UPDATE id=1` → 想要 row 1 → **等 A** |

**循環**：A 等 B，B 等 A → 永遠不會結束。

PostgreSQL 的每個等待中的行程，在等超過 `deadlock_timeout`（預設 **1s**）之後會啟動**死鎖偵測**：檢查等待圖裡有沒有環。找到環就**犧牲其中一個交易**（通常是偵測到環的那一個），讓它回滾。

**被犧牲的交易完整回滾**，資料沒有任何損壞 —— 這是交易的保證。應用層只要重試就好。

**死鎖本身不是資料正確性問題，是效能與可用性問題。**

</details>

<details>
<summary>Hint 2 — 為什麼固定鎖順序能消除死鎖</summary>

死鎖的必要條件之一是**循環等待**。如果所有交易都**依照同一個全域順序**取得鎖，就不可能形成環。

```sql
SELECT id FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
```

不管你是要 1→2 還是 2→1，這一句都會**先鎖 1、再鎖 2**。

於是：
- A 先跑 → 鎖住 1 和 2 → B 在第一步就卡住等待
- A 提交 → B 拿到鎖 → 完成

**B 只是「等待」，不是「死鎖」** —— 因為它沒有持有任何 A 想要的東西。

**排序依據的條件**：必須是**全域一致且穩定**的。`id`（主鍵）最理想。不能用 `owner` 之類可能改變的欄位，也不能用「金額大小」這種依交易而異的東西。

**一對多轉帳**（1 轉給 5 個人）一樣適用：把 6 個帳戶 id 全部收集起來 `ORDER BY id FOR UPDATE` 一次鎖完。

</details>

<details>
<summary>Hint 3 — 生產等級的轉帳</summary>

```sql
BEGIN;

-- 1. 固定順序鎖住兩個帳戶（消除死鎖）
SELECT id FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;

-- 2. 扣款，條件內建（餘額不足則影響 0 列）
UPDATE accounts SET balance = balance - 100
WHERE id = 1 AND balance >= 100;
-- 應用層檢查 rowcount，若為 0 則 ROLLBACK 並回報「餘額不足」

-- 3. 入帳
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

-- 4. 稽核紀錄
INSERT INTO transfers (from_id, to_id, amount) VALUES (1, 2, 100);

COMMIT;
```

**純 SQL 裡沒有 `IF`，所以「影響 0 列就中止」要靠應用層或 PL/pgSQL。**

PL/pgSQL 版本：

```sql
UPDATE accounts SET balance = balance - p_amount
WHERE id = p_from AND balance >= p_amount;

IF NOT FOUND THEN
    RAISE EXCEPTION 'insufficient funds in account %', p_from
        USING ERRCODE = 'P0001';
END IF;
```

`RAISE EXCEPTION` 會**自動回滾整個交易** —— 這是 C2 的答案之一。

**C2 的另一個答案**：函數裡**不能**寫 `BEGIN`/`COMMIT`（PL/pgSQL 函數本身就在呼叫端的交易裡執行）。要控制交易得用 `PROCEDURE` + `CALL`。

</details>

<details>
<summary>Hint 4 — 不變式與熱點帳戶</summary>

**C3 的不變式檢查**：

```sql
-- 不管併發怎麼跑，這個數字必須恆定
SELECT SUM(balance) AS total_money FROM accounts;

-- 更強的檢查：餘額 = 期初 + 所有入帳 - 所有出帳
SELECT a.id, a.balance,
       a.opening + COALESCE(i.amt,0) - COALESCE(o.amt,0) AS derived
FROM accounts a
LEFT JOIN (SELECT to_id,   SUM(amount) amt FROM transfers GROUP BY to_id)   i ON i.to_id   = a.id
LEFT JOIN (SELECT from_id, SUM(amount) amt FROM transfers GROUP BY from_id) o ON o.from_id = a.id
WHERE a.balance IS DISTINCT FROM a.opening + COALESCE(i.amt,0) - COALESCE(o.amt,0);
```

回傳 0 列 = 帳實相符。**這是 [Phase 1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) 的對帳查詢，`IS DISTINCT FROM` 也在這裡救你。**

**D1 熱點帳戶**：所有交易都要鎖同一列 → 完全序列化 → 吞吐量上限就是「1 / 交易時長」。

解法是**分桶**（sharded counter）：

```sql
CREATE TABLE fee_account_buckets (bucket INT PRIMARY KEY, balance NUMERIC(12,2) NOT NULL);
-- 插入 100 個桶

-- 入帳時隨機選一個桶
UPDATE fee_account_buckets SET balance = balance + 5
WHERE bucket = (random() * 99)::int + 1;

-- 查總額時加總
SELECT SUM(balance) FROM fee_account_buckets;
```

**寫入分散到 100 個桶 → 併發度 ×100**，代價是讀取總額變成聚合查詢。

這是「**用寫入的分散性換讀取的簡單性**」的經典取捨。

</details>
