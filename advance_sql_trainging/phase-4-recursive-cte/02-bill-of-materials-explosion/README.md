# Phase 4-02 — Bill of Materials Explosion

> **難度**：★★★★★
> **核心技巧**：遞迴 + 數量沿路徑**累乘**、跨路徑**加總**
> **對應基礎題**：[LC 1384. Total Sales Amount by Year](../../../sql_training/total_sales_amount_by_year)（你當初的遞迴生成序列）

<br>

---

<br>

## Interview Context

> *面試官：*「製造業的經典問題。
>
> 一台腳踏車由 2 個輪子 + 1 個車架 + 1 個座墊組成。
> 一個輪子由 36 根輻條 + 1 個輪圈 + 1 個外胎 + 4 顆螺絲組成。
> 外胎由橡膠和氣嘴組成。車架由鋼管、焊點、**還有 6 顆螺絲**組成。
>
> 採購問我：**做 1 台腳踏車，要買幾顆螺絲？**
>
> 提醒你，螺絲出現在兩個地方。」

<br>

BOM 展開（BOM explosion）是遞迴 CTE 最經典的商業應用。它比組織圖難的地方在於：**數量要沿著路徑相乘，而同一個零件可能透過多條路徑抵達，最後要相加。**

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS bom;

CREATE TABLE bom (
    parent_sku VARCHAR(20) NOT NULL,
    child_sku  VARCHAR(20) NOT NULL,
    qty        INT NOT NULL,           -- 每 1 個 parent 需要幾個 child
    PRIMARY KEY (parent_sku, child_sku)
);

INSERT INTO bom (parent_sku, child_sku, qty) VALUES
('BIKE',  'WHEEL',   2),
('BIKE',  'FRAME',   1),
('BIKE',  'SEAT',    1),
('WHEEL', 'SPOKE',  36),
('WHEEL', 'RIM',     1),
('WHEEL', 'TIRE',    1),
('WHEEL', 'BOLT',    4),      -- ← 螺絲出現在這裡
('TIRE',  'RUBBER',  1),
('TIRE',  'VALVE',   1),
('FRAME', 'TUBE',    4),
('FRAME', 'WELD',    8),
('FRAME', 'BOLT',    6);      -- ← 螺絲也出現在這裡
```

<br>

### 正確答案

```
  part  | qty_needed
--------+------------
 BOLT   |         14      ← 2×4 + 1×6，兩條路徑相加
 RIM    |          2
 RUBBER |          2
 SEAT   |          1
 SPOKE  |         72      ← 2×36
 TUBE   |          4
 VALVE  |          2
 WELD   |          8
```

<br>

---

<br>

## Part A — 展開

### A1 — 先手算

**不要碰鍵盤。** 算出這三個：

- `SPOKE`（輻條）：1 台車要幾根？
- `RUBBER`（橡膠）：幾份？（注意它在第 3 層）
- `BOLT`（螺絲）：幾顆？

寫下你的計算過程。**A1 算對了，SQL 就只是把過程翻譯出來。**

### A2 — 遞迴展開

寫出遞迴 CTE，輸出每一條展開路徑與累計數量：

```
 lvl |             path             | total_qty
-----+------------------------------+-----------
   1 | BIKE > FRAME                 |         1
   1 | BIKE > SEAT                  |         1
   1 | BIKE > WHEEL                 |         2
   2 | BIKE > FRAME > BOLT          |         6
   2 | BIKE > FRAME > TUBE          |         4
   2 | BIKE > FRAME > WELD          |         8
   2 | BIKE > WHEEL > BOLT          |         8
   2 | BIKE > WHEEL > RIM           |         2
   2 | BIKE > WHEEL > SPOKE         |        72
   2 | BIKE > WHEEL > TIRE          |         2
   3 | BIKE > WHEEL > TIRE > RUBBER |         2
   3 | BIKE > WHEEL > TIRE > VALVE  |         2
```

關鍵是遞迴項裡的數量怎麼算 —— **不是 `qty`，也不是 `qty + qty`。**

### A3 — 只要葉節點

採購只關心**買得到的原料**（葉節點：沒有再往下拆的零件），不關心 `WHEEL`、`TIRE`、`FRAME` 這些中間組件。

改寫查詢，只輸出葉節點並加總，得到上面那張正確答案表。

**怎麼判斷一個 SKU 是葉節點？** 寫出條件。

### A4 — BOLT 的驗證

盯著 `BOLT` 那兩行：

```
   2 | BIKE > FRAME > BOLT          |         6
   2 | BIKE > WHEEL > BOLT          |         8
```

回答：
- 為什麼是 6 和 8，不是 6 和 4？
- 如果你的 A3 用了 `MAX()` 或忘記 `GROUP BY`，答案會變成什麼？
- **如果 BOM 只有一條路徑通往每個零件，這個 bug 會被發現嗎？**

> 又是那個模式：**單一路徑的資料會讓錯誤的查詢看起來是對的。**
> 這就是為什麼我把 `BOLT` 放進兩個組件。

<br>

---

<br>

## Part B — 反向查詢（Where-Used）

BOM 有兩種標準查詢：**explosion**（往下拆）和 **implosion / where-used**（往上找）。

### B1

寫出反向查詢：給定一個零件（例如 `BOLT`），找出**所有用到它的上層組件**，一直往上追到最終產品。

```
 part | used_in | path
------+---------+---------------------
 BOLT | WHEEL   | BOLT < WHEEL
 BOLT | FRAME   | BOLT < FRAME
 BOLT | BIKE    | BOLT < WHEEL < BIKE
 BOLT | BIKE    | BOLT < FRAME < BIKE
```

### B2

**商業情境**：供應商通知 `RUBBER` 有瑕疵要召回。

寫一個查詢回答：「**哪些成品受影響？**」

### B3

回答：explosion 和 implosion 在遞迴 CTE 裡的差異，只有一個地方不同。是哪裡？

<br>

---

<br>

## Part C — 真實世界的髒東西

### C1 — 環

有人手滑，把 `SPOKE` 設成需要 1 個 `WHEEL`：

```sql
INSERT INTO bom VALUES ('SPOKE', 'WHEEL', 1);
```

> ⚠️ 執行前先 `SET statement_timeout = '2s';`

跑你 A2 的查詢，會發生什麼事？

用 [4-01](../01-the-org-chart-that-loops) 學的三種方法之一防禦它，並寫出**偵測 BOM 環**的稽核查詢。

（測完記得 `DELETE FROM bom WHERE parent_sku='SPOKE';`）

### C2 — 數量爆炸

如果 BOM 有 8 層深，每層平均 5 個子零件，展開後會有幾行？

- 寫出通式
- 這對記憶體和執行時間的意義是什麼？
- **有沒有辦法在展開過程中就先聚合**，而不是先展開幾百萬行再 `GROUP BY`？

### C3 — 小數與單位

真實 BOM 的 `qty` 常常是小數（0.5 公升油漆）而且有單位（公斤、公升、個）。

- `qty INT` 改成 `NUMERIC` 後，累乘的精度會有什麼問題？
- 如果 `WHEEL` 需要 0.1 公升油漆，`BIKE` 需要 2 個 `WHEEL`，答案是 0.2 公升。連乘 8 層之後呢？
- 單位不同的零件混在同一張表，`SUM` 會發生什麼事？schema 該怎麼改？

<br>

---

<br>

## 面試官的追問

> 1. 「這個查詢每次採購都要跑一次，BOM 有 50 萬筆。你會怎麼優化？」
>    （提示：物化 —— 但 BOM 改了怎麼辦？）
>
> 2. 「如果要算的是**成本**而不是數量，查詢要怎麼改？成本可以沿路徑累乘嗎？」
>
> 3. 「要做『生產 1000 台車的採購清單，扣掉現有庫存』，怎麼寫？」
>
> 4. 「`WITH RECURSIVE` 的 `SEARCH DEPTH FIRST` / `SEARCH BREADTH FIRST` 子句是什麼？這題該用哪個？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 手算</summary>

**SPOKE**：`BIKE → WHEEL(×2) → SPOKE(×36)` = 2 × 36 = **72**

**RUBBER**：`BIKE → WHEEL(×2) → TIRE(×1) → RUBBER(×1)` = 2 × 1 × 1 = **2**

**BOLT**：兩條路徑
- `BIKE → WHEEL(×2) → BOLT(×4)` = 2 × 4 = 8
- `BIKE → FRAME(×1) → BOLT(×6)` = 1 × 6 = 6
- 合計 = **14**

**核心規則**：**沿路徑相乘，跨路徑相加。**

</details>

<details>
<summary>Hint 2 — 遞迴骨架</summary>

```sql
WITH RECURSIVE ex AS (
    SELECT parent_sku, child_sku,
           qty AS total_qty,                       -- 第一層就是 qty 本身
           1 AS lvl,
           parent_sku || ' > ' || child_sku AS path
    FROM bom
    WHERE parent_sku = 'BIKE'
    UNION ALL
    SELECT b.parent_sku, b.child_sku,
           e.total_qty * b.qty,                    -- ← 累乘，不是累加
           e.lvl + 1,
           e.path || ' > ' || b.child_sku
    FROM ex e
    JOIN bom b ON b.parent_sku = e.child_sku       -- ← 上一層的 child 變這一層的 parent
)
SELECT lvl, path, total_qty FROM ex ORDER BY lvl, path;
```

兩個關鍵：
- `e.total_qty * b.qty` —— 數量是**乘**上去的（和組織圖的 `depth + 1` 完全不同）
- `b.parent_sku = e.child_sku` —— 遞迴往下的接法

</details>

<details>
<summary>Hint 3 — 葉節點與加總</summary>

```sql
SELECT e.child_sku AS part, SUM(e.total_qty) AS qty_needed
FROM ex e
WHERE NOT EXISTS (SELECT 1 FROM bom b WHERE b.parent_sku = e.child_sku)   -- ← 葉節點
GROUP BY e.child_sku
ORDER BY 1;
```

**葉節點的定義**：它不曾以 `parent_sku` 出現過 —— 也就是沒有東西可以再往下拆。

這是 [Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results) 的 anti-join 又出現了。
用 `NOT EXISTS` 而不是 `NOT IN` —— 這裡 `parent_sku` 是主鍵一部分不會是 NULL，但**習慣要一致**。

`SUM` + `GROUP BY` 就是「跨路徑相加」。少了它，`BOLT` 會變成兩行（6 和 8）而不是一行 14。

</details>

<details>
<summary>Hint 4 — C2 的邊展開邊聚合</summary>

遞迴 CTE **不能**在遞迴過程中聚合 —— 遞迴項裡不允許 `GROUP BY` / 聚合函數。

所以只能先展開再聚合。這就是 BOM 展開在大型製造系統裡很貴的原因。

實務解法：
- **物化**：把展開結果存成一張 `bom_exploded` 表，BOM 變動時用 trigger 或排程重算
- **限制深度**：多數 BOM 不超過 10 層，加深度上限避免失控
- **只展開需要的產品**：不要一次展開整個目錄

追問 1 的完整答案是：**物化 + 增量更新**，而增量更新的難點是「改了一個底層零件，要重算所有用到它的成品」—— 也就是 Part B 的 where-used 查詢。**兩個方向的查詢在真實系統裡是搭配使用的。**

</details>
