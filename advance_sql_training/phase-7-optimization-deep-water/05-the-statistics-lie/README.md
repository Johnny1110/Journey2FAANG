# Phase 7-05 — The Statistics Lie

> **難度**：★★★★★
> **核心技巧**：欄位獨立性假設、`CREATE STATISTICS`、functional dependency、估計值 vs 實際值
> **對應基礎題**：[sql_training Phase 7 Scenario 03](../../../sql_training/phase-7/scenario-03-join-optimization)（那題是缺索引，這題是**索引沒問題但估計錯**）

<br>

---

<br>

## Interview Context

> *面試官：*「這個查詢很簡單，索引也有，但 JOIN 的計畫每次都選錯 —— 該用 Nested Loop 的時候用 Hash Join，反之亦然。
>
> 我 `ANALYZE` 過了，統計是最新的。
>
> `EXPLAIN ANALYZE` 顯示 planner 估 **6041 列**，實際是 **25000 列**。差了 4 倍。
>
> 統計明明是新的，為什麼還會估錯？」

<br>

**「統計是新的」不等於「估計是對的」。** PostgreSQL 的統計預設是**每個欄位各自獨立**收集的 —— 當兩個欄位之間有相關性時，估計必然出錯。

而排查效能問題的第一步，就是**比對 `rows=`（估計）和 `actual rows=`（實際）**。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS addresses;

CREATE TABLE addresses (
    id      SERIAL PRIMARY KEY,
    country TEXT NOT NULL,
    city    TEXT NOT NULL,
    note    TEXT
);

-- 12 個城市，每個城市只屬於一個國家 —— city 完全決定 country
INSERT INTO addresses (country, city, note)
SELECT c.country, c.city, repeat('x',20)
FROM (VALUES
  ('Taiwan','Taipei'),('Taiwan','Kaohsiung'),('Taiwan','Taichung'),
  ('Japan','Tokyo'),('Japan','Osaka'),('Japan','Kyoto'),
  ('Korea','Seoul'),('Korea','Busan'),('Korea','Incheon'),
  ('USA','NYC'),('USA','LA'),('USA','Chicago')
) AS c(country, city), generate_series(1, 25000);

CREATE INDEX ON addresses (country, city);
ANALYZE addresses;
-- 共 30 萬列，每個城市 2.5 萬列
```

<br>

---

<br>

## Part A — 重現誤估

### A1

```sql
EXPLAIN (ANALYZE, TIMING OFF)
SELECT * FROM addresses WHERE country = 'Taiwan' AND city = 'Taipei';
```

實測：

```
Bitmap Heap Scan on addresses  (cost=86.34..2713.96 rows=6041 width=36)
                               (actual rows=25000.00 loops=1)
```

**估計 6041，實際 25000。**

### A2 — 推導 planner 的算式

planner 有這些單欄統計：

- `country` 有 4 個相異值 → `P(country='Taiwan')` ≈ ?
- `city` 有 12 個相異值 → `P(city='Taipei')` ≈ ?
- 總列數 30 萬

**假設兩欄獨立**，planner 算出：`300000 × P(country) × P(city)` = ?

驗證你算出來的數字接近 6041。

### A3 — 為什麼假設錯了

回答：
- `city = 'Taipei'` 的列，`country` 一定是什麼？
- 所以 `country='Taiwan' AND city='Taipei'` 這兩個條件，第二個提供了多少「額外的過濾能力」？
- **正確的選擇率應該是多少？**
- 用一句話說明「欄位獨立性假設」在什麼情況下會失效。

### A4 — 誤估的連鎖效應

估計 6041 vs 實際 25000，**單看這個掃描節點影響不大**（反正都要掃）。

真正的傷害在 JOIN。建一張表測試：

```sql
CREATE TABLE orders7 (id SERIAL PRIMARY KEY, addr_id INT NOT NULL, amount NUMERIC(10,2) NOT NULL);
INSERT INTO orders7 (addr_id, amount)
SELECT (random()*299999+1)::int, (random()*100)::numeric(10,2) FROM generate_series(1,300000);
CREATE INDEX ON orders7 (addr_id);
ANALYZE orders7;
```

```sql
EXPLAIN (ANALYZE, TIMING OFF)
SELECT count(*) FROM addresses a JOIN orders7 o ON o.addr_id = a.id
WHERE a.country='Taiwan' AND a.city='Taipei';
```

實測（無擴充統計）：

```
->  Parallel Hash Join  (cost=2733.04..6582.99 rows=3820 width=0)
                        (actual rows=12518.50 loops=2)
```

回答：
- JOIN 的估計是 3820，實際是 12518（每個 worker）。誤差傳遞下去了。
- **如果誤差再大一個數量級，planner 可能做出什麼災難性的選擇？**
  （提示：想想 Nested Loop 和 Hash Join 的成本模型）

<br>

---

<br>

## Part B — 擴充統計

### B1

```sql
CREATE STATISTICS stat_addr (dependencies, ndistinct, mcv) ON country, city FROM addresses;
ANALYZE addresses;
```

重跑 A1，實測：

```
Bitmap Heap Scan on addresses  (cost=355.75..3278.09 rows=25690 width=36)
                               (actual rows=25000.00 loops=1)
```

**估計 25690 vs 實際 25000 —— 誤差 2.8%。**

### B2 — 看看它學到了什麼

```sql
SELECT stxdndistinct AS ndistinct, stxddependencies AS dependencies
FROM pg_statistic_ext_data d JOIN pg_statistic_ext e ON e.oid = d.stxoid
WHERE e.stxname = 'stat_addr';
```

實測：

```
  ndistinct   |     dependencies
--------------+----------------------
 {"2, 3": 12} | {"3 => 2": 1.000000}
```

回答：
- `{"2, 3": 12}` 是什麼意思？（提示：2 和 3 是欄位編號，查 `pg_attribute`）
- **如果假設獨立，`(country, city)` 的組合數應該是多少？實際是 12。**
- `{"3 => 2": 1.000000}` 是什麼意思？`1.000000` 這個係數代表什麼？
- 反過來 `2 => 3`（country 決定 city）的係數會是多少？為什麼沒出現在結果裡？

### B3 — 三種統計類型

`CREATE STATISTICS` 可以收集三種：

| 類型 | 解決什麼問題 | 什麼查詢會受益 |
|------|-------------|---------------|
| `dependencies` | ? | ? |
| `ndistinct` | ? | ? |
| `mcv` | ? | ? |

**分別只建一種**，測試哪一種對本題的查詢有效。

（提示：`dependencies` 幫 `WHERE a=? AND b=?`；`ndistinct` 幫 `GROUP BY a, b`；`mcv` 幫不等值和特定值的組合）

### B4 — `GROUP BY` 的估計

測試 `ndistinct` 的效果：

```sql
EXPLAIN SELECT country, city, count(*) FROM addresses GROUP BY country, city;
```

有沒有擴充統計，`HashAggregate` 的 `rows=` 估計差多少？

**為什麼這個估計很重要？**（提示：planner 用它決定 hash table 大小、要不要用 `work_mem`、要不要 spill 到磁碟）

<br>

---

<br>

## Part C — 診斷方法論

### C1 — 估計 vs 實際的檢查

**這是效能排查的第一步。** 寫出你的檢查流程：

```
EXPLAIN ANALYZE → 逐節點比對 rows= 和 actual rows=
  ├─ 差距 < 10 倍  → 估計沒問題，往別的方向查
  ├─ 差距 > 10 倍  → ?
  └─ 差距 > 100 倍 → ?
```

每一個分支要往哪裡查？

### C2 — 誤估的常見原因

列出至少**五種**讓 planner 估錯的原因，並各自說明怎麼確認和修正：

- 統計過期（沒 `ANALYZE`）
- 欄位相關（本題）
- `default_statistics_target` 太低
- 資料傾斜（skew）
- 函數/表達式的選擇率無從估計
- JOIN 之後的分布改變

### C3 — `default_statistics_target`

回答：
- 這個參數控制什麼？預設值多少？
- 調高有什麼好處和代價？
- 可以只針對某一欄調高嗎？寫出 DDL。

### C4 — 什麼時候該建擴充統計

回答：
- 每一對欄位都建嗎？代價是什麼？
- 怎麼找出「應該建擴充統計」的欄位組合？
- **寫出一個查詢**，找出「同時出現在 `WHERE` 裡」的欄位組合。
  （提示：`pg_stat_statements` 裡的 query 文字）

<br>

---

<br>

## Part D — 回頭看

### D1

回到 [7-01](../01-the-query-that-got-slower-after-adding-an-index)：那題的 `status` 和 `created_at` 也是相關的（open 的都是舊的）。

**建擴充統計能修好 7-01 嗎？**

```sql
CREATE STATISTICS stat_tickets (dependencies, mcv) ON status, created_at FROM tickets;
ANALYZE tickets;
```

自己測。然後回答：
- 有沒有改善？
- **為什麼？**（提示：7-01 的問題是「`LIMIT` 的提前終止估計」，擴充統計能不能提供這個資訊？）
- 這說明了擴充統計的**能力邊界**在哪？

### D2

**寫出這句結論**：

> 擴充統計解決的是 `______` 的問題，不能解決 `______` 的問題。

<br>

---

<br>

## 面試官的追問

> 1. 「`pg_stats` 這個 view 有哪些欄位？`most_common_vals` / `histogram_bounds` / `correlation` 分別代表什麼？」
>
> 2. 「`correlation` 這個統計值對 planner 的什麼決策有影響？」
>
> 3. 「如果 planner 就是估錯而你改不了，有什麼手段強制它走特定計畫？」
>    （提示：`pg_hint_plan`、改寫查詢、`enable_*` 參數 —— 各自的取捨）
>
> 4. 「`ANALYZE` 是怎麼取樣的？它讀全表嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — planner 的算式</summary>

單欄統計告訴 planner：

- `country` 有 4 個值，各佔 1/4 → `P(country='Taiwan')` = **0.25**
- `city` 有 12 個值，各佔 1/12 → `P(city='Taipei')` = **0.0833**

**獨立性假設**：`P(A AND B) = P(A) × P(B)`

```
300000 × 0.25 × 0.0833 = 6250
```

實測估計是 6041 —— 非常接近（差異來自直方圖與 MCV 的細節）。

**真實情況**：`city='Taipei'` **蘊含** `country='Taiwan'`，所以

```
P(country='Taiwan' AND city='Taipei') = P(city='Taipei') = 0.0833
300000 × 0.0833 = 25000  ✓
```

**加上 `country='Taiwan'` 這個條件，實際上沒有過濾掉任何東西** —— 但 planner 以為它把結果砍到 1/4。

**失效條件**：兩個欄位存在**函數相依**或任何形式的相關性時，獨立性假設就會低估（若正相關）或高估（若負相關）。

</details>

<details>
<summary>Hint 2 — 統計物件學到了什麼</summary>

`{"2, 3": 12}`

- `2` 和 `3` 是 `pg_attribute.attnum`（`country` 是第 2 欄、`city` 是第 3 欄）
- `12` 是這兩欄**組合起來的相異值個數**

**獨立假設下**：4 × 12 = **48** 種組合
**實際**：只有 **12** 種

差了 4 倍 —— 這正好解釋了估計誤差的 4 倍。

<br>

`{"3 => 2": 1.000000}`

- 讀作「**欄位 3（city）決定 欄位 2（country）**」
- 係數 `1.000000` = **100% 成立**（每一個 city 值，對應的 country 值永遠相同）

**反過來 `2 => 3`（country 決定 city）不成立** —— Taiwan 對應 3 個不同的城市。所以係數會遠低於 1（大約 1/3），低於門檻就不會被記錄。

**函數相依是有方向的** —— 這正是 `city → country` 而非反向的原因。

</details>

<details>
<summary>Hint 3 — 三種統計類型的分工</summary>

| 類型 | 解決 | 受益的查詢 |
|------|------|-----------|
| `dependencies` | 函數相依造成的**等值條件**低估 | `WHERE country='Taiwan' AND city='Taipei'` |
| `ndistinct` | 多欄組合的**相異值個數**高估 | `GROUP BY country, city`、`DISTINCT` |
| `mcv` | 特定值組合的頻率、**不等值**條件 | `WHERE country='Taiwan' AND city <> 'Taipei'` |

**`dependencies` 只對等值條件有效** —— 這是很多人不知道的限制。如果你的查詢是 `city > 'M'` 之類的範圍條件，`dependencies` 幫不上忙，要靠 `mcv`。

**`ndistinct` 對 `GROUP BY` 的重要性**（B4）：planner 用「預期分組數」決定：
- Hash Aggregate 的 hash table 要多大
- 會不會超過 `work_mem` 而需要 spill 到磁碟
- 要不要改用 Sort + Group Aggregate

估成 48 組和估成 12 組，在大表上會導致完全不同的執行策略。

</details>

<details>
<summary>Hint 4 — D1 的答案（擴充統計的能力邊界）</summary>

**擴充統計修不好 [7-01](../01-the-query-that-got-slower-after-adding-an-index)。**

原因：兩題的誤估**性質完全不同**。

**7-05（本題）**：planner 估錯的是「**符合條件的列有幾筆**」。這是一個**基數（cardinality）**問題，而擴充統計正是為此設計的。

**7-01**：planner 估對了基數（1% 是 open，它知道）。它估錯的是「**沿著 `created_at` 索引往回走，要走幾列才能湊滿 10 筆 open**」。

這需要的資訊是：「`status='open'` 的列，在 `created_at` 的排序上**分布在哪裡**」——

- 是均勻散布？
- 全部集中在最舊端？
- 集中在最新端？

**PostgreSQL 的統計系統完全沒有這種「A 欄的值在 B 欄排序上的分布」的資訊。**
`dependencies` 只說「A 決定 B」，`mcv` 只說「哪些組合最常見」，兩者都無法表達「位置分布」。

**D2 的結論**：

> 擴充統計解決的是「**多欄條件下的基數估計**」問題，
> 不能解決「**排序位置分布**」造成的 `LIMIT` 提前終止誤判。
>
> 前者靠 `CREATE STATISTICS`，後者只能靠**改索引**（讓過濾欄位進入索引的前綴）。

**這就是為什麼 7-01 的解法是複合索引/部分索引，而不是統計。** 認識工具的能力邊界，比會用工具更重要。

</details>
