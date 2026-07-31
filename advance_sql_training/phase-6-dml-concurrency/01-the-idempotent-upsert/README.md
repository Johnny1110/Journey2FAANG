# Phase 6-01 — The Idempotent Upsert

> **難度**：★★★★☆
> **核心技巧**：`INSERT ... ON CONFLICT`、`EXCLUDED`、部分唯一索引、冪等性
> **對應基礎題**：[練習題（自設）UPSERT by user_id](../../../sql_training/upsert_by_user_id)（你當初的單執行緒版本）

<br>

---

<br>

## Interview Context

> *面試官：*「我們接金流商的 webhook。他們的規格寫得很清楚：**同一個事件可能會送多次**，因為他們沒收到 200 就會重試。
>
> 上週對帳發現有客戶被**重複記帳三次**。
>
> 工程師說他有做檢查：先 `SELECT` 看事件在不在，不在才 `INSERT`。」

<br>

「先查再寫」在單執行緒下是對的。**在併發下它永遠是錯的** —— 兩個請求可以同時查到「不在」。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS webhook_events;

CREATE TABLE webhook_events (
    event_id    VARCHAR(40) PRIMARY KEY,     -- 金流商給的唯一事件 ID
    payload     TEXT NOT NULL,
    received_at TIMESTAMP NOT NULL DEFAULT now(),
    retry_count INT NOT NULL DEFAULT 0
);

DROP TABLE IF EXISTS subscriptions;

CREATE TABLE subscriptions (
    id      SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    plan    TEXT NOT NULL,
    status  TEXT NOT NULL                    -- 'active' / 'cancelled'
);

INSERT INTO subscriptions (user_id, plan, status) VALUES
(1, 'pro',   'cancelled'),
(1, 'basic', 'cancelled');
```

<br>

---

<br>

## Part A — 先查再寫的競態

### A1

寫出「先 `SELECT` 檢查，不存在才 `INSERT`」的邏輯（用兩個獨立的 SQL 語句表示）。

### A2 — 重現競態

用兩個 session 同時執行，在 `SELECT` 和 `INSERT` 之間插入 `SELECT pg_sleep(0.4);`：

```sql
-- Session A 和 Session B 幾乎同時執行
BEGIN;
SELECT count(*) FROM webhook_events WHERE event_id = 'evt_race';   -- 兩邊都讀到 0
SELECT pg_sleep(0.4);
INSERT INTO webhook_events (event_id, payload) VALUES ('evt_race', 'x');
COMMIT;
```

回答：
- 兩個 session 的 `SELECT` 各讀到什麼？
- 如果 `event_id` **沒有** PRIMARY KEY，最後會有幾列？
- 有 PRIMARY KEY 的話，第二個 session 會怎樣？**錯誤訊息是什麼？**
- **「拿到錯誤」和「靜靜寫入重複資料」，哪一個比較好？**

### A3

回答：為什麼「先查再寫」在任何隔離級別下都不安全？

（提示：READ COMMITTED 下兩個 `SELECT` 都看不到對方未提交的資料；REPEATABLE READ 下更看不到）

<br>

---

<br>

## Part B — `ON CONFLICT`

### B1 — 兩種模式

```sql
-- 模式一：重複就忽略
INSERT INTO webhook_events (event_id, payload) VALUES ('evt_1', 'v1')
ON CONFLICT (event_id) DO NOTHING;

-- 模式二：重複就更新
INSERT INTO webhook_events (event_id, payload) VALUES ('evt_1', 'v3')
ON CONFLICT (event_id) DO UPDATE
SET payload = EXCLUDED.payload,
    retry_count = webhook_events.retry_count + 1;
```

依序執行：`DO NOTHING('v1')` → `DO NOTHING('v2')` → `DO UPDATE('v3')`。

驗證最後結果是 `payload = 'v3'`, `retry_count = 1`。

回答：
- `EXCLUDED` 是什麼？它代表哪一份資料？
- `webhook_events.retry_count` 和 `EXCLUDED.retry_count` 分別是什麼？**為什麼要寫表名？**
- 對 webhook 這個場景，`DO NOTHING` 和 `DO UPDATE` 你選哪個？為什麼？

### B2 — 陷阱一：同一個語句裡有重複鍵

```sql
INSERT INTO webhook_events (event_id, payload) VALUES ('evt_9','a'), ('evt_9','b')
ON CONFLICT (event_id) DO UPDATE SET payload = EXCLUDED.payload;
```

**跑跑看。** 你會拿到：

```
ERROR:  ON CONFLICT DO UPDATE command cannot affect row a second time
HINT:  Ensure that no rows proposed for insertion within the same command have duplicate constrained values.
```

回答：
- 為什麼 PostgreSQL 不讓你這樣做？（它該用 'a' 還是 'b'？）
- 批次匯入時很容易踩到這個。**怎麼在 `INSERT` 之前就去重？**
- 改成 `DO NOTHING` 會報錯嗎？自己測。

### B3 — 陷阱二：`ON CONFLICT` 的目標必須對應真實索引

```sql
INSERT INTO webhook_events (event_id, payload) VALUES ('evt_2','x')
ON CONFLICT (payload) DO NOTHING;
```

```
ERROR:  there is no unique or exclusion constraint matching the ON CONFLICT specification
```

回答：
- 為什麼不能對任意欄位寫 `ON CONFLICT`？
- `ON CONFLICT DO NOTHING`（**不指定欄位**）合法嗎？它的語意是什麼？和指定欄位差在哪？
- 什麼情況下你會用不指定欄位的版本？**它有什麼風險？**

<br>

---

<br>

## Part C — 部分唯一索引

### C1 — 需求

商業規則：**一個使用者同時只能有一個 `active` 訂閱，但可以有任意多個 `cancelled` 的歷史訂閱。**

普通的 `UNIQUE (user_id)` 做得到嗎？為什麼不行？

### C2 — 部分唯一索引

```sql
CREATE UNIQUE INDEX uniq_active_sub ON subscriptions (user_id) WHERE status = 'active';
```

測試：
1. `INSERT (1,'pro','active')` → 應該成功
2. 再 `INSERT (1,'team','active')` → 應該**失敗**，錯誤訊息是什麼？
3. 現有的兩筆 `cancelled` 有受影響嗎？

### C3 — 陷阱三：`ON CONFLICT` 配部分索引

```sql
INSERT INTO subscriptions (user_id, plan, status) VALUES (1,'team','active')
ON CONFLICT (user_id) DO NOTHING;
```

**會報錯。** 為什麼？

正確寫法要加上索引的 `WHERE` 條件：

```sql
ON CONFLICT (user_id) WHERE status = 'active' DO UPDATE SET plan = EXCLUDED.plan
```

回答：
- 為什麼 `ON CONFLICT` 需要知道索引的 predicate？
- 這叫做什麼？（提示：**索引推斷**，index inference）
- 如果一張表有多個部分唯一索引，你要怎麼指定要用哪一個？

### C4 — 實務設計

回答：
- 部分唯一索引 vs 「用 `status` 當複合主鍵一部分」，兩種設計的取捨？
- 部分唯一索引的體積和普通索引比如何？（本題只索引 active 的行）
- **如果 `status` 從 `'active'` 改成 `'cancelled'`，索引會怎麼變化？**

<br>

---

<br>

## Part D — 冪等性

### D1

回答：什麼是**冪等**（idempotent）？用一句話定義，然後說明為什麼 webhook handler 必須冪等。

### D2

你的 `ON CONFLICT` 版本冪等嗎？分別回答：

| 寫法 | 執行 3 次的結果 | 冪等嗎 |
|------|----------------|--------|
| `DO NOTHING` | ? | ? |
| `DO UPDATE SET payload = EXCLUDED.payload` | ? | ? |
| `DO UPDATE SET retry_count = retry_count + 1` | ? | ? |

**第三個特別注意** —— 它是不是冪等？如果不是，這樣設計對嗎？

### D3 — 更大的問題

webhook handler 除了寫 `webhook_events`，通常還要**做事**（記帳、發信、更新訂單）。

回答：
- 「寫入事件表」和「做事」要不要在同一個交易裡？
- 如果做事失敗但事件表已經寫入，重試會發生什麼？
- **這個問題有標準解嗎？**（提示：outbox pattern / 兩階段 —— 講得出方向即可）

<br>

---

<br>

## 面試官的追問

> 1. 「`ON CONFLICT` 底層怎麼做到不會有競態？」（提示：speculative insertion）
>
> 2. 「兩個 session 同時對**同一個鍵**做 `ON CONFLICT DO UPDATE`，第二個會等待嗎？會死鎖嗎？」
>
> 3. 「`ON CONFLICT DO UPDATE` 會觸發哪些 trigger？`BEFORE INSERT` 還是 `BEFORE UPDATE`？」
>
> 4. 「如果我要『存在就更新、不存在就插入，而且要知道剛剛是插入還是更新』，怎麼寫？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼「先查再寫」必定有競態</summary>

```
時間 →
Session A:  SELECT (讀到 0) ────────────── INSERT ──── COMMIT
Session B:      SELECT (讀到 0) ────────────── INSERT ──── COMMIT
                     ↑
              兩邊都看到「不存在」
```

**關鍵**：A 的 `INSERT` 在 `COMMIT` 之前，B **看不到**（任何隔離級別都看不到未提交的資料）。所以 B 的 `SELECT` 必然讀到 0。

隔離級別**幫不上忙**：
- READ COMMITTED：B 看不到 A 未提交的 INSERT
- REPEATABLE READ：B 連 A 提交後的資料都看不到（用快照）
- SERIALIZABLE：會偵測到衝突並讓其中一個失敗 —— **但你還是要處理錯誤並重試**

**唯一的正解是把「檢查 + 寫入」變成一個原子操作** —— 這就是 `ON CONFLICT` 做的事，或者靠唯一約束讓資料庫幫你擋。

</details>

<details>
<summary>Hint 2 — EXCLUDED 是什麼</summary>

`EXCLUDED` 是一個**虛擬表**，代表「**原本要插入但因為衝突被排除掉的那一列**」。

```sql
INSERT INTO webhook_events (event_id, payload) VALUES ('evt_1', 'v3')
ON CONFLICT (event_id) DO UPDATE
SET payload     = EXCLUDED.payload,                    -- 'v3'（新來的值）
    retry_count = webhook_events.retry_count + 1;      -- 表裡現有的值 + 1
```

- `EXCLUDED.payload` → **新資料**（'v3'）
- `webhook_events.retry_count` → **舊資料**（表裡現有的）

**必須寫表名**，否則 `retry_count = retry_count + 1` 會有歧義 —— PostgreSQL 不知道你指的是哪一個。

（這和 MySQL 的 `VALUES(col)` / `ON DUPLICATE KEY UPDATE` 是對應概念，語法不同。）

</details>

<details>
<summary>Hint 3 — 為什麼「同一語句重複鍵」會報錯</summary>

```sql
VALUES ('evt_9','a'), ('evt_9','b')
```

第一列插入成功。第二列衝突了 → 觸發 `DO UPDATE` → 但它要更新的**正是同一個語句剛剛才插入的那一列**。

PostgreSQL 拒絕這件事，因為結果是**未定義的**：最終該是 'a' 還是 'b'？而且一個語句內多次修改同一列會破壞 MVCC 的假設。

**`DO NOTHING` 不會報錯** —— 第二列直接被丟掉，結果是 'a'。（自己測一次確認。）

**批次匯入的正確做法**：先在來源端去重。

```sql
INSERT INTO webhook_events (event_id, payload)
SELECT DISTINCT ON (event_id) event_id, payload
FROM staging_table
ORDER BY event_id, received_at DESC          -- 同鍵取最新的那筆
ON CONFLICT (event_id) DO UPDATE SET payload = EXCLUDED.payload;
```

`DISTINCT ON` 又出現了 —— [Phase 2-04](../../phase-2-aggregation-limits/04-the-mode-that-ties) 說過它的定位就是「每組取一筆」。

</details>

<details>
<summary>Hint 4 — 索引推斷與部分索引</summary>

`ON CONFLICT (user_id)` 這個寫法叫**索引推斷**：PostgreSQL 要從你給的欄位找出**唯一一個**符合的唯一索引。

部分索引 `(user_id) WHERE status='active'` 只對 `status='active'` 的列生效。如果只寫 `ON CONFLICT (user_id)`，PostgreSQL 無法確定你指的是「全表唯一」還是「部分唯一」—— 兩者語意天差地別，所以它拒絕猜測。

加上 predicate 就明確了：

```sql
ON CONFLICT (user_id) WHERE status = 'active' DO UPDATE SET plan = EXCLUDED.plan
```

**C4 的答案**：
- 部分索引**只索引符合條件的列**，所以體積小很多（本題只索引 active 的訂閱，可能是全表的 1%）
- 當某列的 `status` 從 `'active'` 改成 `'cancelled'`，它會**從索引中被移除** —— 這也是為什麼「取消舊訂閱、開新訂閱」的操作能通過約束
- 但要小心順序：**必須先取消舊的、再開新的**，否則中間那一瞬間會有兩個 active 而違反約束

這正是 [Phase 5-05](../../phase-5-time-series/05-scd-type-2-point-query) D3 那個「原本 `valid_to IS NULL` 的那列怎麼處理」的併發版本。

</details>
