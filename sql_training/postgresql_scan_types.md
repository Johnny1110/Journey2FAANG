# PostgreSQL Scan Types — 完整教學

> 目標：讀懂 EXPLAIN 輸出中的每一種 Scan 節點，能判斷查詢瓶頸並提出優化方案。

---

## 目錄

1. [什麼是 Scan Node](#1-什麼是-scan-node)
2. [如何閱讀 EXPLAIN 輸出](#2-如何閱讀-explain-輸出)
3. [六大核心 Scan Type 詳解](#3-六大核心-scan-type-詳解)
   - [Seq Scan（全表掃描）](#31-seq-scan全表掃描)
   - [Index Scan（索引掃描）](#32-index-scan索引掃描)
   - [Index Only Scan（純索引掃描）](#33-index-only-scan純索引掃描)
   - [Bitmap Index Scan + Bitmap Heap Scan（點陣圖掃描）](#34-bitmap-index-scan--bitmap-heap-scan點陣圖掃描)
   - [Parallel Seq Scan（並行全表掃描）](#35-parallel-seq-scan並行全表掃描)
4. [Planner 的選擇邏輯](#4-planner-的選擇邏輯)
5. [其他 Scan Type 速查](#5-其他-scan-type-速查)
6. [實戰判斷流程](#6-實戰判斷流程)
7. [常見效能陷阱與解法](#7-常見效能陷阱與解法)

---

## 1. 什麼是 Scan Node

在 PostgreSQL 的查詢執行計劃中，**Scan Node（掃描節點）** 是整個計劃樹的葉子節點（leaf node）。它負責從一張表中「讀取」符合條件的 row，並將結果往上傳遞給上層運算節點（如 Join、Sort、Aggregate）。

```
Sort
 └─ Hash Join
     ├─ Hash
     │   └─ Seq Scan on products     ← 這是一個 Scan Node
     └─ Nested Loop
         ├─ Index Scan on orders     ← 這是一個 Scan Node
         └─ Index Scan on order_items ← 這是一個 Scan Node
```

所有查詢的最底層都是 Scan。**Scan Node 的類型直接決定了查詢的 I/O 模式與效能天花板**。

---

## 2. 如何閱讀 EXPLAIN 輸出

執行 `EXPLAIN ANALYZE` 後，每個 Scan Node 的輸出格式如下：

```
Seq Scan on users  (cost=0.00..2487.00 rows=500 width=93)
                   (actual time=12.345..78.912 rows=1 loops=1)
   Filter: (lower((email)::text) = 'alice@example.com'::text)
   Rows Removed by Filter: 100002
```

### 關鍵欄位解讀

| 欄位 | 說明 | 面試重點 |
|------|------|---------|
| **cost=啟動..總成本** | planner 估算的成本（單位是 arbitrary unit，1 約等於一次 sequential page read） | `0.00` 啟動成本表示不需要排序/預處理就能開始 |
| **rows=估算行數** | planner 估算此節點會返回多少行 | 估算值 vs 實際值（actual rows）差距大 → `ANALYZE` 該表或調整 `default_statistics_target` |
| **actual time=啟動..結束** | 實際執行：第一個 row 的延遲 vs 全部 row 的時間（毫秒） | 差距大 = 需要長時間才能返回第一批資料 |
| **rows=N** | 此節點實際返回的行數 | 1 row 但過濾了 10 萬行 → 這是瓶頸 |
| **loops=N** | 此節點被上層執行了幾次 | loops=897 且在 Nested Loop 內側 → 多次重複掃描 |
| **Rows Removed by Filter** | 讀取但被過濾掉的行數 | 值接近總行數 → 無 index 或多數行不符合 |
| **Heap Fetches** | Index Scan 中實際回表讀取的次數 | 大量 Heap Fetches → 考慮 covering index |
| **Buffers: shared hit/read** | cache hit vs 磁碟讀取的 page 數 | `read` 大 → 資料不在 memory，需要 `pg_prewarm` 或加大 `shared_buffers` |

### EXPLAIN 參數選擇

| 參數 | 用途 | 何時用 |
|------|------|--------|
| `EXPLAIN` | 只顯示計劃，不執行 | 快速看 planner 的決策 |
| `EXPLAIN ANALYZE` | 實際執行 + 計時 | 需要看真實效能數據（**注意：會真的執行查詢**） |
| `EXPLAIN (ANALYZE, BUFFERS)` | 加上 cache / disk I/O 資訊 | 判斷瓶頸是 CPU 還是 I/O |
| `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` | JSON 格式輸出 | 搭配工具（如 pgAdmin 的可視化 Explain） |

---

## 3. 六大核心 Scan Type 詳解

### 3.1 Seq Scan（全表掃描）

#### 一句話解釋

從 table 的第一個 page 讀到最後一個 page，一行一行檢查 WHERE 條件。

#### 內部原理

```
┌─────────────────────────────────────┐
│  Table Heap (physical file on disk) │
│  [page 0] [page 1] [page 2] ...     │
│     ↓ read sequentially             │
│  Check WHERE clause on every row    │
│     ↓                               │
│  Return matching rows               │
└─────────────────────────────────────┘
```

- 使用 **sequential read**（順序 I/O），作業系統會做 read-ahead
- 每讀一個 page（預設 8KB）就檢查裡面所有 row 是否符合 WHERE 條件
- PostgreSQL 使用 **sync_seqscan** 機制：多個查詢同時掃同一張表時，會共用同一個掃描進度

#### 什麼時候出現

| 情況 | 範例 |
|------|------|
| 沒有 index 可以用 | `SELECT * FROM logs WHERE message LIKE '%error%'` |
| 有 index 但 planner 認為回表太多 | 100 萬行表中要取 20 萬行 — random I/O 比順序讀更貴 |
| 表太小 | < 10 個 page，index lookup 的 overhead > 直接掃 |
| 查詢 `SELECT *` 且無 WHERE | 當然是全表掃描 |

#### 是好是壞

| 小表（< 1000 rows） | 大表（> 10 萬 rows） |
|---------------------|----------------------|
| 沒問題，甚至比 Index Scan 快 | **危險訊號**：代表缺 index、index 失效、或查詢選擇率太高 |

#### 實戰 EXPLAIN 範例

```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';
```

```
Seq Scan on users  (cost=0.00..2487.00 rows=500 width=93)
                   (actual time=12.345..78.912 rows=1 loops=1)
   Filter: (lower((email)::text) = 'alice@example.com'::text)
   Rows Removed by Filter: 100002
 Planning Time: 0.152 ms
 Execution Time: 78.987 ms
```

**解讀**：讀了 100,003 行，只返回 1 行。99.999% 的 I/O 是浪費。`LOWER(email)` 讓 index 失效。

#### 優化方向

1. 建立適合的 index
2. 避免在 WHERE 中對 indexed column 使用函數（`LOWER(col)`, `col::text`, `col + 1`）
3. 如果查詢確實需要全表掃描（如 nightly batch），那是合理的

---

### 3.2 Index Scan（索引掃描）

#### 一句話解釋

走 B-tree（或其他 index）快速定位到符合條件的 row 位置，再回 heap 讀取完整資料。

#### 內部原理

```
┌──────────────────────┐     ┌──────────────────────┐
│  B-tree Index        │     │  Table Heap          │
│                      │     │                      │
│  [root]              │     │  page 3  → [row]     │
│   ├─ [branch]        │     │  page 17 → [row]     │
│   │   ├─ [leaf] ─────┼────→│  page 42 → [row]     │
│   │   ├─ [leaf]      │     │  ...                 │
│   │   └─ [leaf]      │     └──────────────────────┘
│   └─ [branch]        │
│       └─ ...         │     random I/O per heap fetch
└──────────────────────┘
```

1. 從 root 開始 traverse B-tree，找到 leaf page 中的 index entry
2. index entry 包含了指向 heap 的 pointer（`(page_number, offset)` 即 ctid）
3. **每次回表（heap fetch）都是一次 random I/O**

#### 什麼時候出現

- WHERE 條件中有 index 的第一列（composite index 的最左前綴）
- 查詢選擇性高（返回行數佔比 < 1~5%）
- JOIN 的 ON 條件上有 index

#### 效能特性

| 優點 | 缺點 |
|------|------|
| 不需要掃全表 | 大量回表 = 大量 random I/O |
| 啟動時間快（第一行很快返回） | 如果返回行數多（> 10%），可能比 Seq Scan 更慢 |

#### 實戰 EXPLAIN 範例

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 4823;
```

```
Index Scan using idx_orders_user_id on orders
    (cost=0.42..373.87 rows=215 width=40)
    (actual time=0.045..1.223 rows=203 loops=1)
   Index Cond: (user_id = 4823)
   Buffers: shared hit=4 read=39
 Planning Time: 0.123 ms
 Execution Time: 1.345 ms
```

**解讀**：效率良好。走了 index，讀取 43 個 page，返回 203 行。

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 4823 AND total_amount > 500;
```

```
Index Scan using idx_orders_user_id on orders
    (cost=0.42..393.12 rows=50 width=40)
    (actual time=0.044..1.856 rows=12 loops=1)
   Index Cond: (user_id = 4823)
   Filter: (total_amount > 500)
   Rows Removed by Filter: 191
   Buffers: shared hit=4 read=39
```

**解讀**：`Index Cond` 是 index 定位的條件，`Filter` 是額外過濾。in Index Scan 先用 `user_id` 定位 203 行，再逐行檢查 `total_amount` 過濾掉 191 行。如果 `(user_id, total_amount)` composite index 可以省掉這 191 行的回表。

#### 優化方向

1. **Heap Fetches 太多** → 考慮 covering index（`INCLUDE` 或擴大 index 欄位）
2. **Filter 過濾比例高** → 加上 composite index 把 Filter 變成 Index Cond
3. **大量 random I/O** → 如果回表行數佔比 > 10%，考慮讓 planner 走 Bitmap Scan

---

### 3.3 Index Only Scan（純索引掃描）

#### 一句話解釋

所有需要的欄位都在 index 裡面，連 heap 都不用去，直接從 index 返回結果。

#### 內部原理

```
┌──────────────────────┐
│  B-tree Index        │
│                      │
│  index on:           │
│    (user_id, email,  │  ← SELECT 的欄位全在 index 裡
│     created_at)      │
│                      │
│  [leaf page]         │
│   │─ entry: (4823,   │
│   │   'alice@...',   │
│   │   '2026-01-01')  │────→ 直接返回，不訪問 heap
│   │─ entry: (...)    │
└──────────────────────┘
         ↑
    但要檢查 visibility map：
    這個 page 上的所有 tuple 是否對所有 transaction 都可見？
      ├─ YES → 不回表（真正 Index Only）
      └─ NO  → 需回表檢查 tuple header 的 xmin/xmax（Heap Fetch）
```

#### 關鍵條件

| 條件 | 說明 |
|------|------|
| Covering Index | SELECT 的所有欄位 + WHERE 的所有欄位都在同一個 index 中 |
| Visibility Map 乾淨 | 該 page 沒有 dead tuple，或 dead tuple 已被 `VACUUM` 清理並標記為全可見 |

#### 實戰 EXPLAIN 範例

```sql
-- 有 index: idx_users_email_created (email, created_at)
EXPLAIN (ANALYZE, BUFFERS)
SELECT email, created_at FROM users WHERE email = 'alice@example.com';
```

```
Index Only Scan using idx_users_email_created on users
    (cost=0.42..4.44 rows=1 width=36)
    (actual time=0.030..0.032 rows=1 loops=1)
   Index Cond: (email = 'alice@example.com'::text)
   Heap Fetches: 0
   Buffers: shared hit=4
 Planning Time: 0.098 ms
 Execution Time: 0.050 ms
```

**解讀**：`Heap Fetches: 0` — 完美，完全沒碰 heap。0.05ms。

```sql
-- 同一張表，但 VACUUM 很久沒跑
EXPLAIN (ANALYZE, BUFFERS)
SELECT email, created_at FROM users WHERE email = 'alice@example.com';
```

```
Index Only Scan using idx_users_email_created on users
    (cost=0.42..4.44 rows=1 width=36)
    (actual time=0.030..0.056 rows=1 loops=1)
   Index Cond: (email = 'alice@example.com'::text)
   Heap Fetches: 1
   Buffers: shared hit=4 read=1
 Planning Time: 0.098 ms
 Execution Time: 0.072 ms
```

**解讀**：`Heap Fetches: 1` — 有 dead tuple，被迫回表檢查可見性。差距不大（一行而已），但高併發場景下堆積大量 dead tuple 會顯著拖慢 Index Only Scan。

#### 優化方向

1. 確保 **VACUUM** 頻率足夠（特別是高 UPDATE/DELETE 的表）
2. 調整 `autovacuum_vacuum_scale_factor` 讓 vacuum 更頻繁觸發
3. 對於 append-only 的表（只 INSERT 不 UPDATE/DELETE），Index Only Scan 幾乎永遠是 0 Heap Fetch

#### 面試加分金句

> "Index Only Scan 並非真的永不訪問 heap。visibility map 只能告訴你 page-level 的可見性。如果 page 上有任何 dead tuple，PostgreSQL 還是要回 heap 檢查每個 tuple 的 xmin/xmax。"

---

### 3.4 Bitmap Index Scan + Bitmap Heap Scan（點陣圖掃描）

#### 一句話解釋

兩階段掃描：(1) 從 index 中收集符合條件的 page 號碼並壓縮成 bitmap，(2) 按物理順序讀取這些 page，把 random I/O 變成 sequential I/O。

#### 內部原理

```
Step 1: Bitmap Index Scan
┌─────────────────────┐
│  B-tree Index       │
│  WHERE status =     │
│    'confirmed'      │
│  ↓                  │
│  matching entries:  │
│  page 5, tuple 2    │
│  page 5, tuple 7    │──→  Build Bitmap
│  page 12, tuple 1   │    ┌────────────────┐
│  page 12, tuple 9   │    │ page 5:  001000│
│  page 88, tuple 3   │    │ page 12: 010001│
│  ...                │    │ page 88: 000100│
└─────────────────────┘    │ ...            │
                           └───────┬────────┘
                                   │
Step 2: Bitmap Heap Scan          ▼
┌──────────────────────────────────────┐
│  Table Heap                          │
│  Read page 5  → check tuple 2,7      │
│  Read page 12 → check tuple 1,9      │  ← sequential order!
│  Read page 88 → check tuple 3        │
│  ...                                 │
│  Recheck Cond (重新檢查 WHERE 條件)   │  ← 因為 bitmap 可能不精確
└──────────────────────────────────────┘
```

#### 為什麼要兩階段

| 問題 | Bitmap 的解法 |
|------|--------------|
| Index Scan 回表太多 = 大量 random I/O | 先收集 page 號碼，按物理順序讀 = sequential I/O |
| 多個 index 可用（WHERE a OR b） | 對兩個 index 各建 bitmap → bitmap OR → 一次 heap scan |
| 複合條件（WHERE a AND b） | 對兩個 index 各建 bitmap → bitmap AND → 一次 heap scan |

#### 什麼時候出現

- 查詢選擇率中等（回表行數佔比 1~10%）
- `WHERE ... OR ...` 可以使用多個 index
- `WHERE col IN (...)` 有多個值

#### 實戰 EXPLAIN 範例

```sql
-- 兩個獨立的 index: idx_status, idx_created_at
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE status = 'confirmed' OR created_at > '2026-06-01';
```

```
Bitmap Heap Scan on orders
    (cost=358.12..2023.45 rows=12340 width=40)
    (actual time=5.678..23.456 rows=11892 loops=1)
   Recheck Cond: ((status = 'confirmed'::text)
               OR (created_at > '2026-06-01 00:00:00+08'::timestamptz))
   Heap Blocks: exact=834
   Buffers: shared hit=67 read=821
   ->  BitmapOr
         (cost=358.12..358.12 rows=12400 width=0)
         (actual time=5.123..5.125 rows=0 loops=1)
         ->  Bitmap Index Scan on idx_orders_status
             (cost=0.00..145.23 rows=6200 width=0)
             (actual time=2.891..2.891 rows=5892 loops=1)
               Index Cond: (status = 'confirmed'::text)
         ->  Bitmap Index Scan on idx_orders_created_at
             (cost=0.00..206.72 rows=6200 width=0)
             (actual time=2.229..2.229 rows=6123 loops=1)
               Index Cond: (created_at > '2026-06-01 00:00:00+08'::timestamptz)
 Planning Time: 0.234 ms
 Execution Time: 25.123 ms
```

**解讀**：planner 發現兩個 index 都有用，做 `BitmapOr` 合併兩個 bitmap，再一次 `Bitmap Heap Scan` 讀 heap。比起走單個 index 再 Filter，這個策略可以省掉大量 random I/O。

#### 關鍵指標

| 指標 | 說明 |
|------|------|
| `Heap Blocks: exact=N` | 從 bitmap 中確定的 page 數量。N 小 = bitmap 精確 |
| `Heap Blocks: lossy=N` | bitmap 精度不夠，整個 page 都要檢查（`work_mem` 太小） |

#### `work_mem` 與 lossy bitmap

當 bitmap 所需的記憶體超過 `work_mem` 時，PostgreSQL 會降級為 **lossy bitmap**：每個 bit 不再代表一個 tuple，而是代表一整個 page（8KB）。這導致 `Bitmap Heap Scan` 要掃描整個 page，然後 `Recheck Cond` 再逐行過濾，效率降低。

**解法**：加大 `work_mem`（對單次查詢 `SET work_mem = '256MB'`）。

---

### 3.5 Parallel Seq Scan（並行全表掃描）

#### 一句話解釋

把 Seq Scan 的工作切給多個 background worker 同時做，最後由 leader process（Gather 節點）彙總結果。

#### 內部原理

```
┌────────────────────────────────────────────┐
│  Parallel Seq Scan on big_table            │
│                                            │
│  Worker 1:  page 0    → page 3333          │
│  Worker 2:  page 3334 → page 6666  ────┐   │
│  Worker 3:  page 6667 → page 9999      │   │
│                                        │   │
│  (Leader 通常不掃描，只做 Gather)       │   │
└────────────────────────────────────────┘   │
                                             │
          ┌──────────────────────────────────┘
          ▼
┌─────────────────────┐
│  Gather             │  ← 彙總所有 worker 的 rows
│  Workers Planned: 3 │
│  Workers Launched: 3│
└─────────────────────┘
```

#### 觸發條件

| 條件 | 說明 |
|------|------|
| 表大小 > `min_parallel_table_scan_size`（預設 8MB） | 太小沒必要 parallel |
| `max_parallel_workers_per_gather > 0` | 預設 2，可調大 |
| 查詢沒有寫入操作 | SELECT only |
| 查詢不在 `FOR SHARE/UPDATE` 內 | locking 查詢不適用 |
| 查詢不是 CTE 的一部分 | CTE 內部通常不 parallel（PG 12+ 會 inline 的除外） |

#### 實戰 EXPLAIN 範例

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) FROM events WHERE created_at > '2026-01-01';
```

```
Finalize Aggregate
    (cost=8234.56..8234.57 rows=1 width=8)
    (actual time=245.123..245.124 rows=1 loops=1)
   Buffers: shared hit=234 read=1234
   ->  Gather
       (cost=8234.12..8234.53 rows=3 width=8)
       (actual time=244.891..245.115 rows=3 loops=1)
         Workers Planned: 3
         Workers Launched: 3
         Buffers: shared hit=234 read=1234
         ->  Partial Aggregate
             (cost=7234.12..7234.13 rows=1 width=8)
             (actual time=238.456..238.457 rows=1 loops=3)
             ->  Parallel Seq Scan on events
                 (cost=0.00..6890.34 rows=137478 width=0)
                 (actual time=0.456..189.234 rows=110032 loops=3)
                   Filter: (created_at > '2026-01-01 ...')
                   Rows Removed by Filter: 39890
                   Buffers: shared hit=234 read=1234
 Planning Time: 0.345 ms
 Execution Time: 245.234 ms
```

**解讀**：3 個 worker，每個掃描約 15 萬行（總共 45 萬行）。`Partial Aggregate` = 每個 worker 各自 COUNT 自己的部分。`Finalize Aggregate` = leader 把各個 partial count 加總。

#### 注意

- `Workers Launched < Workers Planned` → 系統的 parallel worker 不夠用，考慮調高 `max_parallel_workers`
- Parallel Scan 不等於一定比 Index Scan 快。如果查詢選擇性高（返回很少行），single Index Scan 可能更快
- 不是所有查詢都適合 parallel — 高選擇性查詢 + 好 index > Parallel Seq Scan

---

## 4. Planner 的選擇邏輯

PostgreSQL 的 cost-based optimizer 如何決定使用哪種 Scan？

### 決策參數

| 參數 | 預設值 | 影響 |
|------|--------|------|
| `seq_page_cost` | 1.0 | 一次 sequential page read 的成本 |
| `random_page_cost` | 4.0 | 一次 random page read 的成本（SSD 可調為 1.1~2.0） |
| `cpu_tuple_cost` | 0.01 | 處理一個 row 的 CPU 成本 |
| `cpu_index_tuple_cost` | 0.005 | 處理一個 index entry 的 CPU 成本 |
| `cpu_operator_cost` | 0.0025 | 執行一次運算（如 `>`, `=`, `+`）的 CPU 成本 |
| `effective_cache_size` | 4GB | planner 對 OS + PG buffer cache 的估算，影響 index vs seq scan 的抉擇 |

### 選擇流程圖

```
Query comes in
        │
        ▼
┌─ Is there any usable index?
│      │
│      ├── NO ──────────→ Seq Scan (or Parallel Seq Scan if table is large)
│      │
│      └── YES
│            │
│            ▼
│   ┌─ SELECT columns ⊆ index columns?
│   │      │
│   │      └── YES → consider Index Only Scan
│   │                  (still dependent on selectivity below)
│   │
│   └─ Estimate selectivity (how many rows match?)
│            │
│      ┌─────┼─────────────┐
│      ▼     ▼             ▼
│    < 1%   1~10%        > 10%
│      │     │             │
│      ▼     ▼             ▼
│   Index   Bitmap       Seq Scan
│   Scan    Index+Heap   (or Parallel)
│            Scan
│
└─> Final decision: compare total cost (cost=...)
    of each path. Pick the lowest.
```

### 實際驗證：強制指定 Scan 類型

```sql
-- 測試：強制關掉所有 scan 類型，看看 planner 選什麼
SET enable_seqscan = off;       -- 禁用 Seq Scan
SET enable_indexscan = off;     -- 禁用 Index Scan
SET enable_bitmapscan = off;    -- 禁用 Bitmap Scan
SET enable_indexonlyscan = off; -- 禁用 Index Only Scan

-- 跑 EXPLAIN 看 planner 被逼著選什麼

-- 恢復預設
RESET enable_seqscan;
RESET enable_indexscan;
RESET enable_bitmapscan;
RESET enable_indexonlyscan;
```

> 這招在 debug 時很有用：如果你認為某個 index 應該被用到但沒被用到，可以 `SET enable_seqscan = off` 強制走 index，觀察 cost 變化。

---

## 5. 其他 Scan Type 速查

| Scan Type | 觸發場景 | 範例 |
|-----------|---------|------|
| **Parallel Index Scan** | PG 11+，parallel worker 走 B-tree index | 大表 + 有 index + planner 認為值得 parallel |
| **TID Scan** | 直接指定 ctid（實體行位置）| `WHERE ctid = '(0,1)'` 或 bitmap scan 轉 TID scan |
| **Function Scan** | 查詢 set-returning function | `SELECT * FROM generate_series(1, 100)` |
| **Values Scan** | 掃描 VALUES 子句 | `SELECT * FROM (VALUES (1,'a'), (2,'b')) AS t` |
| **Subquery Scan** | 子查詢的包裝節點 | `SELECT * FROM (SELECT ... ) AS sub`（通常被 planner 優化掉） |
| **CTE Scan** | 掃描已物化的 CTE 結果 | `WITH cte AS (...) SELECT * FROM cte` |
| **WorkTable Scan** | 遞迴 CTE 中掃描上一步結果 | `WITH RECURSIVE ...` 內部的 work table |
| **Foreign Scan** | 掃描 foreign table（FDW）| `SELECT * FROM remote_users`（postgres_fdw） |
| **Custom Scan** | Extension 自定義掃描 | 如 `pg_bigm` 的全文檢索 custom scan |

---

## 6. 實戰判斷流程

拿到一個 slow query 的 EXPLAIN 輸出時，依以下順序排查：

```
1. 找最內層的 Scan Node（葉子節點）
        │
        ▼
2. 是什麼 Scan 類型？
   ├─ Seq Scan on <large_table> ──→ 缺 index / index 失效 / 選擇率太高
   ├─ Index Scan + 大量 Heap Fetches ──→ 考慮 covering index
   ├─ Index Scan + Filter 過濾掉很多行 ──→ 考慮 composite index
   ├─ Nested Loop 內側有 Scan ──→ 缺 JOIN key 的 index
   └─ Bitmap Heap Scan + lossy ──→ work_mem 太小
        │
        ▼
3. 看 actual time 和 rows
   ├─ rows=1 但 Rows Removed by Filter=1,000,000 ──→ 嚴重浪費
   ├─ loops=5000（在 Nested Loop 內側）──→ 加 index 減少每次掃描成本
   └─ Heap Fetches >> actual rows ──→ visibility map 問題（VACUUM）
        │
        ▼
4. 看 Buffers
   ├─ shared read 很大 ──→ 資料不在 memory，I/O bound
   ├─ shared hit 為主 ──→ 資料在 cache，瓶頸在 CPU 或 plan 本身
   └─ temp read/write ──→ work_mem 不足，spill to disk
        │
        ▼
5. 提出優化方案：
   ├─ CREATE INDEX ...
   ├─ 改寫查詢（減少函數包裹、改 cursor pagination）
   ├─ VACUUM / ANALYZE
   ├─ 調整 work_mem / shared_buffers
   └─ 硬體升級（最後手段）
```

---

## 7. 常見效能陷阱與解法

### 陷阱 1：函數包裹 Indexed Column

```sql
-- 慢：index 失效
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';

-- 解法 A：expression index
CREATE INDEX idx_users_lower_email ON users (LOWER(email));

-- 解法 B：應用層保證 email 存小寫，查詢直接
SELECT * FROM users WHERE email = 'alice@example.com';
```

### 陷阱 2：LIKE 前綴萬用字元

```sql
-- 慢：index 失效（B-tree 無法加速 '%...'）
SELECT * FROM products WHERE name LIKE '%shoes%';

-- 解法：使用全文檢索（GIN index + tsvector）
CREATE INDEX idx_products_name_gin ON products USING GIN (to_tsvector('english', name));
SELECT * FROM products WHERE to_tsvector('english', name) @@ to_tsquery('shoes');

-- 或使用 pg_trgm extension 做模糊匹配
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_products_name_trgm ON products USING GIN (name gin_trgm_ops);
```

### 陷阱 3：隱式型別轉換

```sql
-- id 是 bigint，但查詢傳入 text
SELECT * FROM orders WHERE id = '12345';
-- 實際上 PostgreSQL 會轉換：WHERE id::text = '12345'
-- 導致 index 失效！

-- 解法：傳入正確型別
SELECT * FROM orders WHERE id = 12345;
```

### 陷阱 4：Composite Index 順序錯誤

```sql
-- index (status, created_at, user_id)
-- 這個查詢用不到 index
SELECT * FROM events WHERE user_id = 4823 AND created_at > '2026-01-01';

-- 正確的 index（equality 先，range 後）
CREATE INDEX idx_events_user_created ON events (user_id, created_at);
```

### 陷阱 5：OFFSET 大值

```sql
-- 慢
SELECT * FROM orders ORDER BY id OFFSET 100000 LIMIT 20;

-- 解法：cursor-based pagination
SELECT * FROM orders WHERE id > 100000 ORDER BY id LIMIT 20;
```

### 陷阱 6：N+1 in Nested Loop

```
Nested Loop  (loops=5000)
  ├─ Index Scan on orders       (1 次)
  └─ Seq Scan on order_items    (5000 次！)
```

解法：在 `order_items.order_id` 建立 index，讓內側變成 Index Scan。

### 陷阱 7：忘記 VACUUM / ANALYZE

```sql
-- 定期執行
VACUUM ANALYZE users;
```

- `ANALYZE`：更新統計資訊（planner 依此做決策），沒有統計資訊 planner 亂選 plan
- `VACUUM`：清理 dead tuple，讓 Index Only Scan 能真正 skip heap

---

## 延伸閱讀

- [PostgreSQL Official - Using EXPLAIN](https://www.postgresql.org/docs/current/using-explain.html)
- [PostgreSQL Official - Planner Cost Constants](https://www.postgresql.org/docs/current/runtime-config-query.html#RUNTIME-CONFIG-QUERY-CONSTANTS)
- [PostgreSQL Official - Index Types](https://www.postgresql.org/docs/current/indexes-types.html)
- [use-the-index-luke.com](https://use-the-index-luke.com/) — 經典 SQL indexing 教學
