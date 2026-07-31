# Phase 7-06 — Partition Pruning Gone Wrong

> **難度**：★★★★★
> **核心技巧**：分區裁剪、裁剪失效的三種原因、Runtime Pruning
> **對應基礎題**：[sql_training Phase 7 Scenario 04](../../../sql_training/phase-7/scenario-04-composite-index-design)（最左前綴失效 → 這題是分區裁剪失效）

<br>

---

<br>

## Interview Context

> *面試官：*「我們把 6 億筆的感測器資料按月分區，一個月一張。
>
> 儀表板查詢『某個月的資料』本來應該只碰一張分區。上線後我看 `EXPLAIN`，發現它**掃了全部 6 張分區**。
>
> 分區鍵沒錯、查詢有帶時間條件。
>
> **為什麼裁剪沒生效？**」

<br>

分區的全部價值就在**裁剪（pruning）**。裁剪失效的分區表，比不分區還糟 —— 你付出了管理成本，卻沒得到任何效能好處。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS measurements;

CREATE TABLE measurements (
    id        BIGSERIAL,
    sensor_id INT NOT NULL,
    reading   NUMERIC(10,2) NOT NULL,
    taken_at  TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (taken_at);

CREATE TABLE measurements_2026_01 PARTITION OF measurements FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE measurements_2026_02 PARTITION OF measurements FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE measurements_2026_03 PARTITION OF measurements FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE measurements_2026_04 PARTITION OF measurements FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE measurements_2026_05 PARTITION OF measurements FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE measurements_2026_06 PARTITION OF measurements FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

INSERT INTO measurements (sensor_id, reading, taken_at)
SELECT (random()*99+1)::int, (random()*100)::numeric(10,2),
       '2026-01-01'::timestamptz + (random() * interval '180 days')
FROM generate_series(1, 600000);

ANALYZE measurements;
```

<br>

> **診斷技巧**：想知道掃了幾張分區，數 `EXPLAIN` 裡有幾個 `Seq Scan on measurements_`：
>
> ```bash
> psql -c "EXPLAIN <你的查詢>" | grep -c 'Scan on measurements_'
> ```

<br>

---

<br>

## Part A — 裁剪正常運作

### A1

```sql
EXPLAIN (ANALYZE, TIMING OFF)
SELECT count(*) FROM measurements
WHERE taken_at >= '2026-03-01' AND taken_at < '2026-04-01';
```

**實測：只掃 1 張分區。**

```
->  Seq Scan on measurements_2026_03 measurements  (actual rows=102981.00 loops=1)
```

回答：
- 其他 5 張分區去哪了？
- 這個裁剪是在**什麼時候**發生的？（規劃時還是執行時？）
- `EXPLAIN`（不加 `ANALYZE`）看得到裁剪結果嗎？

<br>

---

<br>

## Part B — 三種裁剪失效

### B1 — 失效原因一：分區鍵被函數包住

```sql
EXPLAIN (ANALYZE, TIMING OFF)
SELECT count(*) FROM measurements
WHERE date_trunc('month', taken_at) = '2026-03-01';
```

**實測：掃了全部 6 張分區。**

回答：
- 這個查詢的**結果**是對的嗎？
- 為什麼 planner 不能裁剪？（提示：它必須證明「`date_trunc(x)='2026-03-01'` ⟹ `x` 落在某個範圍」）
- **怎麼改寫**成可裁剪的？
- 這和 [sql_training Phase 7 Scenario 01](../../../sql_training/phase-7/scenario-01-index-failure) 的「函數包住欄位讓索引失效」是同一個道理嗎？

### B2 — 失效原因二：沒有分區鍵條件

```sql
EXPLAIN (ANALYZE, TIMING OFF)
SELECT count(*) FROM measurements WHERE sensor_id = 42;
```

**實測：掃了全部 6 張分區。**

回答：
- 這是「bug」還是「本來就該這樣」？
- **如果這是最常見的查詢模式，分區鍵選 `taken_at` 對嗎？**
- 有什麼辦法讓這種查詢也快？（提示：每張分區上的本地索引）
- 建索引後重測，掃的分區數會變嗎？**成本會變嗎？**

### B3 — 失效原因三：跨型別比較

測試這幾種寫法，記錄各自掃幾張分區：

| 查詢條件 | 掃幾張 |
|---------|-------|
| `taken_at >= '2026-03-01' AND taken_at < '2026-04-01'` | 1 |
| `taken_at::date = '2026-03-15'` | ? |
| `to_char(taken_at,'YYYY-MM') = '2026-03'` | ? |
| `taken_at BETWEEN '2026-03-01' AND '2026-03-31'` | ? |
| `EXTRACT(month FROM taken_at) = 3` | ? |

**第四個特別注意**：它只掃 1 張還是 2 張？為什麼？（提示：`BETWEEN` 是閉區間）

<br>

---

<br>

## Part C — Runtime Pruning

### C1

有些條件在**規劃時**不知道值，但**執行時**知道。PostgreSQL 支援執行期裁剪。

```sql
PREPARE q(timestamptz) AS
SELECT count(*) FROM measurements
WHERE taken_at >= $1 AND taken_at < $1 + interval '1 month';

EXPLAIN (ANALYZE, TIMING OFF) EXECUTE q('2026-03-01');
```

實測：

```
->  Parallel Append  (cost=0.00..7339.51 rows=42903 width=0)
      Subplans Removed: 3
      ->  Parallel Seq Scan on measurements_2026_03 ...
```

回答：
- **`Subplans Removed: 3`** 是什麼意思？
- 這代表裁剪發生在哪個階段？
- **不加 `ANALYZE` 的 `EXPLAIN` 看得到 `Subplans Removed` 嗎？** 自己測。為什麼？

### C2 — 兩種裁剪

填完這張表：

| | 規劃期裁剪 | 執行期裁剪 |
|---|---|---|
| 什麼時候發生 | ? | ? |
| 條件必須是什麼 | ? | ? |
| `EXPLAIN` 怎麼看出來 | ? | ? |
| 效果 | ? | ? |

### C3 — 什麼情況會用到執行期裁剪

列出至少三種：
- prepared statement 的參數
- 子查詢的結果（`WHERE taken_at = (SELECT ...)`）
- Nested Loop 的內側（外側的值決定要掃哪張分區）

各寫一個例子測試。

<br>

---

<br>

## Part D — 分區設計

### D1 — 分區鍵怎麼選

回答：
- 分區鍵應該根據什麼來選？
- 如果查詢模式有兩種（一種按時間、一種按 `sensor_id`），怎麼辦？
- **子分區（sub-partitioning）能解決嗎？代價是什麼？**

### D2 — 分區數量

回答：
- 分成 6 張和分成 600 張，規劃時間有差嗎？自己測（多建一些分區試試）
- PostgreSQL 對分區數有實務上限嗎？
- **分太細的代價是什麼？**

### D3 — 維運

回答：
- 怎麼自動建立下個月的分區？
- 舊分區怎麼歸檔？（提示：`DETACH PARTITION` 的鎖等級）
- **`ATTACH PARTITION` 需要什麼前置條件才不會鎖太久？**
- 分區表上建索引，`CREATE INDEX` 會鎖住所有分區嗎？

### D4 — 分區真的值得嗎

回答：什麼情況下**不該**分區？

（提示：想想「分區的好處」清單 —— 裁剪、批次刪除、平行掃描、維護視窗。如果你一個都用不到呢？）

<br>

---

<br>

## 面試官的追問

> 1. 「`enable_partition_pruning` 參數是什麼？什麼時候會想關掉它？」
>
> 2. 「分區表的 JOIN 有 partition-wise join 嗎？要什麼條件才會啟用？」
>
> 3. 「`DROP PARTITION` 和 `DELETE FROM ... WHERE` 刪同樣的資料，成本差多少？」
>
> 4. 「分區表的主鍵有什麼限制？為什麼？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼函數包住就不能裁剪</summary>

裁剪的原理：planner 拿 `WHERE` 條件和每張分區的**邊界定義**做比對，證明「這個條件不可能在這張分區裡成立」就把它排除。

```sql
WHERE taken_at >= '2026-03-01' AND taken_at < '2026-04-01'
```
對 `measurements_2026_01`（範圍 `[2026-01-01, 2026-02-01)`）：
`taken_at >= '2026-03-01'` 和 `taken_at < '2026-02-01'` **不可能同時成立** → 排除 ✓

```sql
WHERE date_trunc('month', taken_at) = '2026-03-01'
```
planner 要證明的是「`date_trunc('month', x) = '2026-03-01'` ⟹ `x ∉ [2026-01-01, 2026-02-01)`」。

**這需要理解 `date_trunc` 這個函數的數學性質** —— planner 沒有這種能力。它只知道「這是個函數呼叫，結果不可知」。

**改寫成可裁剪的形式**：把函數從欄位上拿掉，改成範圍條件。

```sql
WHERE taken_at >= '2026-03-01' AND taken_at < '2026-04-01'
```

**和索引失效是同一個道理**：`WHERE lower(email)=...` 用不到 `email` 的索引，`WHERE date_trunc(taken_at)=...` 用不到分區裁剪 ——
**只要欄位被函數包住，資料庫就失去了「用欄位的原始值推理」的能力。**

（差別在於索引還可以建**表達式索引**來救；**分區裁剪沒有這個選項** —— 分區邊界是固定的。）

</details>

<details>
<summary>Hint 2 — B2 的深層問題</summary>

`WHERE sensor_id = 42` 沒有提到分區鍵，**planner 沒有任何資訊可以排除任何一張分區** —— 這不是 bug，是必然。

**真正該問的是：分區鍵選對了嗎？**

- 如果 90% 的查詢是「某個時間範圍」→ 按 `taken_at` 分區是對的
- 如果 90% 的查詢是「某個感測器的所有資料」→ **應該按 `sensor_id` 分區（HASH 或 LIST）**

**加索引能救嗎**：在每張分區上建 `sensor_id` 的索引之後，仍然會「碰」6 張分區，但每張都是快速的 Index Scan 而不是 Seq Scan。

```
Append
  -> Index Scan on measurements_2026_01 (rows=...)
  -> Index Scan on measurements_2026_02 (rows=...)
  ...
```

**掃描的分區「數量」不變，但每張的「成本」大幅下降。** 這通常是可接受的 —— 6 次索引查找還好，600 張分區就不行了。

**這就是 D2「分太細的代價」的一部分。**

</details>

<details>
<summary>Hint 3 — Runtime pruning 與 BETWEEN 陷阱</summary>

**`Subplans Removed: 3`**：Append 節點底下原本掛了 6 個子計畫（每張分區一個）。執行時 `$1` 的值確定了，PostgreSQL **在執行階段動態跳過** 3 個不需要的子計畫。

**不加 `ANALYZE` 的 `EXPLAIN` 看不到它** —— 因為執行期裁剪要**真的執行**才會發生。純 `EXPLAIN` 只做規劃，會顯示全部 6 個子計畫。

**這是診斷分區問題最容易誤判的地方**：你 `EXPLAIN` 看到 6 張分區都在，以為裁剪壞了 —— 其實執行時它只碰 1 張。**一定要用 `EXPLAIN ANALYZE`。**

<br>

**B3 的 `BETWEEN` 陷阱**：

```sql
WHERE taken_at BETWEEN '2026-03-01' AND '2026-03-31'
```

`BETWEEN` 是**閉區間** → `taken_at <= '2026-03-31 00:00:00'`。

這**只掃 1 張分區**（3 月）—— 裁剪看起來完全正常。**但它漏資料。**

`taken_at` 是 `TIMESTAMPTZ`，`'2026-03-31'` 被解讀成 `2026-03-31 00:00:00` —— 3/31 白天的資料全部不見。

**實測**：

```sql
SELECT count(*) FROM measurements WHERE taken_at BETWEEN '2026-03-01' AND '2026-03-31';
--  99754
SELECT count(*) FROM measurements WHERE taken_at >= '2026-03-01' AND taken_at < '2026-04-01';
-- 102981
```

**少了 3,227 列，而且沒有任何錯誤或警告。**

這比裁剪失效更危險 —— 裁剪失效只是慢，這個是**答案錯了**。

**正確寫法永遠是半開區間**：

```sql
WHERE taken_at >= '2026-03-01' AND taken_at < '2026-04-01'
```

**半開區間第五次出現**（[1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room)、[2-06](../../phase-2-aggregation-limits/06-histogram-with-empty-buckets)、[5-05](../../phase-5-time-series/05-scd-type-2-point-query)、[6-03](../../phase-6-dml-concurrency/03-preventing-double-booking)）。
**而分區邊界本身就是半開的**（`FROM ... TO ...` 是 `[from, to)`）—— 你的查詢條件用同樣的形狀，裁剪才會乾淨。

</details>

<details>
<summary>Hint 4 — D4 什麼時候不該分區</summary>

分區的好處只有四項：

1. **裁剪** —— 查詢只碰需要的分區
2. **批次刪除** —— `DROP PARTITION` 是瞬間的，`DELETE` 是災難（[Phase 6-06](../../phase-6-dml-concurrency/06-deduplicate-a-10m-row-table)）
3. **平行/分散維護** —— `VACUUM`、`REINDEX` 可以一張一張做
4. **冷熱分離** —— 舊分區可以放到便宜的儲存

**如果你一項都用不到，就不該分區。** 代價是：

- 規劃時間增加（分區越多越明顯）
- 主鍵/唯一約束**必須包含分區鍵**（追問 4）
- 跨分區的查詢和 JOIN 更複雜
- 維運負擔（要自動建新分區、要監控）

**常見的錯誤決定**：「表有 1000 萬列，好像很大，分區一下吧」——
1000 萬列對 PostgreSQL 根本不大，一個好的索引就解決了。**分區是為了「管理」而不是為了「速度」** ——
真正的速度來自裁剪，而裁剪只有在查詢模式和分區鍵高度吻合時才有效。

</details>
