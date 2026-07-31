# Phase 7-04 — The Covering Index That Stopped Covering

> **難度**：★★★★☆
> **核心技巧**：Index Only Scan、`INCLUDE`、Visibility Map、`Heap Fetches`、`VACUUM` 的真正作用
> **對應基礎題**：[sql_training PostgreSQL Scan Types 教學](../../../sql_training/postgresql_scan_types.md)（Index Only Scan 那一段）

<br>

---

<br>

## Interview Context

> *面試官：*「我們有個查詢原本是 **Index Only Scan**，4 個 buffer 就跑完，超快。
>
> 上禮拜做了一次批次更新，改了 5% 的資料。從那之後同一個查詢變成 **113 個 buffer**，而且 `EXPLAIN` 顯示它**完全不用 Index Only Scan 了**。
>
> 索引沒動、查詢沒動、資料量也差不多。
>
> **發生什麼事？怎麼修？**」

<br>

**Index Only Scan 是 PostgreSQL 最快的存取方式，但它有一個隱形的前提條件** —— 而那個條件會被普通的 `UPDATE` 破壞。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS events7;

CREATE TABLE events7 (
    id         BIGSERIAL PRIMARY KEY,
    user_id    INT NOT NULL,
    status     TEXT NOT NULL,
    amount     NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

INSERT INTO events7 (user_id, status, amount, created_at)
SELECT (random()*9999+1)::int,
       CASE WHEN random() < 0.99 THEN 'done' ELSE 'pending' END,
       (random()*500)::numeric(10,2),
       now() - (random() * interval '365 days')
FROM generate_series(1, 1000000);

-- 覆蓋索引：查詢需要的欄位全部在索引裡
CREATE INDEX idx_cover ON events7 (user_id) INCLUDE (amount);

VACUUM ANALYZE events7;
```

<br>

## The Query

```sql
SELECT user_id, sum(amount) FROM events7 WHERE user_id = 42 GROUP BY user_id;
```

<br>

---

<br>

## Part A — 三個狀態

**依序執行這三步，每一步都跑 `EXPLAIN (ANALYZE, BUFFERS)` 並記錄。**

### A1 — 狀態一：乾淨的表

剛 `VACUUM` 完，實測：

```
->  Index Only Scan using idx_cover on events7  (actual rows=103.00 loops=1)
      Heap Fetches: 0
      Buffers: shared hit=4
```

也記錄 visibility map 的狀態：

```sql
SELECT relallvisible, relpages FROM pg_class WHERE relname = 'events7';
--  relallvisible = 7743 / relpages = 7743      ← 全部頁面都「全可見」
```

### A2 — 狀態二：更新 5% 的資料

```sql
UPDATE events7 SET amount = amount + 1 WHERE id % 20 = 0;
ANALYZE events7;
```

重跑查詢，實測：

```
->  Bitmap Heap Scan on events7  (actual rows=103.00 loops=1)
      Recheck Cond: (user_id = 42)
      Heap Blocks: exact=110
      Buffers: shared hit=113
```

```sql
SELECT relallvisible, relpages FROM pg_class WHERE relname = 'events7';
--  relallvisible = 0 / relpages = 7761         ← 歸零了
```

**注意：它不是「Index Only Scan 但 Heap Fetches 變高」，而是 planner 直接放棄了 Index Only Scan，改用 Bitmap Heap Scan。**

### A3 — 狀態三：VACUUM 之後

```sql
VACUUM ANALYZE events7;
```

實測：

```
->  Index Only Scan using idx_cover on events7  (actual rows=103.00 loops=1)
      Heap Fetches: 0
      Buffers: shared hit=4
--  relallvisible = 7761 / relpages = 7761
```

**4 → 113 → 4。** 完整的一個循環。

<br>

---

<br>

## Part B — 為什麼

### B1 — Index Only Scan 的前提

回答：
- 索引裡存了 `user_id` 和 `amount`（`INCLUDE`），查詢只要這兩欄 —— 那為什麼還需要碰 heap？
- **索引裡沒有存什麼？**（提示：MVCC 的可見性資訊）
- 所以 PostgreSQL 怎麼知道「索引裡的這一筆，對我這個交易是不是可見的」？

### B2 — Visibility Map

回答：
- Visibility Map 是什麼？它記錄什麼？
- 一個頁面在什麼條件下會被標記為 `all-visible`？
- `UPDATE` 為什麼會清掉那個標記？（提示：PostgreSQL 的 `UPDATE` 實際上做了什麼）
- **為什麼只改 5% 的列，`relallvisible` 卻從 7743 掉到 0？**

### B3 — `Heap Fetches` 的意義

回答：
- `Heap Fetches: 0` 代表什麼？
- 如果是 `Heap Fetches: 500` 呢？那還算「Index Only」Scan 嗎？
- **為什麼本題的 A2 完全看不到 `Heap Fetches`？**（提示：planner 做了什麼決定）

### B4 — planner 的成本模型

回答：
- planner 怎麼決定要不要用 Index Only Scan？它看哪個統計值？
- 當 `relallvisible = 0` 時，planner 估計 Index Only Scan 要回表幾次？
- **所以它為什麼改選 Bitmap Heap Scan？** 這個決定是對的嗎？

<br>

---

<br>

## Part C — `INCLUDE` vs 複合索引

### C1

```sql
CREATE INDEX idx_a ON events7 (user_id) INCLUDE (amount);
CREATE INDEX idx_b ON events7 (user_id, amount);
```

兩者都能讓那個查詢走 Index Only Scan。差別在哪？

| | `(user_id) INCLUDE (amount)` | `(user_id, amount)` |
|---|---|---|
| `amount` 有排序嗎 | ? | ? |
| 能服務 `WHERE user_id=? AND amount>?` 嗎 | ? | ? |
| 能服務 `ORDER BY user_id, amount` 嗎 | ? | ? |
| 索引大小 | ? | ? |
| 能當唯一索引嗎（`UNIQUE (user_id)`） | ? | ? |

**建兩個索引實測體積，填進表格。**

### C2

回答：`INCLUDE` 存在的意義是什麼？舉一個**只能用 `INCLUDE` 不能用複合索引**的場景。

（提示：想想 `CREATE UNIQUE INDEX ... INCLUDE (...)`）

### C3

回答：`INCLUDE` 的欄位放越多越好嗎？代價是什麼？

<br>

---

<br>

## Part D — 實務

### D1 — 為什麼不能靠 autovacuum

回答：
- autovacuum 什麼時候會觸發？看哪些參數？
- 大批次 `UPDATE` 之後，autovacuum 多久會跟上？
- **為什麼「批次作業之後手動 `VACUUM`」是標準做法？**

### D2 — 監控

寫一個查詢，找出**「visibility map 髒掉」最嚴重的表**：

```sql
SELECT relname, relpages, relallvisible,
       ROUND(100.0 * relallvisible / NULLIF(relpages,0), 1) AS pct_visible
FROM pg_class WHERE relkind='r' AND relpages > 0
ORDER BY pct_visible ASC;
```

回答：
- `pct_visible` 低代表什麼？
- 什麼樣的表天生就會低？（提示：高頻更新的表）
- **這個指標該設什麼告警閾值？**

### D3 — HOT update

回答：
- 什麼是 **HOT（Heap-Only Tuple）update**？
- 什麼條件下 `UPDATE` 才能是 HOT 的？
- HOT update 會清掉 visibility map 標記嗎？
- **`fillfactor` 參數和 HOT update 有什麼關係？** 對高頻更新的表該怎麼設？

### D4 — 完整策略

寫出一份「**如何維持 Index Only Scan 有效**」的策略，涵蓋：
- 索引設計
- `fillfactor`
- autovacuum 調校
- 批次作業的規範
- 監控

<br>

---

<br>

## 面試官的追問

> 1. 「`VACUUM` 和 `VACUUM FULL` 對 visibility map 的影響一樣嗎？」
>
> 2. 「唯讀複本（read replica）上的 Index Only Scan 會受主庫的 VACUUM 影響嗎？」
>
> 3. 「長交易（long-running transaction）為什麼會讓 `VACUUM` 失效？」
>
> 4. 「如果一張表是 append-only（只 INSERT 不 UPDATE），還需要擔心這個問題嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 索引裡沒有的東西</summary>

PostgreSQL 的索引項目**只存鍵值和指向 heap 的指標（tid）**，**不存交易可見性資訊**（`xmin` / `xmax`）。

所以掃到一個索引項目時，PostgreSQL 無法直接判斷「這一列對我這個交易是否可見」—— 那筆資料可能是：
- 已經被刪除但還沒 vacuum 的
- 被其他還沒提交的交易插入的
- 被更新過、這是舊版本

**正常情況下就得回 heap 檢查**（這就是 Index Scan 的 heap fetch）。

**Visibility Map 是捷徑**：它為每個 heap 頁面記一個 bit，「這一頁裡的所有 tuple 對所有交易都可見」。

如果索引項目指向的頁面被標記為 `all-visible`，PostgreSQL **就可以跳過回表** → 這就是 Index Only Scan。

**所以 Index Only Scan 的前提是兩個，不是一個**：
1. 索引包含查詢需要的所有欄位（covering）
2. **資料頁在 visibility map 裡是乾淨的**

第 2 點是隱形的，也是這一題的主角。

</details>

<details>
<summary>Hint 2 — 為什麼改 5% 會讓 relallvisible 歸零</summary>

PostgreSQL 的 `UPDATE` **不是原地修改**，而是：
1. 把舊版本標記為「被 xmax 刪除」
2. **在某個頁面寫入一個全新的 tuple**（新版本）

新寫入的 tuple 屬於「還沒被確認對所有交易可見」→ 該頁面的 `all-visible` bit 被**清除**。

**關鍵在於「5% 的列」不等於「5% 的頁面」**：

本題 100 萬列分布在 7743 個頁面上，每頁約 130 列。`WHERE id % 20 = 0` 挑出每 20 列中的 1 列 —— 這些列**均勻散布在每一個頁面上**。

**幾乎每一頁都至少被碰到一次** → 幾乎每一頁的 bit 都被清掉 → `relallvisible` 從 7743 掉到 **0**。

**教訓：分散的小量更新，破壞力遠大於集中的大量更新。**
更新 5% 但集中在連續的頁面，只會弄髒 5% 的頁面；均勻散布就會弄髒 100%。

</details>

<details>
<summary>Hint 3 — planner 為什麼直接放棄 Index Only Scan</summary>

planner 估算 Index Only Scan 的成本時，會用這個比例：

```
預期回表次數 ≈ 掃到的索引項目數 × (1 - relallvisible / relpages)
```

- `relallvisible = 7743 / 7743` → 比例是 1.0 → 預期回表 **0 次** → Index Only Scan 超便宜 ✅
- `relallvisible = 0 / 7761` → 比例是 0.0 → 預期**每一筆都要回表** → Index Only Scan 退化成比普通 Index Scan 還糟（多一層檢查）

於是 planner 改選 **Bitmap Heap Scan** —— 它先把要讀的頁面收集成 bitmap、按實體順序讀，把隨機 I/O 變成順序 I/O。

**這個決定是對的**：在 VM 全髒的情況下，Bitmap Heap Scan 確實比逐筆回表的 Index Only Scan 好。

**planner 沒有做錯，是資料的維護狀態變了。** 這也是為什麼 `EXPLAIN` 看起來「換了一個計畫」而不是「同一個計畫變慢」—— 很多人因此完全找錯方向。

</details>

<details>
<summary>Hint 4 — INCLUDE vs 複合索引，與 fillfactor</summary>

**C1 對照**：

| | `(user_id) INCLUDE (amount)` | `(user_id, amount)` |
|---|---|---|
| `amount` 有排序 | ❌（只是附加酬載） | ✅ |
| `WHERE user_id=? AND amount>?` | ❌ 只能 filter | ✅ 兩欄都是 Index Cond |
| `ORDER BY user_id, amount` | ❌ | ✅ |
| 索引大小（本題實測） | **30 MB** | **30 MB** | 
| `UNIQUE (user_id)` | **✅ 可以** | ❌ 唯一性會變成 (user_id, amount) |

**實測的 `EXPLAIN` 差異**（這是最關鍵的一格）：

```
-- INCLUDE 版本：amount 只能當 Filter
   Recheck Cond: (user_id = 42)
   Filter: (amount > '400'::numeric)

-- 複合索引版本：amount 進得了 Index Cond
   Index Cond: ((user_id = 42) AND (amount > '400'::numeric))
```

**INCLUDE 的欄位進不了 `Index Cond`** —— 它只是被順便帶著走的酬載，不能拿來縮小掃描範圍。

> **注意索引大小那一格**：理論上 `INCLUDE` 的欄位不存在非葉節點，所以應該略小。
> 但本題實測**兩者都是 30 MB** —— 因為非葉節點只佔整個索引的極小比例（約 1%），差異被捨入吃掉了。
> **不要為了「省空間」而選 `INCLUDE`** —— 它的價值在唯一索引，不在體積。

**C2 的答案**：`INCLUDE` 唯一不可取代的場景就是**唯一索引**：

```sql
CREATE UNIQUE INDEX ON orders (order_no) INCLUDE (customer_id, total);
```

你要 `order_no` 唯一，但又想讓 `SELECT customer_id, total FROM orders WHERE order_no=?` 走 Index Only Scan。
複合索引 `(order_no, customer_id, total)` 做不到 —— 那樣唯一性約束就變成三欄的組合了。

**D3 的 `fillfactor`**：

`fillfactor` 控制每個頁面填多滿（預設 100%）。設成 `90` 就留 10% 空間。

**HOT update** 的條件：
1. 更新的欄位**沒有被任何索引引用**
2. **新版本能放進同一個頁面**

滿足時，新 tuple 直接寫在同一頁、索引不用更新 —— 快很多，而且**對 VM 的破壞較小**（只弄髒一頁而不是「索引頁 + 資料頁」）。

```sql
ALTER TABLE events7 SET (fillfactor = 85);
VACUUM FULL events7;    -- 需要重寫才會生效
```

**高頻更新的表設 `fillfactor` 80~90 是標準做法。** 代價是表變大約 10~20%。

</details>
