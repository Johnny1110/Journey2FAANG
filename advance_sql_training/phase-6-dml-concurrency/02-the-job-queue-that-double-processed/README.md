# Phase 6-02 — The Job Queue That Double-Processed

> **難度**：★★★★★
> **核心技巧**：`SELECT ... FOR UPDATE SKIP LOCKED`、行級鎖、佇列模式
> **對應基礎題**：[LC 1204. Last Person to Fit in the Bus](../../../sql_training/last_person_to_fit_in_the_bus)（你當初是單執行緒的循序處理）

<br>

---

<br>

## Interview Context

> *面試官：*「我們用一張 `jobs` 表當工作佇列，跑三個 worker process。
>
> 上週有 200 個客戶**收到兩封一模一樣的帳單信**。
>
> Worker 的邏輯是：撈一筆 pending 的、寄信、標記成 done。工程師堅持他有用 `BEGIN` / `COMMIT` 包起來。
>
> **交易不能解決這個問題。** 你告訴我為什麼，然後修好它。」

<br>

「我有用交易」是最常見的誤解。**交易保證的是原子性和隔離性，不是互斥性** —— 兩個交易可以同時讀到同一筆 pending 的工作。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS jobs;

CREATE TABLE jobs (
    id        SERIAL PRIMARY KEY,
    payload   TEXT NOT NULL,
    status    TEXT NOT NULL DEFAULT 'pending',   -- pending / running / done
    locked_by TEXT,
    locked_at TIMESTAMP
);

INSERT INTO jobs (payload)
SELECT 'job_' || g FROM generate_series(1, 5) g;
```

<br>

---

<br>

## Part A — 重現雙重處理

### A1 — 天真版

兩個 session **同時**執行（用 `pg_sleep` 模擬「寄信」的耗時）：

```sql
-- Session A 和 Session B 同時跑
BEGIN;
SELECT id FROM jobs WHERE status = 'pending' ORDER BY id LIMIT 1;   -- 撈工作
SELECT pg_sleep(0.4);                                               -- 假裝在寄信
UPDATE jobs SET status = 'running', locked_by = 'A'                 -- B 就填 'B'
 WHERE id = (SELECT id FROM jobs WHERE status = 'pending' ORDER BY id LIMIT 1);
COMMIT;
```

**實測結果**：

```
worker B picked job 1
worker A picked job 1        ← 兩個 worker 都撈到 job 1
```

### A2 — 診斷

回答：
- 兩個 worker 的 `SELECT` 各回傳什麼？
- 最後 `jobs` 表裡 job 1 的 `locked_by` 是誰？
- **但兩個 worker 都已經把信寄出去了。** 資料庫的最終狀態看起來完全正常 —— 這是這個 bug 最可怕的地方。寫出你的理解。
- 為什麼 `BEGIN` / `COMMIT` 完全沒有幫助？

### A3 — 隔離級別能救嗎

分別在 `REPEATABLE READ` 和 `SERIALIZABLE` 下重跑 A1。

- 結果有變嗎？
- `SERIALIZABLE` 會不會讓其中一個失敗？
- **即使它讓一個失敗了，這是好的解法嗎？**（提示：想想 worker 已經寄出的信）

<br>

---

<br>

## Part B — 三種鎖策略

### B1 — `FOR UPDATE`（悲觀鎖，會阻塞）

```sql
SELECT id FROM jobs WHERE status = 'pending' ORDER BY id FOR UPDATE LIMIT 1;
```

兩個 session 同時跑，回答：
- Session B 會發生什麼事？（提示：它會停住）
- B 等到 A 提交後，它撈到的是哪一筆？**為什麼？**
- 三個 worker 的話，實際的併行度是多少？
- **這解決了雙重處理嗎？代價是什麼？**

### B2 — `FOR UPDATE SKIP LOCKED`（正解）

```sql
SELECT id FROM jobs WHERE status = 'pending' ORDER BY id
FOR UPDATE SKIP LOCKED LIMIT 1;
```

**實測結果**：

```
worker B got job 1
worker A got job 2           ← 各拿各的，都在工作
```

回答：
- `SKIP LOCKED` 的語意是什麼？
- 為什麼 A 拿到 job 2 而不是等待？
- **`ORDER BY id` 還有意義嗎？** 在 `SKIP LOCKED` 下它保證什麼、不保證什麼？

### B3 — 三者對照

| | 天真版 | `FOR UPDATE` | `FOR UPDATE SKIP LOCKED` |
|---|---|---|---|
| 會雙重處理嗎 | ? | ? | ? |
| worker 會互相阻塞嗎 | ? | ? | ? |
| 3 個 worker 的併行度 | ? | ? | ? |
| 工作的處理順序 | ? | ? | ? |
| 適合什麼場景 | ? | ? | ? |

<br>

---

<br>

## Part C — 完整的佇列實作

### C1 — 原子的「撈取 + 標記」

B2 還是分成兩個語句（`SELECT` 然後 `UPDATE`）。用**一個語句**完成撈取並標記：

```sql
UPDATE jobs SET status = 'running', locked_by = 'worker_A', locked_at = now()
WHERE id = (
    SELECT id FROM jobs WHERE status = 'pending'
    ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 1
)
RETURNING id, payload;
```

回答：
- `RETURNING` 做什麼？為什麼這裡需要它？
- 為什麼 `FOR UPDATE SKIP LOCKED` 要寫在**子查詢**裡？
- 沒有 pending 工作時，這個語句回傳什麼？應用層要怎麼處理？

### C2 — 一次撈多筆

改成一次撈 10 筆（批次處理更有效率）。

提示：`WHERE id IN (SELECT ... LIMIT 10)` 或用 CTE。

### C3 — 卡住的工作

Worker 撈了工作之後**當機了**，那筆工作永遠停在 `running`。

- 寫一個查詢找出「`running` 超過 5 分鐘」的殭屍工作
- 寫出把它們放回 `pending` 的 SQL
- **這樣做安全嗎？**如果原本的 worker 只是很慢、沒死呢？（提示：心跳、租約 lease）

### C4 — 重試與死信

加上 `attempts` 欄位。

- 工作失敗要怎麼處理？
- 重試幾次之後該放棄？放棄的工作放哪？
- 寫出完整的 schema 與狀態轉換圖

<br>

---

<br>

## Part D — 規模與替代方案

### D1 — 效能

`jobs` 表有 1000 萬筆，其中 99% 是 `done`。

- 你的撈取查詢要加什麼索引？
- **部分索引** `WHERE status = 'pending'` 有幫助嗎？體積差多少？
  （[6-01](../01-the-idempotent-upsert) Part C 的技巧在這裡有第二個用途）
- `done` 的資料要不要搬走？怎麼搬？

### D2 — 為什麼不用專門的佇列

回答：
- Redis / RabbitMQ / SQS 相比「用資料庫當佇列」，各有什麼優缺點？
- 什麼情況下**用資料庫當佇列反而是對的**？
  （提示：想想「工作的建立」和「業務資料的寫入」需不需要在同一個交易裡）
- 這個模式有名字嗎？

### D3 — `SKIP LOCKED` 的其他用途

`SKIP LOCKED` 不只能做佇列。舉出**兩個**其他使用場景。

<br>

---

<br>

## 面試官的追問

> 1. 「`FOR UPDATE` 和 `FOR NO KEY UPDATE` / `FOR SHARE` 差在哪？佇列該用哪個？」
>
> 2. 「`SKIP LOCKED` 會不會造成某些工作永遠被跳過（飢餓）？」
>
> 3. 「如果我要保證工作**嚴格照順序**處理（FIFO，不能亂序），`SKIP LOCKED` 還能用嗎？」
>
> 4. 「worker 撈到工作後，如果它的交易一直不提交，會發生什麼事？怎麼防？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼交易救不了</summary>

交易提供 **ACID**，但這裡需要的是**互斥**：

- **A**tomicity：整個交易要嘛全成功要嘛全失敗 —— 和「兩個 worker 撈到同一筆」無關
- **C**onsistency：約束不被違反 —— 這裡沒有任何約束被違反（`status` 從 pending 變 running 完全合法）
- **I**solation：交易看不到彼此的中間狀態 —— **這正是問題所在**：A 看不到 B 也撈了同一筆
- **D**urability：提交後不會消失 —— 無關

**Isolation 讓兩個 worker 互相看不見，而「互相看不見」正是雙重處理的原因。**

最終資料庫狀態完全合法（job 1 是 running，locked_by 是其中一個 worker）—— 但**兩封信已經寄出去了，資料庫不知道也管不著**。

**這就是為什麼副作用（寄信、扣款、呼叫外部 API）必須靠鎖來保護，而不是靠交易。**

</details>

<details>
<summary>Hint 2 — 三種鎖的行為</summary>

**`FOR UPDATE`（不加 SKIP LOCKED）**

A 鎖住 job 1 → B 執行同樣的查詢 → **B 被阻塞，停在那裡等**。

A 提交後（job 1 已變成 running），B 的查詢**重新評估** `WHERE status='pending'` → job 1 不再符合 → B 拿到 job 2。

**結果是正確的，但 worker 變成排隊的** —— 3 個 worker 的實際併行度趨近 1，加 worker 完全沒用。

**`FOR UPDATE SKIP LOCKED`**

B 發現 job 1 被鎖住 → **直接跳過，不等待** → 拿 job 2。

三個 worker 同時拿到三筆不同的工作 → **真正的併行**。

**代價**：`ORDER BY id` 只保證「**每個 worker 各自**優先拿編號小的」，不保證全域的處理順序。job 3 可能比 job 2 先完成。**佇列不是 FIFO 了。**

</details>

<details>
<summary>Hint 3 — 一個語句完成撈取</summary>

```sql
UPDATE jobs
SET status = 'running', locked_by = 'worker_A', locked_at = now()
WHERE id = (
    SELECT id FROM jobs
    WHERE status = 'pending'
    ORDER BY id
    FOR UPDATE SKIP LOCKED
    LIMIT 1
)
RETURNING id, payload;
```

**為什麼 `FOR UPDATE SKIP LOCKED` 在子查詢裡**：外層的 `UPDATE` 本身會加鎖，但那是**在選定目標之後**。要在「挑選」階段就跳過被鎖的行，必須在子查詢裡下鎖提示。

**`RETURNING` 的作用**：一個語句同時完成「標記」和「取得 payload」。沒有它你要再 `SELECT` 一次，而那又是一次競態機會。

沒有 pending 工作時回傳 **0 列** —— 應用層要判斷並 sleep 後重試（或用 `LISTEN`/`NOTIFY` 等通知）。

</details>

<details>
<summary>Hint 4 — D1 部分索引與 D2 的取捨</summary>

```sql
CREATE INDEX idx_jobs_pending ON jobs (id) WHERE status = 'pending';
```

1000 萬列裡只有 1% 是 pending → 索引只有 10 萬個項目，**體積是全表索引的 1%**。

而且 `done` 的工作變多時，這個索引**不會變大** —— 因為 `status` 改成 `done` 時該列就從索引中被移除了。

**D2 的核心答案**：

用專門佇列（SQS、RabbitMQ）的問題是 **「工作建立」和「業務資料寫入」無法在同一個交易裡**。

```
BEGIN;
INSERT INTO orders (...);          -- 業務資料
-- 送訊息到 SQS ← 這一步不在交易裡！
COMMIT;
```

如果 `COMMIT` 失敗，訊息已經送出去了 → 幽靈工作。
如果訊息送出前 crash，訂單建立了但沒有後續處理 → 遺失工作。

**用資料庫當佇列時，兩者在同一個交易裡，要嘛都成功要嘛都回滾。** 這叫 **transactional outbox**（或直接說 database-as-queue）。

代價是資料庫的寫入壓力和 vacuum 負擔。**吞吐量需求不高但一致性要求高的場景，資料庫佇列是正確選擇。**

</details>
