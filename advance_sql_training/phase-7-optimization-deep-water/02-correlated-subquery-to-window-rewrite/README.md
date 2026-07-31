# Phase 7-02 — Correlated Subquery → Window Rewrite

> **難度**：★★★★☆
> **核心技巧**：辨識 N+1 式查詢、`loops=N` 的意義、window function 改寫
> **對應基礎題**：[Phase 1-05. Top-N Four Ways](../../phase-1-join-dark-side/05-top-n-four-ways)（那題 window 輸給 LATERAL，這題反過來）

<br>

---

<br>

## Interview Context

> *面試官：*「這個報表查詢跑 2.4 秒，資料只有 30 萬筆。
>
> 工程師說『我已經加了索引，`EXPLAIN` 顯示有走 Index Scan，應該沒問題了』。
>
> 索引確實有被用到。但這個查詢還是慢了 14 倍。
>
> **`EXPLAIN` 裡有一個數字直接告訴你問題在哪。找出來。**」

<br>

**「有走索引」不等於「快」。** 這一題教你看 `EXPLAIN` 裡最容易被忽略的一個欄位：`loops`。

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

CREATE INDEX ON sales7 (customer_id);
ANALYZE sales7;
```

<br>

---

<br>

## Part A — 慢的版本

### A1

需求：列出 APAC 區的每一筆訂單，並附上**該客戶的總訂單數**和**平均金額**。

工程師的寫法：

```sql
SELECT s.id, s.amount,
       (SELECT count(*)    FROM sales7 x WHERE x.customer_id = s.customer_id) AS cust_cnt,
       (SELECT avg(amount) FROM sales7 y WHERE y.customer_id = s.customer_id) AS cust_avg
FROM sales7 s
WHERE s.region = 'APAC';
```

跑 `EXPLAIN (ANALYZE, BUFFERS)`。

**實測**：

```
Execution Time: 2435 ms
Buffers: shared hit=4,825,469
```

### A2 — 找出那個數字

在計畫裡找到子查詢的節點：

```
->  Aggregate  (cost=215.98..215.99 rows=1 width=8)
    (actual time=0.024..0.024 rows=1.00 loops=75096)
    ->  Bitmap Heap Scan on sales7 x  (actual rows=60.98 loops=75096)
```

**`loops=75096`。**

回答：
- `loops` 是什麼意思？
- 這個子查詢被執行了幾次？
- 外層有幾列（APAC 的訂單數）？兩個數字有什麼關係？
- **兩個子查詢，所以總共執行了幾次？**

### A3 — 為什麼索引沒救到它

回答：
- 每次子查詢執行只花 `0.024 ms` —— **很快**。
- 但 `0.024 ms × 75096 × 2` = 多少？
- **索引讓每一次都很快，但沒有減少「次數」。**
- 用一句話總結：`EXPLAIN` 顯示的單次成本很低時，還要看什麼？

### A4 — `actual time` 的陷阱

`Aggregate` 節點顯示 `actual time=0.024..0.024`。

回答：
- 這是「單次」的時間還是「總共」的時間？（**查文件確認**）
- 那總時間怎麼算？
- **這是 `EXPLAIN ANALYZE` 最容易誤讀的地方。** 寫出正確的讀法。

<br>

---

<br>

## Part B — Window 改寫

### B1

用 window function 重寫：

```sql
SELECT id, amount, cust_cnt, cust_avg
FROM (
    SELECT id, amount, region,
           count(*)    OVER (PARTITION BY customer_id) AS cust_cnt,
           avg(amount) OVER (PARTITION BY customer_id) AS cust_avg
    FROM sales7
) t
WHERE region = 'APAC';
```

**實測**：

```
Execution Time: 170 ms
Buffers: shared hit=296,357
```

**14 倍快，16 倍少的 I/O。**

### B2 — 為什麼快

回答：
- window 版本掃了幾次 `sales7`？
- 它用什麼演算法算出每個客戶的 count/avg？（看計畫裡的節點）
- **為什麼「掃一次全表」會比「掃 15 萬次索引」快？**

### B3 — 陷阱：`WHERE` 的位置

注意 B1 的 `WHERE region='APAC'` 在**外層**，不在子查詢裡。

- 把它移進子查詢（和 window function 同一層）會怎樣？
- 結果會不會變？
- **`cust_cnt` 的語意會變成什麼？**

> 這是 [Phase 3-06](../../phase-3-window-deep-water/06-rolling-7-day-average) Part D 的「`WHERE` 在 window 之前執行」再次出現 ——
> 但這一次，**兩種寫法都「對」，只是回答了不同的問題**。想清楚需求要哪一個。

### B4 — 效能的代價

window 版本要掃**全表** 30 萬列，但只輸出 APAC 的 7.5 萬列。

- 如果 APAC 只佔 0.1%（300 列）呢？兩種寫法哪個快？
- **交叉點在哪？** 寫出你的判斷依據。
- 這和 [Phase 1-05](../../phase-1-join-dark-side/05-top-n-four-ways) 的 LATERAL vs Window 判準是同一個嗎？

<br>

---

<br>

## Part C — 第三種寫法

### C1 — 預聚合 + JOIN

```sql
WITH agg AS (
    SELECT customer_id, count(*) AS cust_cnt, avg(amount) AS cust_avg
    FROM sales7 GROUP BY customer_id
)
SELECT s.id, s.amount, a.cust_cnt, a.cust_avg
FROM sales7 s JOIN agg a ON a.customer_id = s.customer_id
WHERE s.region = 'APAC';
```

跑一次，和 A1、B1 比較。

回答：
- 它掃了幾次表？
- 比 window 版快還是慢？為什麼？
- **這是 [Phase 2-07](../../phase-2-aggregation-limits/07-the-count-that-lied) 的預聚合技巧** —— 那題用它防扇出，這題用它防 N+1。同一個工具兩種用途。

### C2 — 三者對照

| | 相關子查詢 | Window | 預聚合 + JOIN |
|---|---|---|---|
| 執行時間 | 2435 ms | 170 ms | ? |
| Buffers | 4,825,469 | 296,357 | ? |
| 掃表次數 | ? | ? | ? |
| 可讀性 | ? | ? | ? |
| APAC 只佔 0.1% 時 | ? | ? | ? |

### C3 — 什麼時候相關子查詢才是對的

相關子查詢不是永遠都錯。舉出**兩個**它是最佳選擇的場景。

（提示：想想 `EXISTS`、想想外層只有幾列的情況）

<br>

---

<br>

## Part D — 診斷方法論

### D1 — N+1 的辨識特徵

寫出一份**檢查表**：看到 `EXPLAIN` 輸出時，哪些訊號代表「這是 N+1 式查詢」？

- `loops` 的值？
- 節點的巢狀結構？
- `Buffers` 和資料量的比例？

### D2 — 從 `pg_stat_statements` 找出來

回答：
- 哪個欄位能反映「單次很快但呼叫很多次」？
- `shared_blks_hit / calls` 這個比值代表什麼？
- 怎麼找出「總時間最長」而不是「單次最慢」的查詢？

### D3 — 通用改寫規則

**寫出這句結論**：

> 看到 `SELECT ..., (SELECT agg(...) FROM t WHERE t.k = outer.k) FROM ...` 這種形狀，
> 就應該考慮改寫成 `______` 或 `______`，因為 `______`。

<br>

---

<br>

## 面試官的追問

> 1. 「PostgreSQL 的 planner 會自動把相關子查詢改寫成 JOIN 嗎？什麼情況會、什麼情況不會？」
>
> 2. 「如果兩個子查詢的 `WHERE` 條件不同（一個 `customer_id`、一個 `region`），還能用 window 改寫嗎？」
>
> 3. 「`EXPLAIN` 的 `actual time` 在 parallel plan 底下要怎麼讀？」
>
> 4. 「同樣的需求在 ORM（Django / ActiveRecord）裡會產生什麼 SQL？怎麼避免？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — loops 是什麼</summary>

`loops=75096` 代表**這個節點被執行了 75,096 次**。

外層 `WHERE region='APAC'` 有 75,096 列，每一列都觸發一次子查詢。**兩個子查詢 → 總共 150,192 次執行。**

**這就是 N+1**：1 次外層查詢 + N 次內層查詢。

即使每一次都走索引、只花 0.024 ms：

```
0.024 ms × 150,192 ≈ 3,600 ms
```

**索引優化的是「每一次的成本」，但 N+1 的問題是「次數」。**
把單次從 0.024 ms 優化到 0.012 ms，也只是從 3.6 秒變 1.8 秒 —— 而改寫成 window 是 0.17 秒。

</details>

<details>
<summary>Hint 2 — actual time 的正確讀法</summary>

**PostgreSQL 文件明確寫了**：在 `EXPLAIN ANALYZE` 中，巢狀節點的 `actual time` 和 `rows` 都是**「每一次執行的平均值」**，不是總和。

```
->  Aggregate (actual time=0.024..0.024 rows=1.00 loops=75096)
```

意思是：
- 這個節點跑了 75,096 次
- **平均**每次花 0.024 ms
- **平均**每次回傳 1 列

**總時間 = `actual time` × `loops` = 0.024 × 75096 ≈ 1,800 ms**（單一子查詢）

**最常見的誤讀**：看到 `actual time=0.024` 就覺得「這個節點很快，不是瓶頸」—— 忽略了 `loops`。

**正確的讀法**：任何節點看到 `loops > 1`，就要把時間乘上去。

（同理，`Bitmap Heap Scan ... rows=60.98 loops=75096` 代表**總共**掃了 60.98 × 75,096 ≈ 458 萬列 —— 這就是 480 萬 buffers 的來源。）

</details>

<details>
<summary>Hint 3 — B3 的語意差異</summary>

**`WHERE` 在外層**（B1 的寫法）：

```sql
SELECT ... FROM (SELECT ..., count(*) OVER (PARTITION BY customer_id) ... FROM sales7) t
WHERE region='APAC'
```

window 在**全部 30 萬列**上計算 → `cust_cnt` = 「該客戶的**所有**訂單數」→ 和 A1 的相關子查詢**語意相同** ✓

**`WHERE` 在內層**：

```sql
SELECT ..., count(*) OVER (PARTITION BY customer_id) ... FROM sales7 WHERE region='APAC'
```

`WHERE` 先過濾 → window 只在 APAC 的 7.5 萬列上計算 → `cust_cnt` = 「該客戶的 **APAC** 訂單數」

**兩個都是合法的需求，但答案完全不同。**

- 「這筆訂單的客戶總共下過幾單」→ 外層
- 「這筆訂單的客戶在 APAC 下過幾單」→ 內層

**而內層版本會快很多**（只處理 1/4 的資料）。所以要先確認需求 —— 如果需求其實是後者，你連改寫都不用，直接把 `WHERE` 往內移就好。

</details>

<details>
<summary>Hint 4 — D3 的結論與交叉點</summary>

**D3 結論**：

> 看到 `SELECT ..., (SELECT agg(...) FROM t WHERE t.k = outer.k) FROM ...` 這種形狀，
> 就應該考慮改寫成 **window function** 或 **預聚合 + JOIN**，
> 因為**相關子查詢的執行次數等於外層列數，索引只能降低單次成本、無法降低次數**。

**B4 的交叉點**：

令 `N` = 外層列數，`T` = 表總列數。

- 相關子查詢：`N × 索引查找成本`
- Window：`T × 掃描成本 + T log T 排序成本`
- 預聚合 + JOIN：`T × 掃描 + 聚合` 然後 join `N` 列

**N 很小時**（例如 APAC 只有 300 列）：相關子查詢只跑 300 次，而 window 要掃 30 萬列 —— **相關子查詢贏**。

**N 接近 T 時**：window 大勝。

**交叉點大約在 `N × log(T) ≈ T`** —— 和 [Phase 1-05](../../phase-1-join-dark-side/05-top-n-four-ways) Hint 4 的 LATERAL vs Window 判準**是同一個公式**。

**C3 的答案**（相關子查詢是對的場景）：
1. **`EXISTS` / `NOT EXISTS`** —— 語意最清楚，而且 planner 通常會轉成 semi-join，不會真的跑 N 次
2. **外層只有極少列** —— 例如 `WHERE id = 42`，外層 1 列，子查詢跑 1 次

</details>
