# Phase 6 — DML、併發、與資料正確性

> **這一章和前五章不一樣。**
>
> Phase 1~5 的每一題，你一個 session 就能做完。
> **這一章的每一題，單一 session 跑起來都是「對的」，只有兩個 session 同時跑才會壞。**

<br>

---

<br>

## 開始之前：準備兩個 session

這一章大部分題目需要**同時開兩個連線**。三種做法：

### 做法 A — 兩個終端機視窗（最直覺）

```bash
# 視窗 1
docker exec -it postgres-leetcode psql -U root -d lico_adv

# 視窗 2
docker exec -it postgres-leetcode psql -U root -d lico_adv
```

題目裡會標示 `-- Session A` / `-- Session B`，照順序在兩個視窗貼上執行。

### 做法 B — 用 shell 腳本模擬並行

```bash
cat > worker.sh <<'SH'
docker exec -i postgres-leetcode psql -U root -d lico_adv -tAq <<EOF
BEGIN;
SELECT '$1 開始';
SELECT pg_sleep(0.4);
-- 你的 SQL
COMMIT;
EOF
SH
chmod +x worker.sh
( ./worker.sh A & ./worker.sh B & wait )
```

`pg_sleep` 是關鍵 —— 它把「讀」和「寫」之間的空隙拉大，讓競態必定發生。

### 做法 C — 檢視鎖狀態

卡住時，開第三個 session 查：

```sql
SELECT pid, wait_event_type, wait_event, state,
       left(query, 60) AS query
FROM pg_stat_activity
WHERE datname = 'lico_adv' AND pid <> pg_backend_pid();

-- 誰擋住誰
SELECT pid, pg_blocking_pids(pid) AS blocked_by, left(query,60)
FROM pg_stat_activity WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

<br>

> ⚠️ **兩個保命習慣**
>
> 1. 每一題開始前設 `SET lock_timeout = '5s';` —— 否則卡住的 session 會等到天荒地老
> 2. 手動貼 SQL 時，`BEGIN;` 之後**一定要記得 `COMMIT;` 或 `ROLLBACK;`**，忘了會一直持有鎖

<br>

需要的 extension：

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- 6-03 會用到
```

<br>

---

<br>

## 這一章在回答什麼問題

[Phase 3-07](../phase-3-window-deep-water/07-the-running-balance-with-a-floor) 問「window function 怎麼算餘額」→ 做不到。
[Phase 4-05](../phase-4-recursive-cte/05-running-balance-recursive-edition) 問「遞迴 CTE 怎麼算」→ 做得到，但慢。

**這一章回答最後一段**：真實的銀行系統為什麼兩種都不用 —— 因為餘額不是「算出來的報表」，是「**多個交易同時在改的狀態**」。

而只要有「同時」，前面五章學的所有東西都不夠用了。

<br>

---

<br>

## 題目

| # | 題目 | 核心技巧 | 難度 |
|---|------|---------|------|
| 01 | [The Idempotent Upsert](01-the-idempotent-upsert) | `ON CONFLICT`、部分唯一索引、重試安全 | ★★★★☆ |
| 02 | [The Job Queue That Double-Processed](02-the-job-queue-that-double-processed) | `FOR UPDATE SKIP LOCKED` | ★★★★★ |
| 03 | [Preventing Double Booking](03-preventing-double-booking) | `EXCLUDE` 約束 + `tstzrange` | ★★★★★ |
| 04 | [The Lost Update](04-the-lost-update) | 隔離級別、樂觀鎖 vs 悲觀鎖 | ★★★★★ |
| 05 | [Transfer Money Atomically](05-transfer-money-atomically) | 交易原子性、死鎖與鎖順序 | ★★★★☆ |
| 06 | [Deduplicate a 10M-Row Table](06-deduplicate-a-10m-row-table) | `ctid`、分批刪除、鎖持有時間 | ★★★★★ |
| 07 | [MERGE vs ON CONFLICT](07-merge-vs-on-conflict) | PG15 `MERGE` 的併發陷阱 | ★★★☆☆ |

<br>

---

<br>

## Phase 6 自我檢測

面試官給你這三行：

```sql
SELECT balance FROM accounts WHERE id = 1;       -- 讀到 1000
-- 應用層計算 1000 - 300 = 700
UPDATE accounts SET balance = 700 WHERE id = 1;  -- 寫回
```

「兩個人同時提款 300，最後餘額是多少？應該是多少？三種修法各是什麼、各自的取捨？」

你要能在 **90 秒內**講完：Lost Update → 結果 700（應為 400）→ 三種修法（原子 `UPDATE`、樂觀鎖 version、`SELECT FOR UPDATE`）→ 各自在什麼場景下適用。
