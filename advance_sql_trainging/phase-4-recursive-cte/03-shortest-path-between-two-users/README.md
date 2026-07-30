# Phase 4-03 — Shortest Path Between Two Users

> **難度**：★★★★★
> **核心技巧**：遞迴 BFS、無向圖處理、visited-set 剪枝、最短路徑
> **對應基礎題**：[LC 602. Friend Requests II](../../../sql_training/friend_reequests_ii)（你當初只算了一層好友）

<br>

---

<br>

## Interview Context

> *面試官：*「LinkedIn 會顯示『你和這個人是二度人脈』。實作它。
>
> 給我兩個 user_id，回答他們相隔幾度，以及一條最短的連結路徑。
>
> 順便告訴我，為什麼這個功能在真實的 LinkedIn 上**不是**用 SQL 做的。」

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS friendships;

CREATE TABLE friendships (
    a INT NOT NULL,
    b INT NOT NULL,
    PRIMARY KEY (a, b)
);

-- 好友關係是「無向」的，但每一對只存一次
INSERT INTO friendships (a, b) VALUES
(1, 2), (2, 3), (3, 4), (4, 5),    -- 一條長鏈：1→2→3→4→5
(1, 6), (6, 5),                    -- 一條捷徑：1→6→5
(2, 7), (7, 8),                    -- 支線
(9, 10);                           -- 完全不相連的另一個社群
```

<br>

### 正確答案（從 user 1 出發）

```
 node | shortest_hops |   path
------+---------------+-----------
    1 |             0 | {1}
    2 |             1 | {1,2}
    6 |             1 | {1,6}
    3 |             2 | {1,2,3}
    5 |             2 | {1,6,5}      ← 走捷徑，不是長鏈的 4 度
    7 |             2 | {1,2,7}
    4 |             3 | {1,2,3,4}
    8 |             3 | {1,2,7,8}
```

`user 9` 和 `user 10` **不可達**。

<br>

> **user 5 是關鍵測資**：沿長鏈走是 4 度，走捷徑是 2 度。
> 你的查詢如果回傳 4，代表它找到的是「某一條路徑」而不是「最短路徑」。

<br>

---

<br>

## Part A — 無向圖

### A1

`friendships` 只存了 `(1,2)`，沒有存 `(2,1)`。但好友關係是雙向的。

如果你直接 `JOIN friendships f ON f.a = current_node`，會發生什麼事？從 user 5 出發試試看。

### A2

寫出處理雙向的方法。至少兩種：

- 建一個 `VIEW`（或 CTE）把每條邊展開成兩個方向
- 在 `JOIN` 條件裡用 `OR` 同時比對兩欄

哪一種好？跑 `EXPLAIN` 比較 —— **特別注意 `OR` 條件對索引的影響**。

### A3

如果 schema 改成「每對關係存兩行」（`(1,2)` 和 `(2,1)` 都存），會有什麼好處和壞處？

- 查詢會變簡單嗎？
- 儲存空間？
- **資料一致性**：怎麼保證兩行永遠同時存在、同時刪除？

<br>

---

<br>

## Part B — BFS

### B1 — 不剪枝會怎樣

先寫一個**沒有 visited-set** 的版本：

```sql
WITH RECURSIVE bfs AS (
    SELECT 1 AS node, 0 AS hops
    UNION ALL
    SELECT e.dst, b.hops + 1 FROM bfs b JOIN edges e ON e.src = b.node
)
SELECT * FROM bfs;
```

> ⚠️ 先 `SET statement_timeout = '2s';`

會發生什麼事？**為什麼？**（提示：1→2→1→2→1…）

這和 [4-01](../01-the-org-chart-that-loops) 的環是同一個問題嗎？有什麼不同？

> **注意**：這裡的「環」不是資料錯誤 —— 無向圖裡**每一條邊本身就是一個 2-環**。
> 也就是說，無向圖的遞迴遍歷**永遠**需要剪枝，不是「以防萬一」。

### B2 — 加上 visited-set

用 `path` 陣列剪枝，寫出正確版本。

驗證它產生 **15 行**（每個節點可能有多條路徑）。

### B3 — 取最短

B2 產生了所有路徑。現在要每個節點的**最短**那一條。

用 `DISTINCT ON` 寫出來（[Phase 2-04](../../phase-2-aggregation-limits/04-the-mode-that-ties) 學過的取捨在這裡會用上）。

> ⚠️ 陷阱：`ARRAY_AGG(path ORDER BY hops)` 會報錯：
> ```
> ERROR:  cannot accumulate arrays of different dimensionality
> ```
> 因為不同路徑長度不同。想想怎麼繞過。

### B4 — 兩個特定使用者

包成一個查詢：給定 `from_id` 和 `to_id`，回傳度數和路徑。

- user 1 → user 5：應該是 **2**
- user 1 → user 8：應該是 **3**
- user 1 → user 10：應該回傳什麼？（**不是 0，也不是 NULL 行 —— 想清楚該回傳什麼**）

<br>

---

<br>

## Part C — 效能

### C1 — 提早停止

B3 展開了**整個連通分量**才取最短。如果只要知道 1 和 5 的距離，這是浪費。

- 遞迴 CTE 能不能「找到目標就停」？
- 加上 `WHERE hops < 3`（LinkedIn 只顯示到三度）會有幫助嗎？
- 為什麼遞迴 CTE **無法**真正做到「找到就停」？

### C2 — 規模

社群圖有 10 億使用者，平均每人 200 個好友。

- 從一個節點做 3 度 BFS，會碰到幾個節點？（寫出計算）
- `path` 陣列在這個規模下的記憶體成本？
- **這就是追問「為什麼 LinkedIn 不用 SQL 做」的答案。** 寫出完整理由。

### C3 — 那真實系統怎麼做

回答（講得出方向即可）：
- 雙向 BFS（從兩端同時搜）能省多少？
- 為什麼圖資料庫（Neo4j）或專用的圖服務比較適合？
- LinkedIn 實際上怎麼做？（提示：預先計算 + 快取 + 近似）

<br>

---

<br>

## 面試官的追問

> 1. 「如果邊有**權重**（親密度），要找『權重和最小』的路徑，遞迴 CTE 做得到嗎？」
>    （提示：那是 Dijkstra，不是 BFS。想想差在哪）
>
> 2. 「`SEARCH BREADTH FIRST BY ... SET ...` 子句是什麼？用它能簡化這題嗎？」
>
> 3. 「如果要算『每個人的二度人脈總數』（不是路徑），查詢會簡單很多。怎麼寫？」
>
> 4. 「怎麼驗證你的最短路徑真的是最短的？寫一個測試。」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 雙向邊</summary>

```sql
CREATE VIEW edges AS
SELECT a AS src, b AS dst FROM friendships
UNION ALL
SELECT b, a FROM friendships;
```

`UNION ALL` 不是 `UNION` —— 因為 `(a,b)` 和 `(b,a)` 在原表裡只存一次，展開後不會有重複，用 `ALL` 省掉去重成本。

**用 `OR` 的替代寫法**：

```sql
JOIN friendships f ON (f.a = b.node OR f.b = b.node)
```

能跑，但 `OR` 讓 planner 很難用索引 —— 通常會退化成 Seq Scan 或 BitmapOr。**`UNION ALL` 展開成兩個可各自走索引的分支，幾乎總是比較快。**

</details>

<details>
<summary>Hint 2 — 為什麼無向圖一定要剪枝</summary>

邊 `1—2` 在 `edges` 裡是兩行：`(1→2)` 和 `(2→1)`。

所以 BFS 從 1 走到 2，下一步又能從 2 走回 1，再走到 2……**無限往返**。

這和 [4-01](../01-the-org-chart-that-loops) 的差別很重要：

| | 4-01 組織圖 | 4-03 社群圖 |
|---|---|---|
| 環是什麼 | **資料錯誤** | **正常結構** |
| 沒有環時 | 遞迴自然終止 | 仍然會無限迴圈 |
| 剪枝是 | 防禦性措施 | **必要條件** |

**無向圖的遍歷，visited-set 不是選配。**

</details>

<details>
<summary>Hint 3 — BFS 骨架與取最短</summary>

```sql
WITH RECURSIVE bfs AS (
    SELECT 1 AS node, 0 AS hops, ARRAY[1] AS path
    UNION ALL
    SELECT e.dst, b.hops + 1, b.path || e.dst
    FROM bfs b
    JOIN edges e ON e.src = b.node
    WHERE NOT (e.dst = ANY(b.path))
)
SELECT DISTINCT ON (node) node, hops AS shortest_hops, path
FROM bfs
ORDER BY node, hops, path;          -- ← hops 排前面，所以每組取到的是最短那條
```

`DISTINCT ON (node)` 配 `ORDER BY node, hops` —— 每個 node 保留 `hops` 最小的那一行。

這正是 [Phase 2-04](../../phase-2-aggregation-limits/04-the-mode-that-ties) Hint 3 說的「`DISTINCT ON` 的定位是每組取一筆」。**Top-1 用它最短。**

（`ORDER BY` 最後加 `path` 是 tie-breaker —— 同樣長度的多條路徑要有決定性的選擇，否則結果不穩定。這是 [Phase 2-04](../../phase-2-aggregation-limits/04-the-mode-that-ties) 的非決定性問題。）

</details>

<details>
<summary>Hint 4 — 為什麼不能「找到就停」</summary>

遞迴 CTE 的終止條件是「**某一輪產生 0 行**」。它沒有 `break`。

你可以寫 `WHERE hops < 3` 限制深度，但那是**限制總深度**，不是「找到目標就停」—— 即使第 1 層就找到了目標，它還是會把第 2、3 層全部展開。

實務上的折衷：
```sql
WHERE NOT (e.dst = ANY(b.path)) AND b.hops < 3 AND b.node <> 5
```
最後那個條件讓「已經到達目標」的分支不再往外擴 —— 有幫助，但其他分支還是會走完。

**這是遞迴 CTE 的本質限制**：它是集合導向的批次展開，不是逐步的圖走訪。真正的 BFS 演算法有 queue 和 early exit，SQL 沒有。

C2 的計算：3 度 × 每人 200 好友 = 200³ = **800 萬個節點**（還沒扣重複）。每個節點帶一個長度 4 的陣列。這就是為什麼 LinkedIn 不用 SQL。

</details>
