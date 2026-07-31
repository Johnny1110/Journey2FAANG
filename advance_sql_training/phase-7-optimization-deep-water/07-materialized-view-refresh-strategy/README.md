# Phase 7-07 — Materialized View Refresh Strategy

> **難度**：★★★★☆
> **核心技巧**：Materialized View、`REFRESH CONCURRENTLY` 的鎖行為、增量刷新設計
> **對應基礎題**：[練習題（自設）INSERT INTO SELECT 報表](../../../sql_training/insert_into_select_report)（你當初的手動彙總表）

<br>

---

<br>

## Interview Context

> *面試官：*「我們有個 dashboard 查詢要跑 40 秒。它是一堆 `GROUP BY` 的彙總，資料一天只變一次。
>
> 有人提議做成 materialized view，每晚刷新。聽起來很合理。
>
> 上線第一天，凌晨三點刷新的時候，**所有查這個 view 的 API 全部逾時**。
>
> 為什麼？怎麼修？」

<br>

**Materialized view 是「用空間和新鮮度換速度」的經典手段。** 但 `REFRESH` 這個動作本身的鎖行為，是很多人上線後才發現的坑。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS sales7;

CREATE TABLE sales7 (
    id          BIGSERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    region      TEXT NOT NULL,
    amount      NUMERIC(10,2) NOT NULL,
    sold_on     DATE NOT NULL
);

INSERT INTO sales7 (customer_id, region, amount, sold_on)
SELECT (random()*4999+1)::int,
       (ARRAY['APAC','EMEA','NA','LATAM'])[floor(random()*4+1)],
       (random()*1000)::numeric(10,2),
       '2026-01-01'::date + (random()*200)::int
FROM generate_series(1, 300000);

ANALYZE sales7;

CREATE MATERIALIZED VIEW mv_region_daily AS
SELECT region, sold_on, count(*) AS orders, sum(amount) AS revenue
FROM sales7
GROUP BY region, sold_on;
```

<br>

---

<br>

## Part A — 重現事故

### A1

先試著用 `CONCURRENTLY` 刷新：

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_region_daily;
```

實測：

```
ERROR:  cannot refresh materialized view "public.mv_region_daily" concurrently
HINT:  Create a unique index with no WHERE clause on one or more columns of the materialized view.
```

回答：為什麼 `CONCURRENTLY` 需要唯一索引？（提示：它怎麼知道哪些列變了？）

### A2 — 建唯一索引

```sql
CREATE UNIQUE INDEX ON mv_region_daily (region, sold_on);
```

回答：
- 為什麼 `(region, sold_on)` 可以當唯一鍵？
- 如果 view 的定義沒有天然的唯一鍵怎麼辦？

### A3 — 證明鎖的差異

**這是本題的核心實驗，一定要親手跑。**

```sql
-- Session A：開一個交易讀 MV，然後 hold 住
BEGIN;
SELECT count(*) FROM mv_region_daily;
SELECT pg_sleep(10);      -- 模擬一個慢查詢
COMMIT;
```

```sql
-- Session B（在 A 還在 sleep 時執行）
SET lock_timeout = '2s';
REFRESH MATERIALIZED VIEW mv_region_daily;          -- 先測這個
```

**實測結果**：

```
ERROR:  canceling statement due to lock timeout
```

再測 `CONCURRENTLY` 版本：

```sql
SET lock_timeout = '2s';
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_region_daily;
```

**實測結果**：

```
REFRESH MATERIALIZED VIEW          ← 成功
```

### A4 — 診斷

回答：
- 兩種 `REFRESH` 各取得什麼鎖？（查 `pg_locks` 或文件）
- 為什麼普通 `REFRESH` 會被一個 `SELECT` 擋住？
- **所以凌晨三點發生了什麼事？**（提示：反過來想，是 REFRESH 擋住了 API 還是 API 擋住了 REFRESH？）
- 這解釋了「所有 API 全部逾時」嗎？

<br>

---

<br>

## Part B — 兩種 REFRESH 的代價

### B1

填完這張表：

| | `REFRESH` | `REFRESH CONCURRENTLY` |
|---|---|---|
| 鎖等級 | ? | ? |
| 期間可以 `SELECT` 嗎 | ? | ? |
| 需要唯一索引嗎 | ? | ? |
| 速度 | ? | ? |
| 需要額外空間嗎 | ? | ? |
| 可以在交易內執行嗎 | ? | ? |

### B2 — 為什麼 CONCURRENTLY 比較慢

回答：
- `CONCURRENTLY` 的實作原理是什麼？（提示：它會建一個暫存表，然後做 diff）
- 為什麼需要唯一索引才能做 diff？
- **在本題（804 列）測不出速度差異，為什麼？** 什麼規模才看得出來？

### B3 — 實測速度

把 MV 的資料量放大（改成按 `customer_id, sold_on` 分組，會有數萬列），再測一次兩種 `REFRESH` 的時間。

<br>

---

<br>

## Part C — 增量刷新

### C1 — 全量刷新的問題

回答：
- `REFRESH`（不管哪一種）都是**全量重算**。300 萬列的表每晚重算一次要多久？
- 如果資料只有 1% 變動，重算 100% 合理嗎？
- **PostgreSQL 有內建的增量物化視圖嗎？**（查一下，答案可能讓你意外）

### C2 — 自己做增量

PostgreSQL 沒有內建 incremental MV，所以實務上是**用普通表 + 自己維護**。

設計一個方案：

```sql
CREATE TABLE agg_region_daily (
    region  TEXT NOT NULL,
    sold_on DATE NOT NULL,
    orders  BIGINT NOT NULL,
    revenue NUMERIC(14,2) NOT NULL,
    PRIMARY KEY (region, sold_on)
);
```

寫出「只更新最近 N 天」的增量刷新 SQL。

> 提示：用 [Phase 6-01](../../phase-6-dml-concurrency/01-the-idempotent-upsert) 的 `INSERT ... ON CONFLICT DO UPDATE`。
> **這一題是那一題的實際應用。**

### C3 — 增量的正確性

回答：
- 如果有人**回頭修改**了三個月前的訂單，你的「只更新最近 7 天」會漏掉。怎麼辦？
- 怎麼偵測「彙總表和明細對不上」？
  （寫出對帳查詢 —— 這是 [Phase 1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) 的技巧）
- 多久做一次全量重算當作校正？

### C4 — 三種方案對照

| | 每次即時算 | Materialized View | 增量彙總表 |
|---|---|---|---|
| 查詢速度 | ? | ? | ? |
| 資料新鮮度 | ? | ? | ? |
| 實作複雜度 | ? | ? | ? |
| 刷新成本 | ? | ? | ? |
| 會不會算錯 | ? | ? | ? |
| **什麼時候選它** | ? | ? | ? |

<br>

---

<br>

## Part D — 實務

### D1 — 刷新排程

回答：
- 用 `cron` + `psql` 還是 `pg_cron` extension？取捨？
- 刷新失敗了怎麼知道？怎麼重試？
- **刷新到一半 crash 會怎樣？** MV 的資料會不會壞掉？

### D2 — 依賴鏈

如果 `mv_b` 是建在 `mv_a` 上的，刷新順序有關係嗎？

寫一個查詢，找出所有 MV 之間的依賴關係。

（提示：`pg_depend` / `pg_matviews`）

### D3 — 監控

回答：
- 怎麼知道一個 MV 的資料「有多舊」？
- MV 沒有內建的「上次刷新時間」—— 你會怎麼記錄？
- **報表上要不要顯示「資料截至 XX 時間」？**

### D4 — 什麼時候不該用 MV

回答：列出至少三種情況。

<br>

---

<br>

## 面試官的追問

> 1. 「MV 和普通 View、和 CTE 的差別分別是什麼？」
>
> 2. 「MV 上可以建幾個索引？MV 的索引在 `REFRESH` 之後需要重建嗎？」
>
> 3. 「唯讀複本上可以刷新 MV 嗎？MV 的資料會同步到複本嗎？」
>
> 4. 「如果我要一個『永遠即時正確』的彙總，除了即時算還有什麼辦法？」
>    （提示：trigger 維護的彙總表 —— 代價是什麼？）

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 兩種 REFRESH 的鎖</summary>

| | `REFRESH` | `REFRESH CONCURRENTLY` |
|---|---|---|
| 鎖等級 | **`ACCESS EXCLUSIVE`** | `EXCLUSIVE` |
| 期間可 `SELECT` | **❌ 完全擋住** | ✅ 可以 |
| 需要唯一索引 | ❌ | **✅ 必須** |
| 速度 | 快 | 慢（要做 diff） |
| 額外空間 | 重建整份 | **需要暫存表 + diff 空間** |
| 可在交易內 | ✅ | ✅（但不能和其他 DDL 混） |

**`ACCESS EXCLUSIVE` 是 PostgreSQL 最強的鎖 —— 它和所有其他鎖衝突，包括最弱的 `ACCESS SHARE`（`SELECT` 取得的鎖）。**

**所以凌晨三點的事故是雙向的**：

1. `REFRESH` 要拿 `ACCESS EXCLUSIVE`，但當時有 API 正在 `SELECT` → **`REFRESH` 先卡住等待**
2. `REFRESH` 在等待時已經進入鎖佇列 → **後續所有新的 `SELECT` 都排在它後面** → 全部卡住
3. 直到那個慢查詢結束、`REFRESH` 跑完（40 秒）→ **API 全線逾時**

**關鍵洞察：一個等待中的強鎖，會把後面所有弱鎖也堵住。** 這是 PostgreSQL 鎖佇列的公平性機制導致的 —— 不是「REFRESH 只擋 40 秒」，而是「REFRESH 等多久，就多擋多久」。

</details>

<details>
<summary>Hint 2 — CONCURRENTLY 的原理</summary>

`REFRESH CONCURRENTLY` 的步驟：

1. 建一個暫存表，把新的查詢結果算進去
2. 用**唯一鍵**把暫存表和舊的 MV 做 **diff**（`FULL OUTER JOIN`）
3. 對舊 MV 執行 `INSERT` / `UPDATE` / `DELETE`，只套用差異
4. 丟掉暫存表

**唯一索引是 diff 的必要條件** —— 沒有唯一鍵，就無法判斷「新結果的這一列，對應舊結果的哪一列」。這正是 [Phase 1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) 的對帳邏輯：**要比對兩個資料集，必須有共同的鍵。**

**為什麼比較慢**：
- 全量 `REFRESH`：算一次 + 換掉整份資料（幾乎就是 `CREATE TABLE AS`）
- `CONCURRENTLY`：算一次 + **額外做一次 FULL OUTER JOIN** + 逐列 DML + 維護索引

**本題測不出差異的原因**：MV 只有 804 列，diff 的成本可以忽略。實測兩者都約 30 ms。
**規模要到數十萬列以上**，`CONCURRENTLY` 的 diff 成本才會明顯（通常是 2~5 倍）。

</details>

<details>
<summary>Hint 3 — C2 增量刷新</summary>

```sql
-- 只重算最近 7 天
INSERT INTO agg_region_daily (region, sold_on, orders, revenue)
SELECT region, sold_on, count(*), sum(amount)
FROM sales7
WHERE sold_on >= CURRENT_DATE - 7
GROUP BY region, sold_on
ON CONFLICT (region, sold_on) DO UPDATE
SET orders  = EXCLUDED.orders,
    revenue = EXCLUDED.revenue;
```

**`DO UPDATE SET x = EXCLUDED.x`（覆蓋）而不是 `x = x + EXCLUDED.x`（累加）** —— 因為我們是**重算**那幾天，不是**追加**。

累加版本不是冪等的（[Phase 6-01](../../phase-6-dml-concurrency/01-the-idempotent-upsert) Part D2 討論過）—— 跑兩次數字就會翻倍。**覆蓋版本可以安全重跑**，這在批次作業裡至關重要。

**C3 的對帳查詢**：

```sql
SELECT COALESCE(a.region, s.region) AS region,
       COALESCE(a.sold_on, s.sold_on) AS sold_on,
       a.revenue AS agg_revenue, s.revenue AS true_revenue
FROM agg_region_daily a
FULL OUTER JOIN (
    SELECT region, sold_on, sum(amount) AS revenue FROM sales7 GROUP BY region, sold_on
) s ON s.region = a.region AND s.sold_on = a.sold_on
WHERE a.revenue IS DISTINCT FROM s.revenue;
```

**`IS DISTINCT FROM` 又出現了** —— 沒有它，「彙總表有但明細沒有」的那些列會因為 `NULL <> x` 是 UNKNOWN 而被漏掉。[Phase 1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) 的教訓在這裡直接套用。

回傳 0 列 = 完全一致。**這個查詢應該每天跑，而且應該比增量刷新更頻繁地被信任。**

</details>

<details>
<summary>Hint 4 — D4 什麼時候不該用 MV</summary>

1. **需要即時資料** —— MV 永遠是過期的。「使用者剛下的訂單要馬上出現在報表上」就不能用 MV。

2. **底層資料變動極頻繁** —— 刷新成本高於節省的查詢成本。如果一小時變 1000 次而只被查 10 次，MV 是虧的。

3. **查詢本身其實不慢** —— 先確認瓶頸真的在這個查詢。很多「慢查詢」加個索引就解決了，不需要 MV 的維運負擔。（先做 [7-01](../01-the-query-that-got-slower-after-adding-an-index) ~ [7-05](../05-the-statistics-lie) 的功課再考慮 MV。）

4. **結果集太大** —— MV 要佔磁碟。如果彙總後還有幾億列，儲存和刷新都是負擔。

5. **需要參數化** —— MV 是固定的查詢結果，不能帶參數。「每個使用者看自己的彙總」不適合（除非把 user_id 也放進 MV 然後查詢時過濾，但那樣 MV 會很大）。

**C1 的答案**：**PostgreSQL 沒有內建的增量物化視圖。** `REFRESH CONCURRENTLY` 雖然名字聽起來像增量，但它**仍然全量重算**，只是套用差異時比較溫和。

真正的 IVM（Incremental View Maintenance）在 PostgreSQL 是研究中的功能（有 `pg_ivm` extension），Oracle 的 `FAST REFRESH` 和 SQL Server 的 indexed view 有類似能力。**所以實務上就是自己用普通表 + `ON CONFLICT` 維護**（C2 的做法）。

</details>
