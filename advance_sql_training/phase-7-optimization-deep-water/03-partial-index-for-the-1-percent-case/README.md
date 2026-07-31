# Phase 7-03 — Partial Index for the 1% Case

> **難度**：★★★★☆
> **核心技巧**：Partial Index、Expression Index、索引體積與寫入成本
> **對應基礎題**：[sql_training Phase 7 Scenario 01](../../../sql_training/phase-7/scenario-01-index-failure)（函數包住欄位讓索引失效）

<br>

---

<br>

## Interview Context

> *面試官：*「我們的工單表有 100 萬筆，其中只有 **1% 是待處理**的。
>
> 所有的後台查詢都只關心那 1%。但我們的索引蓋了全部 100 萬筆 —— 每次寫入都要維護它，佔 30 MB 記憶體。
>
> **有沒有辦法只索引那 1%？**
>
> 順便，我們還有一個 `lower(email)` 的查詢一直走全表掃描。也一起解決。」

<br>

[7-01](../01-the-query-that-got-slower-after-adding-an-index) 的修法 B 你已經用過部分索引了。這一題把它系統化：**什麼時候用、省下多少、代價是什麼**。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS tickets;

CREATE TABLE tickets (
    id         BIGSERIAL PRIMARY KEY,
    status     TEXT NOT NULL,
    assignee   INT,
    created_at TIMESTAMPTZ NOT NULL,
    body       TEXT NOT NULL
);

INSERT INTO tickets (status, assignee, created_at, body)
SELECT 'closed', (random()*99+1)::int, now() - (random()*interval '180 days'), repeat('x',50)
FROM generate_series(1, 990000);

INSERT INTO tickets (status, assignee, created_at, body)
SELECT 'open', (random()*99+1)::int,
       now() - interval '180 days' - (random()*interval '185 days'), repeat('x',50)
FROM generate_series(1, 10000);

ANALYZE tickets;

-- Part C 用
DROP TABLE IF EXISTS users7;
CREATE TABLE users7 (id SERIAL PRIMARY KEY, email TEXT NOT NULL);
INSERT INTO users7 (email) SELECT 'User'||g||'@Example.COM' FROM generate_series(1, 500000) g;
CREATE INDEX idx_email ON users7 (email);
ANALYZE users7;
```

<br>

---

<br>

## Part A — 體積

### A1

建立三種索引，比較體積：

```sql
CREATE INDEX idx_full      ON tickets (created_at);
CREATE INDEX idx_composite ON tickets (status, created_at DESC);
CREATE INDEX idx_partial   ON tickets (created_at DESC) WHERE status = 'open';

SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes WHERE relname = 'tickets'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**實測**：

```
    indexrelname     |  size
---------------------+--------
 idx_composite       | 30 MB
 tickets_pkey        | 21 MB
 idx_full            | 21 MB
 idx_partial         | 240 kB      ← 1/125
```

### A2

回答：
- 為什麼部分索引只有 240 kB？
- 為什麼複合索引（30 MB）比單欄索引（21 MB）**更大**？
- 索引小帶來哪些好處？列出至少四個。

### A3 — 效能一樣嗎

對 [7-01](../01-the-query-that-got-slower-after-adding-an-index) 的那個查詢，三種索引的 `Buffers` 分別是：

| 索引 | Buffers |
|------|---------|
| `idx_full` | 989,954 |
| `idx_composite` | 13 |
| `idx_partial` | **12** |

**部分索引用 1/125 的體積，達到一樣（甚至更好）的效能。**

自己驗證一次。

<br>

---

<br>

## Part B — 部分索引的規則

### B1 — 什麼時候 planner 會用它

部分索引只有在 planner **能證明查詢條件蘊含索引條件**時才會被使用。

測試以下查詢，記錄哪些用得到 `idx_partial`：

| 查詢 | 用得到嗎 |
|------|---------|
| `WHERE status = 'open'` | ? |
| `WHERE status = 'open' AND assignee = 5` | ? |
| `WHERE status <> 'closed'` | ? |
| `WHERE status IN ('open','pending')` | ? |
| `WHERE status = $1`（prepared statement 參數） | ? |
| 沒有 `status` 條件 | ? |

**第三個和第五個特別注意。**

第五個要多做一步 —— 用 `PREPARE` 建一個帶參數的語句，`EXPLAIN EXECUTE` 跑**七次**，然後再跑一次：

```sql
SET plan_cache_mode = force_generic_plan;
EXPLAIN EXECUTE your_stmt('open');
```

**兩種情況的答案不一樣。** 想清楚為什麼，這是實務上最容易中的陷阱。

### B2 — 寫入成本

回答：
- 插入一筆 `status='closed'` 的工單，`idx_partial` 需要更新嗎？
- 插入 `status='open'` 呢？
- 把一筆工單從 `open` 改成 `closed`，索引會發生什麼事？
- **在「99% 寫入都是 closed」的系統裡，部分索引省下多少寫入成本？**

### B3 — 適用判準

**寫出判準**：什麼樣的欄位/查詢適合用部分索引？

考慮這些面向：
- 過濾條件的選擇率
- 條件是否穩定（會不會常常改）
- 查詢是否**總是**帶那個條件

### B4 — 反例

舉出一個**不適合**用部分索引的情境，並說明為什麼。

<br>

---

<br>

## Part C — Expression Index

### C1 — 函數包住欄位

```sql
SELECT id FROM users7 WHERE lower(email) = 'user42@example.com';
```

即使 `email` 上有索引，實測結果：

```
Gather  (cost=1000.00..8051.00 rows=2500 width=4)
  ->  Parallel Seq Scan on users7
        Filter: (lower(email) = 'user42@example.com'::text)
```

**索引完全沒被用到。**

回答：為什麼？（提示：索引裡存的是 `email` 的值，不是 `lower(email)` 的值）

### C2 — 表達式索引

```sql
CREATE INDEX idx_email_lower ON users7 (lower(email));
ANALYZE users7;
```

實測：

```
Index Scan using idx_email_lower on users7  (cost=0.42..8.44 rows=1 width=4)
  Index Cond: (lower(email) = 'user42@example.com'::text)
```

**成本從 8051 降到 8.44。**

回答：
- 表達式索引裡實際存的是什麼？
- 查詢的寫法必須**完全符合**索引的表達式嗎？測試 `WHERE lower(email) LIKE 'user42%'` 用不用得到。
- **表達式必須是 `IMMUTABLE` 的** —— 為什麼？`now()` 可以進表達式索引嗎？

### C3 — 兩者結合

寫出一個**同時是部分索引和表達式索引**的 DDL，例如：

> 只對「未刪除」的使用者，建立 email 小寫的唯一索引

```sql
CREATE UNIQUE INDEX ... ON users7 (lower(email)) WHERE deleted_at IS NULL;
```

回答：這個索引同時達成了哪幾件事？

### C4 — 替代方案

回答：
- 用 `CITEXT` 型別（大小寫不敏感的 text）取代 `lower()` 索引，有什麼優缺點？
- 直接在寫入時就存小寫（多一個 `email_lower` 欄位 + 一般索引）呢？
- **三種做法你選哪個？**

<br>

---

<br>

## Part D — 索引審查

### D1 — 找出沒用的索引

```sql
SELECT relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelid NOT IN (SELECT conindid FROM pg_constraint)
ORDER BY pg_relation_size(indexrelid) DESC;
```

回答：
- `idx_scan = 0` 代表什麼？可以直接刪嗎？
- **有什麼陷阱？**（提示：統計是從什麼時候開始累積的？有沒有可能是季度報表才用的索引？）
- 刪之前你會做什麼確認？

### D2 — 找出重複的索引

`(a)` 和 `(a, b)` 兩個索引，前者是多餘的嗎？

- 什麼情況下 `(a)` 可以刪掉？
- 什麼情況下不能？（提示：索引大小、Index Only Scan）

### D3 — 索引策略

寫出一份**索引設計檢查表**，涵蓋：
- 加索引前要問什麼
- 什麼時候用部分索引
- 什麼時候用表達式索引
- 什麼時候用複合索引，欄位怎麼排序
- 怎麼定期審查

<br>

---

<br>

## 面試官的追問

> 1. 「部分索引的條件可以引用其他欄位嗎？可以用子查詢嗎？」
>
> 2. 「唯一部分索引（`CREATE UNIQUE INDEX ... WHERE ...`）和 `EXCLUDE` 約束有什麼關係？」
>    （回想 [Phase 6-01](../../phase-6-dml-concurrency/01-the-idempotent-upsert) 和 [6-03](../../phase-6-dml-concurrency/03-preventing-double-booking)）
>
> 3. 「表達式索引會影響 `ANALYZE` 收集統計的方式嗎？」
>
> 4. 「如果部分索引的條件欄位被 `UPDATE` 了，索引怎麼維護？成本比一般索引高還是低？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼複合索引比單欄索引大</summary>

- `idx_full (created_at)`：100 萬個項目 × (8 bytes timestamptz + 6 bytes tid + overhead)
- `idx_composite (status, created_at DESC)`：100 萬個項目，**每個多存一個 `status` 字串**（'closed' 是 6 bytes + varlena header）

多存的那一欄乘以 100 萬列 → **多出約 9 MB**。

- `idx_partial ... WHERE status='open'`：**只有 1 萬個項目** → 1/100 的體積

**索引小的好處**：
1. **佔用 shared_buffers 少** → 更可能整個索引都在記憶體裡 → 查詢不碰磁碟
2. **寫入時要維護的頁面少** → INSERT/UPDATE 更快
3. **`VACUUM` 掃描更快** → 維護視窗更短
4. **備份/複本傳輸量更小**
5. 樹的層數可能更少 → 每次查找少一次 I/O

</details>

<details>
<summary>Hint 2 — planner 什麼時候用得到部分索引</summary>

| 查詢 | 用得到 | 原因 |
|------|--------|------|
| `status = 'open'` | ✅ | 完全符合索引條件 |
| `status = 'open' AND assignee = 5` | ✅ | 蘊含索引條件（更嚴格） |
| `status <> 'closed'` | ❌ | planner **無法證明** `<> 'closed'` 蘊含 `= 'open'`（可能還有其他值） |
| `status IN ('open','pending')` | ❌ | 同上，`pending` 不在索引裡 |
| `status = $1`（參數） | **看情況** | 見下方 |
| 無 `status` 條件 | ❌ | 顯然 |

**關鍵**：planner 必須在**產生計畫時**就能**靜態證明**「查詢條件 ⟹ 索引條件」。

<br>

**第五個的完整答案（實測）**：

PostgreSQL 對 prepared statement 有兩種計畫模式：

- **Custom plan**：每次執行都帶入**實際參數值**重新規劃 → 知道 `$1='open'` → **用得到部分索引** ✅
- **Generic plan**：規劃一次、重複使用，**不知道 `$1` 是什麼** → **用不到部分索引** ❌

實測：預設的 `plan_cache_mode = auto` 之下，即使執行七次，PostgreSQL 仍然**持續選擇 custom plan** —— 因為它會比較兩者成本，發現 custom plan 便宜太多（29 vs 19494），就不切換。

但強制走 generic plan：

```sql
SET plan_cache_mode = force_generic_plan;
```

計畫立刻退化成 **Parallel Seq Scan**。

**實務意義**：這不是「一定會中」的陷阱，而是**「可能會中」的陷阱**。當你的部分索引在某些環境突然失效，`plan_cache_mode` 和連線池的 prepared statement 行為是第一個要查的地方。

</details>

<details>
<summary>Hint 2b — 為什麼 PostgreSQL 沒切換到 generic plan</summary>

PostgreSQL 的規則（`plan_cache_mode = auto`）：

1. 前 5 次執行**一律用 custom plan**，記錄平均成本
2. 第 6 次開始產生一次 generic plan，比較成本
3. **只有當 generic plan 的成本不明顯高於 custom plan 的平均成本時，才改用 generic plan**

本題 custom plan 成本 29、generic plan 成本 19494 —— 差 670 倍，所以 PostgreSQL **永遠不會切換**。

**這是好消息**：資料分布極端不均時，PostgreSQL 會自動保護你。

**但仍要小心**：如果分布沒那麼極端（例如 custom 100 vs generic 150），它就會切過去，而你的部分索引就靜靜地不再被使用。

</details>

<details>
<summary>Hint 3 — 表達式索引為什麼要 IMMUTABLE</summary>

索引是**預先算好並存起來**的。`CREATE INDEX ON t (f(col))` 會對每一列算一次 `f(col)` 存進索引。

如果 `f` 的結果會變（不是 `IMMUTABLE`），索引裡存的值就會和真實值不一致 → **查詢結果錯誤**，而且不會有任何錯誤訊息。

```sql
CREATE INDEX ON orders (age(now(), created_at));
-- ERROR: functions in index expression must be marked IMMUTABLE
```

`now()` 是 `STABLE`（同一個交易內固定，但跨交易會變）→ 被拒絕。

**`lower()` 是 `IMMUTABLE` 嗎？** 對 `text` 是的。但要小心 —— 如果資料庫的 locale/collation 改變，`lower()` 的結果理論上可能改變，所以改 collation 之後**必須 `REINDEX`**。

**C2 的 `LIKE` 測試**：

先查你的資料庫 collation：

```sql
SELECT datcollate FROM pg_database WHERE datname = current_database();
```

- **collation 是 `C`**（本題的測試環境）→ `WHERE lower(email) LIKE 'user42%'` **直接就能用普通的表達式索引** ✅
- **collation 是 `en_US.UTF-8` 之類**（多數真實部署）→ **用不到**，必須額外建：

```sql
CREATE INDEX ON users7 (lower(email) text_pattern_ops);
```

加了 `text_pattern_ops` 之後，`EXPLAIN` 會顯示特殊的 pattern 運算子：

```
Index Cond: ((lower(email) ~>=~ 'user42'::text) AND (lower(email) ~<~ 'user43'::text))
```

`~>=~` / `~<~` 是**逐位元組比較**的運算子 —— 它繞開了 locale 的排序規則，所以前綴比對才成立。

**這是很多人踩過的坑**：本機開發用 C collation 一切正常，上正式環境（UTF-8 collation）索引就失效了。**檢查 collation 是排查「索引在某環境不生效」的必查項。**

</details>

<details>
<summary>Hint 4 — D1 的陷阱與 D2 的重複索引</summary>

**D1 陷阱**：

`pg_stat_user_indexes.idx_scan` 是**從上次 `pg_stat_reset()` 或資料庫啟動以來**的累計值。

刪之前必須確認：
1. **統計累積多久了？** 查 `pg_stat_get_db_stat_reset_time()`。如果昨天才重設，那 `idx_scan=0` 什麼都不代表。
2. **有沒有季度/年度的批次任務會用到？** 統計只涵蓋一個月的話，季報用的索引會被誤判。
3. **是不是唯一約束的支撐索引？** 那些不能刪（查詢已經排除了 `pg_constraint`，但要確認）。
4. **複本上的使用狀況？** 主庫的統計不包含只讀複本上的查詢。

**安全做法**：先 `ALTER INDEX ... SET (deprecated)` ——沒有這個語法，所以實務上是：先在低峰期 `DROP INDEX CONCURRENTLY`，但**先把 DDL 存好以便快速重建**。

**D2 重複索引**：

`(a)` 在有 `(a, b)` 的情況下**通常**是多餘的 —— 最左前綴讓 `(a, b)` 能服務所有 `(a)` 的查詢。

**但不一定能刪**：
- `(a)` 更小 → 如果 `WHERE a = ?` 是熱查詢，小索引的快取命中率更好
- **Index Only Scan**：`SELECT a FROM t WHERE a = ?` 用 `(a)` 可以 index-only；用 `(a,b)` 也可以，但要讀更寬的項目
- `(a)` 如果是 `UNIQUE`，那它同時是約束，不能因為「多餘」就刪

</details>
