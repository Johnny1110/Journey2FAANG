# Phase 7-01 — The Query That Got Slower After Adding an Index

> **難度**：★★★★★
> **核心技巧**：`LIMIT` + `ORDER BY` 的成本估算陷阱、資料分布與索引順序的相關性
> **對應基礎題**：[sql_training Phase 7 Scenario 01](../../../sql_training/phase-7/scenario-01-index-failure)（那題是「索引沒被用到」，這題是「索引被用了，然後更慢」）

<br>

---

<br>

## Interview Context

> *面試官：*「客服後台有個查詢：『**最新的 10 筆待處理工單**』。原本要 200ms，大家覺得慢。
>
> 工程師看了 `EXPLAIN`，發現有個 `Sort` 節點，就加了 `created_at` 的索引。
>
> 加完之後，這個查詢變成 **3 秒**。
>
> 他把索引砍掉，又回到 200ms。他現在完全搞不懂了。」

<br>

**這是「加了索引反而變慢」最經典的形態。** 而且它的可怕之處在於：`EXPLAIN` 的**成本估算看起來超級漂亮**。

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

-- 99 萬筆已關閉工單：都是「最近」的
INSERT INTO tickets (status, assignee, created_at, body)
SELECT 'closed', (random()*99+1)::int,
       now() - (random() * interval '180 days'), repeat('x',50)
FROM generate_series(1, 990000);

-- 1 萬筆待處理工單：都是「很舊」的（積壓已久沒人處理）
INSERT INTO tickets (status, assignee, created_at, body)
SELECT 'open', (random()*99+1)::int,
       now() - interval '180 days' - (random() * interval '185 days'), repeat('x',50)
FROM generate_series(1, 10000);

ANALYZE tickets;
```

<br>

> **這份資料的關鍵特徵**：`open` 的工單**全部都是最舊的**。
> 這不是我刻意刁難 —— 積壓的工單本來就是舊的，這是最真實的資料分布。

<br>

---

<br>

## The Query

```sql
SELECT id, created_at FROM tickets
WHERE status = 'open'
ORDER BY created_at DESC
LIMIT 10;
```

<br>

---

<br>

## Part A — 加索引前

### A1

先跑 `EXPLAIN (ANALYZE, BUFFERS)`，記錄：

```
 Limit  (cost=20746.78..20747.94 rows=10 width=16) (actual rows=10.00 loops=1)
   Buffers: shared hit=14362
   ->  Gather Merge  ...
         ->  Sort  (cost=19746.76..19757.24 rows=4195 width=16)
               Sort Key: created_at DESC
```

回答：
- 它用了什麼掃描方式？
- 那個 `Sort` 節點在做什麼？
- **`Buffers: shared hit=14362`** —— 記住這個數字。

<br>

---

<br>

## Part B — 加了索引之後

### B1

```sql
CREATE INDEX idx_tickets_created ON tickets (created_at);
ANALYZE tickets;
```

重跑同一個查詢：

```
 Limit  (cost=0.42..78.23 rows=10 width=16) (actual rows=10.00 loops=1)
   Buffers: shared hit=989954 read=2708 written=1838
   ->  Index Scan Backward using idx_tickets_created on tickets
       (cost=0.42..85584.24 rows=11000 width=16) (actual rows=10.00 loops=1)
         Filter: (status = 'open'::text)
         Rows Removed by Filter: 990000
```

**`Buffers` 從 14,362 變成 989,954 —— 增加了 69 倍。**

### B2 — 讀懂發生了什麼

回答：
- `Rows Removed by Filter: 990000` 是什麼意思？資料庫實際掃了幾列？
- 為什麼要掃這麼多？（提示：它從 `created_at` 最大的那一端往回走，一路找 `status='open'`）
- **`open` 的工單在 `created_at` 排序的哪一端？**

### B3 — planner 為什麼被騙

看 `Limit` 節點的成本：**`cost=0.42..78.23`**。

planner 認為這個查詢只要 78 個成本單位就能完成 —— 非常便宜，比 Part A 的 20746 便宜 265 倍。

回答：
- planner 是怎麼算出 78 這個數字的？（提示：它預期掃幾列就能湊滿 10 筆？）
- **planner 做了什麼假設？** 用一句話寫出來。
- 這個假設在本題的資料上錯得多離譜？
- **`Index Scan` 節點的總成本是 `0.42..85584.24`** —— 為什麼 `Limit` 只取了 78？

### B4 — 這類 bug 的特徵

回答：
- 為什麼工程師在**開發環境測不出來**？（提示：開發環境的資料通常是隨機生成的）
- 什麼樣的資料分布會觸發這個問題？寫出通用描述。
- **如果 `open` 的工單是「最新的」而不是「最舊的」，這個索引還會是災難嗎？** 自己改資料測一次。

<br>

---

<br>

## Part C — 兩種修法

### C1 — 修法 A：複合索引

```sql
CREATE INDEX idx_status_created ON tickets (status, created_at DESC);
```

實測：**`Buffers: shared hit=10 read=3`**

回答：
- 為什麼欄位順序是 `(status, created_at)` 而不是 `(created_at, status)`？
- 為什麼加了 `DESC`？不加會怎樣？
- 這個索引還能服務哪些查詢？（最左前綴原則）

### C2 — 修法 B：部分索引

```sql
CREATE INDEX idx_open_only ON tickets (created_at DESC) WHERE status = 'open';
```

實測：**`Buffers: shared hit=10 read=2`**

回答：
- 這個索引只包含哪些列？
- 效能和 C1 一樣好嗎？

### C3 — 體積對比（決定性的差異）

```sql
SELECT indexrelname, pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes WHERE relname = 'tickets';
```

實測結果：

```
         idx         |  size
---------------------+--------
 idx_status_created  | 30 MB      ← 複合索引
 tickets_pkey        | 21 MB
 idx_tickets_created | 21 MB      ← 那個害人的索引
 idx_open_only       | 240 kB     ← 部分索引
```

**部分索引只有複合索引的 1/125，效能卻一樣。**

回答：
- 為什麼差這麼多？
- 索引小有什麼好處？（至少三個）
- **什麼情況下你會選 C1 而不是 C2？**

### C4 — 三者並排

| | 無索引 | `(created_at)` | `(status, created_at DESC)` | 部分索引 |
|---|---|---|---|---|
| Buffers | 14,362 | **989,954** | 13 | **12** |
| 索引大小 | 0 | 21 MB | 30 MB | **240 kB** |
| 寫入成本 | 無 | ? | ? | ? |
| 能服務其他查詢嗎 | — | ? | ? | ? |

<br>

---

<br>

## Part D — 診斷方法論

### D1 — 怎麼提早發現

回答：如果你是 code reviewer，看到同事送出「加一個 `created_at` 索引」的 PR，你會問什麼問題？

### D2 — 上線後怎麼發現

回答：
- 用什麼監控指標能抓到這種退化？
- `pg_stat_statements` 的哪些欄位有用？
- **為什麼「平均執行時間」可能看不出來？**

### D3 — 緊急處理

正式環境已經因為這個索引掛掉了，你有 5 分鐘。

- 直接 `DROP INDEX` 安全嗎？會鎖住什麼？
- 有沒有不刪索引就能讓 planner 別用它的辦法？
- **寫出你的處置順序。**

<br>

---

<br>

## 面試官的追問

> 1. 「`Rows Removed by Filter` 這個欄位還能診斷出哪些問題？」
>
> 2. 「如果我把 `LIMIT 10` 改成 `LIMIT 1000`，planner 的選擇會變嗎？為什麼？」
>
> 3. 「`random_page_cost` 調整能改善這個問題嗎？」
>
> 4. 「PostgreSQL 有沒有辦法知道『`status` 和 `created_at` 是相關的』？」
>    （提示：這是 [7-05](../05-the-statistics-lie) 的主題 —— **但對這一題有用嗎？**）

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — planner 的致命假設</summary>

planner 看到 `WHERE status='open' ORDER BY created_at DESC LIMIT 10`，有兩個選擇：

**選項 A**：掃全表 → 過濾 → 排序 → 取 10 筆。成本 ≈ 20,747
**選項 B**：沿 `created_at` 索引倒著走 → 邊走邊過濾 → 湊滿 10 筆就停

對選項 B，planner 這樣推算：

- `status='open'` 的選擇率是 10000/1000000 = **1%**
- 要湊滿 10 筆，預期需要掃 `10 / 0.01` = **約 1000 列**
- 掃 1000 列的索引 + 回表 ≈ 成本 78

**成本 78 遠低於 20747，所以它選了 B。**

**致命假設**：planner 假設 `status='open'` 的列在 `created_at` 的排序上是**均勻分布**的 —— 平均每 100 列就會遇到一個 open。

**真實情況**：所有 open 都在最舊的那一端。從最新往回走，要走過 **990,000 列 closed** 才會碰到第一筆 open。

**planner 不知道「兩個欄位之間的相關性」** —— 它只有各欄位獨立的統計資訊。

</details>

<details>
<summary>Hint 2 — 為什麼開發環境測不出來</summary>

開發環境的假資料通常長這樣：

```sql
INSERT INTO tickets (status, created_at)
SELECT CASE WHEN random() < 0.01 THEN 'open' ELSE 'closed' END,
       now() - (random() * interval '365 days')
FROM generate_series(1, 1000000);
```

**`status` 和 `created_at` 各自隨機產生 → 兩者完全獨立 → planner 的假設完全正確 → 索引真的很快。**

正式環境的資料**永遠有相關性**：舊工單比較可能還沒處理、大客戶的訂單比較大、活躍用戶的登入比較密集。

**通用描述**：當「過濾條件的欄位」和「排序條件的欄位」之間**存在相關性**，而且相關的方向和排序方向**相反**時，`ORDER BY ... LIMIT` + 排序欄位索引就會災難性地慢。

**這是為什麼效能測試必須用真實資料分布（或匿名化的正式資料）。**

</details>

<details>
<summary>Hint 3 — 為什麼複合索引的欄位順序是 (status, created_at)</summary>

B-tree 複合索引 `(A, B)` 的資料是先按 A 排序、A 相同時按 B 排序。

**`(status, created_at DESC)`**：
- 索引裡所有 `status='open'` 的項目**連續存放**
- 而且在這個區段內已經按 `created_at DESC` 排好
- 查詢直接跳到 `status='open'` 的起點，往後讀 10 筆就結束 → **完美**

**`(created_at, status)`**：
- 先按時間排序，`status` 散落在各處
- 想找 `status='open'` 還是得掃 —— 和單欄 `created_at` 索引一樣爛

**`DESC` 的作用**：讓索引的實體順序就是查詢要的順序，避免 `Backward Scan`。
（PostgreSQL 的 B-tree 可以雙向掃描，所以不加 `DESC` 也能用，只是正向/反向掃描在 I/O 預取上有差異。明確寫出來意圖更清楚。）

**最左前綴**：`(status, created_at)` 也能服務 `WHERE status='open'`（單獨）的查詢，但**不能**服務 `WHERE created_at > ...`（單獨）的查詢。

</details>

<details>
<summary>Hint 4 — D3 緊急處置</summary>

**優先順序**：

1. **先讓查詢活過來，再談根治。**

2. **最快的一招：加正確的索引，不要先刪錯的**

   ```sql
   CREATE INDEX CONCURRENTLY idx_open_only ON tickets (created_at DESC) WHERE status='open';
   ANALYZE tickets;
   ```

   `CONCURRENTLY` 不鎖寫入（[Phase 6-06](../../phase-6-dml-concurrency/06-deduplicate-a-10m-row-table) 學過）。加完 planner 會自動改用更便宜的那個。

3. **然後才刪掉害人的索引**

   ```sql
   DROP INDEX CONCURRENTLY idx_tickets_created;
   ```

   `DROP INDEX`（不加 `CONCURRENTLY`）會取得 `ACCESS EXCLUSIVE` 鎖 —— **會擋掉所有對該表的查詢**，正式環境很危險。`DROP INDEX CONCURRENTLY` 才安全。

4. **不刪索引的臨時手段**：

   ```sql
   -- 只影響當前 session，用來驗證假設
   SET enable_indexscan = off;
   ```

   這只能用來**診斷**（確認「是不是這個索引害的」），不能當正式解法 —— 它會關掉該 session 所有的 index scan。

**面試加分**：主動說「我會先加對的索引再刪錯的，這樣中間沒有空窗期」。

</details>
