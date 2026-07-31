# Phase 5-06 — Days With No Sales

> **難度**：★★★★☆
> **核心技巧**：Calendar spine、**流量 vs 存量**的填補策略、LOCF（前值填補）
> **對應基礎題**：[Phase 1-07. The Report With Missing Rows](../../phase-1-join-dark-side/07-the-report-with-missing-rows)（骨架心法第三次出現）

<br>

---

<br>

## Interview Context

> *面試官：*「營運要一張每日報表：**當天營收**和**當天庫存量**。
>
> 資料有兩個來源：
> - 營收表：只有**有成交**的日子才有一列
> - 庫存快照表：只有**庫存變動**的日子才有一列
>
> 兩張表都有缺漏的日子。工程師寫了 `COALESCE(x, 0)` 就交出去了。
>
> **有一半是對的。** 哪一半？」

<br>

這一題的核心不是 SQL 技巧，是一個**觀念**：缺漏的資料該補什麼，取決於這個欄位是**流量**還是**存量**。補錯了，數字看起來完全正常，但意思完全相反。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS daily_sales;
DROP TABLE IF EXISTS stock_snapshots;

CREATE TABLE daily_sales (              -- 流量：當天賣了多少
    product_id INT NOT NULL,
    sold_on    DATE NOT NULL,
    revenue    NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (product_id, sold_on)
);

CREATE TABLE stock_snapshots (          -- 存量：庫存變動時才記一筆
    product_id INT NOT NULL,
    snap_date  DATE NOT NULL,
    qty        INT NOT NULL,
    PRIMARY KEY (product_id, snap_date)
);

INSERT INTO daily_sales (product_id, sold_on, revenue) VALUES
(1, '2026-03-01', 100),
(1, '2026-03-03', 200),
(1, '2026-03-07', 150);

INSERT INTO stock_snapshots (product_id, snap_date, qty) VALUES
(1, '2026-03-01', 500),
(1, '2026-03-04', 420),
(1, '2026-03-08', 600);
```

<br>

### 正確答案（報表期間 2026-03-01 ~ 2026-03-10）

```
     d      | revenue_filled | qty_raw | qty_locf
------------+----------------+---------+----------
 2026-03-01 |         100.00 |     500 |      500
 2026-03-02 |           0.00 |         |      500
 2026-03-03 |         200.00 |         |      500
 2026-03-04 |           0.00 |     420 |      420
 2026-03-05 |           0.00 |         |      420
 2026-03-06 |           0.00 |         |      420
 2026-03-07 |         150.00 |         |      420
 2026-03-08 |           0.00 |     600 |      600
 2026-03-09 |           0.00 |         |      600
 2026-03-10 |           0.00 |         |      600
```

<br>

> **看 03-02 那一列**：營收補 `0`（那天真的沒賣東西），庫存補 `500`（那天倉庫裡真的還有 500 個）。
> **同一個「缺漏」，兩種完全相反的正確答案。**

<br>

---

<br>

## Part A — 流量 vs 存量

### A1 — 先分類

回答：如果 `2026-03-02` 這一天完全沒有資料 ——

- 「當天營收」是多少？**0** 還是「未知」？
- 「當天庫存」是多少？**0** 還是「和前一天一樣」？
- 用一句話說明兩者的差別。

### A2 — 通用判準

把下列欄位分成「缺漏補 0」和「缺漏補前值（LOCF）」：

| 欄位 | 補 0 還是 LOCF？ | 理由 |
|------|-----------------|------|
| 當日營收 | ? | ? |
| 當日訂單數 | ? | ? |
| 庫存量 | ? | ? |
| 商品售價 | ? | ? |
| 累計註冊人數 | ? | ? |
| 當日新增註冊 | ? | ? |
| 帳戶餘額 | ? | ? |
| 匯率 | ? | ? |

**寫出判準**：怎麼一眼看出一個欄位屬於哪一類？

### A3 — 補錯的後果

回答：
- 如果庫存補 `0`，「平均庫存」會被低估多少？（用本題資料算一次）
- 如果庫存補 `0`，「缺貨天數」這個指標會變成幾天？真實答案是幾天？
- **這個錯誤會不會觸發自動補貨系統？**

<br>

---

<br>

## Part B — 實作

### B1 — 骨架

用 `generate_series` 造出 `2026-03-01` ~ `2026-03-10` 的日期骨架，`LEFT JOIN` 兩張表。

先確認你得到 **10 列**（不是 3 列，也不是 6 列）。

> 條件記得放 `ON` 不要放 `WHERE` —— [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的教訓。

### B2 — 營收補 0

`COALESCE(revenue, 0)`。這部分很簡單。

### B3 — 庫存 LOCF

**這是本題的技術核心。**

PostgreSQL 沒有內建的 `LOCF()` 函數（TimescaleDB 有）。標準做法是兩步：

1. 用 `COUNT(qty) OVER (ORDER BY d ROWS UNBOUNDED PRECEDING)` 產生**分組編號**
2. 在每個分組內用 `FIRST_VALUE(qty)` 取回那個非空值

**先想清楚為什麼這樣可行**，再寫。

提示：`COUNT(欄位)` 只數非 NULL 的（[Phase 2-02](../../phase-2-aggregation-limits/02-filter-vs-case-when) 學過）。所以累計 `COUNT` 在遇到下一個非空值之前**不會變**。

### B4 — 驗證

確認你的 `qty_locf` 是 `500,500,500,420,420,420,420,600,600,600`。

<br>

---

<br>

## Part C — 邊界

### C1 — 開頭的空白

把報表期間改成 `2026-02-25` ~ `2026-03-10`。

- `02-25` ~ `02-28` 的 `qty_locf` 是什麼？
- **這是對的嗎？** 那幾天倉庫裡真的沒東西嗎？還是我們只是不知道？
- 三種處理方式：留 NULL、往後填（NOCB, Next Observation Carried Backward）、去查更早的快照。**你選哪一個？**

### C2 — 多商品

現在有商品 1、2、3，各自的快照日期不同。

- 你的 LOCF 要加什麼？（提示：兩個 window 都要 `PARTITION BY`）
- 骨架要怎麼做？（提示：`CROSS JOIN` —— [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows)）
- **測一次「漏掉 `PARTITION BY`」會發生什麼事** —— 商品 2 會拿到商品 1 的庫存嗎？

### C3 — 資料真的缺，還是本來就沒有

商品 3 在 `2026-03-05` 才第一次進貨。

- 報表期間從 `03-01` 開始，商品 3 的 `03-01` ~ `03-04` 該顯示什麼？
- `0`、`NULL`、還是**根本不該出現這幾列**？
- 怎麼在查詢裡區分「這個商品那時還不存在」和「那時存在但沒有快照」？

<br>

---

<br>

## Part D — 進階填補

### D1 — 線性插值

如果缺漏的是**溫度感測器讀數**（連續變化的物理量），LOCF 就不太合理 —— 更好的做法是**線性插值**。

已知 `03-01 = 20°C`、`03-04 = 26°C`，求 `03-02`、`03-03`。

寫出 SQL 實作（提示：同時需要**前一個**和**後一個**非空值，以及兩者的距離）。

### D2 — 三種填補的適用場景

| 方法 | 適合什麼資料 | 本題哪一欄該用 |
|------|-------------|---------------|
| 補 0 | ? | ? |
| LOCF | ? | ? |
| 線性插值 | ? | ? |

### D3 — 報表要誠實

回答：
- 補值之後的報表，看報表的人分得出「這是實測值」還是「這是補出來的」嗎？
- 你會怎麼在輸出裡標示？
- **為什麼這件事重要？**（提示：如果有人拿這份報表去做迴歸分析…）

<br>

---

<br>

## 面試官的追問

> 1. 「如果報表要跑 5 年 × 10 萬商品，`CROSS JOIN` 骨架會產生多少列？可行嗎？」
>
> 2. 「日期維度表（calendar table）和 `generate_series` 相比有什麼優勢？」
>
> 3. 「TimescaleDB 的 `locf()` 和 `time_bucket_gapfill()` 是做什麼的？和你手寫的差在哪？」
>
> 4. 「如果庫存快照每天都有，但**有幾天的資料是壞的**（qty 是負數），你的 LOCF 要怎麼改？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 流量 vs 存量的判準</summary>

**流量（flow）**：描述「一段期間內發生了多少」。
沒有紀錄 = **那段期間什麼都沒發生** = **0**。

→ 營收、訂單數、當日新增註冊、點擊數

**存量（stock）**：描述「在某個時間點的狀態是什麼」。
沒有紀錄 = **狀態沒有改變** = **和上次一樣**（LOCF）。

→ 庫存量、售價、帳戶餘額、匯率、累計註冊人數

**一句話判準**：

> 問「**這一天**發生了什麼」→ 流量 → 補 0
> 問「**這一天結束時**是什麼狀態」→ 存量 → LOCF

另一個檢查法：**這個欄位加總起來有意義嗎？**
- 「三月營收 = 每天營收相加」✓ → 流量
- 「三月庫存 = 每天庫存相加」✗（毫無意義）→ 存量

</details>

<details>
<summary>Hint 2 — LOCF 的分組技巧</summary>

```sql
WITH spine AS (
    SELECT generate_series('2026-03-01'::date, '2026-03-10'::date, '1 day')::date AS d
),
joined AS (
    SELECT sp.d, s.revenue, k.qty
    FROM spine sp
    LEFT JOIN daily_sales     s ON s.sold_on   = sp.d AND s.product_id = 1
    LEFT JOIN stock_snapshots k ON k.snap_date = sp.d AND k.product_id = 1
),
grouped AS (
    SELECT d, revenue, qty,
           COUNT(qty) OVER (ORDER BY d ROWS UNBOUNDED PRECEDING) AS grp
    FROM joined
)
SELECT d,
       COALESCE(revenue, 0) AS revenue_filled,
       qty AS qty_raw,
       FIRST_VALUE(qty) OVER (PARTITION BY grp ORDER BY d) AS qty_locf
FROM grouped
ORDER BY d;
```

**為什麼 `COUNT` 能當分組編號**：

| d | qty | 累計 COUNT(qty) |
|---|-----|----------------|
| 03-01 | 500 | **1** |
| 03-02 | NULL | **1** |
| 03-03 | NULL | **1** |
| 03-04 | 420 | **2** |
| 03-05 | NULL | **2** |
| … | | |
| 03-08 | 600 | **3** |

`COUNT(qty)` 只數非 NULL —— 所以它在遇到下一個非空值之前**保持不變**。

每一組的**第一列**必定是那個非空值，所以 `FIRST_VALUE(qty)` 就是「最近一次已知的值」。

**這個技巧和 [5-04](../04-the-as-of-join) Hint 3 的 as-of join 完全相同** —— as-of join 本質上就是在時間軸上做 LOCF。

</details>

<details>
<summary>Hint 3 — 多商品的兩個 PARTITION BY</summary>

```sql
COUNT(qty) OVER (PARTITION BY product_id ORDER BY d ROWS UNBOUNDED PRECEDING) AS grp
...
FIRST_VALUE(qty) OVER (PARTITION BY product_id, grp ORDER BY d) AS qty_locf
```

**兩個地方都要 `PARTITION BY product_id`**：
- 第一個：分組編號要按商品各自累計，否則商品 2 的編號會從商品 1 接續下去
- 第二個：`FIRST_VALUE` 的窗要同時按 `product_id` 和 `grp` 分

漏掉任何一個，商品 2 會拿到商品 1 的庫存值 —— **而且不會報錯**。

這和 [Phase 3-05](../../phase-3-window-deep-water/05-sessionization-30-minute-rule) 的「兩個 `PARTITION BY user_id` 都不能漏」是同一個坑。

</details>

<details>
<summary>Hint 4 — D1 線性插值</summary>

需要四個量：前一個非空值、後一個非空值、以及兩者到當前列的距離。

```sql
WITH g AS (
    SELECT d, temp,
           COUNT(temp) OVER (ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  AS gprev,
           COUNT(temp) OVER (ORDER BY d ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS gnext
    FROM joined
),
b AS (
    SELECT d, temp,
           FIRST_VALUE(temp) OVER (PARTITION BY gprev ORDER BY d)      AS prev_v,
           MIN(d)  FILTER (WHERE temp IS NOT NULL) OVER (PARTITION BY gprev) AS prev_d,
           FIRST_VALUE(temp) OVER (PARTITION BY gnext ORDER BY d DESC) AS next_v,
           MAX(d)  FILTER (WHERE temp IS NOT NULL) OVER (PARTITION BY gnext) AS next_d
    FROM g
)
SELECT d, COALESCE(temp,
       prev_v + (next_v - prev_v) * (d - prev_d)::numeric / NULLIF((next_d - prev_d), 0)) AS temp_interp
FROM b ORDER BY d;
```

往前找用 `UNBOUNDED PRECEDING`，往後找用 `UNBOUNDED FOLLOWING` —— **兩個方向各做一次 LOCF**。

`NULLIF(next_d - prev_d, 0)` 防除以零（[Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results) 的防禦習慣）。

**注意**：線性插值需要「未來的資料」—— 所以它**不能用在即時報表上**，只能用在歷史資料的回填。這是 D2 表格裡很值得寫的一句。

</details>
