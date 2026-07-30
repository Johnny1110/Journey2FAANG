# Phase 4-01 — The Org Chart That Loops

> **難度**：★★★★★
> **核心技巧**：遞迴 CTE 環偵測（path array / PG14 `CYCLE` / 深度上限）
> **對應基礎題**：[LC 1270. All People Report to the Given Manager](../../../sql_training/all_people_report_to_the_given_manager)（你當初的遞迴是**往下**找，這題**往上**走）

<br>

---

<br>

## Interview Context

> *面試官：*「我們的 HR 系統有一個功能：點開任何員工，顯示他的完整匯報鏈到 CEO。
>
> 昨天半夜資料庫被打掛了。查下來是這個查詢 —— 它吃光了記憶體。
>
> 資料庫沒有壞，SQL 也沒改過。**是資料變了。**
>
> 找出原因，然後給我一個永遠不會再掛的版本。」

<br>

**這是遞迴 CTE 在正式環境最常見的事故。** 你的 SQL 沒錯，但真實資料裡有環 —— 而遞迴遇到環就是無限迴圈。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS employees;

CREATE TABLE employees (
    id         INT PRIMARY KEY,
    name       VARCHAR(30) NOT NULL,
    manager_id INT,                      -- 我向誰匯報
    salary     NUMERIC(10,2) NOT NULL
);

INSERT INTO employees (id, name, manager_id, salary) VALUES
(1,  'ceo',      NULL, 500000),
(2,  'vp_eng',      1, 300000),
(3,  'vp_sales',    1, 290000),
(4,  'dir_a',       2, 200000),
(5,  'dir_b',       2, 195000),
(6,  'mgr_x',       8, 150000),   -- ← 資料錯誤：應該是 4，被改成了 8
(7,  'mgr_y',       6, 145000),
(8,  'mgr_z',       7, 148000),
(9,  'eng_1',       6, 120000),
(10, 'eng_2',       4, 118000);
```

<br>

> **先不要跑查詢。** 拿紙筆把 `manager_id` 的指向畫成箭頭圖，找出那個環。

<br>

---

<br>

## Part A — 重現事故

### A1 — 健康的情況

```sql
WITH RECURSIVE chain AS (
    SELECT id, name, manager_id, 1 AS depth
    FROM employees WHERE id = 10
    UNION ALL
    SELECT e.id, e.name, e.manager_id, c.depth + 1
    FROM chain c JOIN employees e ON e.id = c.manager_id
)
SELECT * FROM chain;
```

對 `eng_2`（id=10）跑，得到 4 層：`eng_2 → dir_a → vp_eng → ceo`。**這個查詢本身是對的。**

### A2 — 事故現場

> ⚠️ **執行前先設保險絲**，否則你的 session 會卡死：
>
> ```sql
> SET statement_timeout = '2s';
> ```

把 A1 的 `WHERE id = 10` 改成 `WHERE id = 9`（`eng_1`），跑跑看。

你會拿到：

```
ERROR:  canceling statement due to statement timeout
```

### A3 — 診斷

回答：

- `eng_1` 往上走會經過哪些人？寫出前 8 步。
- 環是由哪幾個人組成的？
- **為什麼 `eng_2`（id=10）沒事而 `eng_1`（id=9）會掛？** 兩個人差在哪？
- 遞迴 CTE 的終止條件是什麼？（提示：work table）為什麼有環時這個條件永遠不成立？

### A4 — 為什麼往下找不會掛

你基礎訓練那題（[LC 1270](../../../sql_training/all_people_report_to_the_given_manager)）是從 CEO **往下**找所有下屬。

用同樣的資料，從 `id=1` 往下遞迴（`JOIN employees e ON e.manager_id = c.id`）—— **它不會掛。**

**證明這件事，然後解釋為什麼。**

> 提示：環裡的每個人，他的 `manager_id` 也在環裡。所以從環外往下走，**永遠走不進環**。
> 這是個數學性質，不是巧合。想清楚它，你就同時理解了兩個方向的遞迴。

<br>

---

<br>

## Part B — 三種防禦

### B1 — 方法一：路徑陣列

帶一個 `path` 陣列記錄走過的節點，遞迴時排除已經走過的。

寫出來。你應該得到 **4 行**：

```
 id | name  | depth |   path
----+-------+-------+-----------
  9 | eng_1 |     1 | {9}
  6 | mgr_x |     2 | {9,6}
  8 | mgr_z |     3 | {9,6,8}
  7 | mgr_y |     4 | {9,6,8,7}
```

### B2 — 方法二：PG 14+ 的 `CYCLE` 子句

PostgreSQL 14 加了原生語法：

```sql
) CYCLE id SET is_cycle USING cyc_path
SELECT ... FROM chain;
```

寫出來。你會得到 **5 行** —— 比方法一多一行：

```
 id | name  | depth | is_cycle |       cyc_path
----+-------+-------+----------+-----------------------
  9 | eng_1 |     1 | f        | {(9)}
  6 | mgr_x |     2 | f        | {(9),(6)}
  8 | mgr_z |     3 | f        | {(9),(6),(8)}
  7 | mgr_y |     4 | f        | {(9),(6),(8),(7)}
  6 | mgr_x |     5 | t        | {(9),(6),(8),(7),(6)}   ← 標出環在哪
```

**這一行的差異很重要。** 回答：
- 方法一「悄悄停下來」，方法二「停下來並告訴你為什麼」。哪一個對**除錯**比較有用？
- 如果你要寫一個「找出所有壞掉的匯報鏈」的稽核工具，你會選哪個？
- 生產環境的查詢（給 HR 系統用的）又該選哪個？

### B3 — 方法三：深度上限

```sql
WHERE c.depth < 6
```

跑跑看，你會得到 **6 行**，包含重複的 `mgr_x` 和 `mgr_z`。

回答：
- 它「有效」嗎？它防止了無限迴圈嗎？
- 它的輸出**正確**嗎？
- **什麼情況下深度上限是合理的選擇？**（提示：如果公司層級最多 15 層…）
- 如果上限設太小會怎樣？這種錯誤好發現嗎？

### B4 — 三者對照

| | 路徑陣列 | `CYCLE` 子句 | 深度上限 |
|---|---|---|---|
| 防止無限迴圈 | ? | ? | ? |
| 輸出是否乾淨 | ? | ? | ? |
| 能否指出環在哪 | ? | ? | ? |
| 版本需求 | ? | ? | ? |
| 效能成本 | ? | ? | ? |
| 你什麼時候會用 | ? | ? | ? |

<br>

---

<br>

## Part C — 稽核與修復

### C1 — 找出所有壞掉的鏈

寫一個查詢，掃描**整張表**，找出所有「匯報鏈會繞回自己」的員工，並輸出環的路徑。

預期結果：

```
 start_id | name  |  loop_path
----------+-------+-------------
        6 | mgr_x | {6,8,7,6}
        7 | mgr_y | {7,6,8,7}
        8 | mgr_z | {8,7,6,8}
        9 | eng_1 | {9,6,8,7,6}
```

回答：
- 為什麼 `eng_1`（id=9）也在清單裡？他自己在環裡嗎？
- `6, 7, 8` 三行的 `loop_path` 是同一個環的三種寫法。怎麼把它們**去重**成「一個環」？

### C2 — 在資料庫層面預防

環是**資料問題**，不該靠每個查詢自己防禦。

回答：
- 能不能用 `CHECK` 約束擋掉 `manager_id = id`（自己是自己的主管）？寫出來。
- 能不能用 `CHECK` 擋掉**多層環**？為什麼不行？
- 那要怎麼防？（提示：trigger / 應用層 / 定期稽核 —— 各自的取捨是什麼？）

> **這是 [Phase 6](../../README.md) 的思維預告**：能在寫入端擋掉的，就不要在讀取端防禦。
> 但有些約束（像環偵測）**本質上無法用宣告式約束表達** —— 認識這個界線本身就是答案。

### C3 — 修好資料

寫出修正 `mgr_x` 的 `UPDATE`（應該向 `dir_a` 匯報，id=4）。

修完之後重跑 C1，確認回傳 0 行。

<br>

---

<br>

## 面試官的追問

> 1. 「遞迴 CTE 的執行過程是什麼？`work table` 和 `result table` 分別是什麼？」
>
> 2. 「`UNION` 和 `UNION ALL` 在遞迴 CTE 裡差在哪？如果我用 `UNION`，環還會讓它跑不完嗎？」
>    （**先想，再測**。答案可能跟你想的不一樣 —— [4-07](../07-the-recursion-that-never-ended) 會正式處理這題。）
>
> 3. 「`path` 陣列在 100 萬節點的圖上會有什麼問題？」
>
> 4. 「如果不用遞迴 CTE，還有什麼方式表達層級查詢？」
>    （提示：closure table、nested set、materialized path、`ltree` —— 各自的讀寫取捨）

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 環在哪</summary>

依 `manager_id` 畫箭頭（箭頭指向主管）：

```
  1 (ceo)
  ├── 2 (vp_eng)
  │   ├── 4 (dir_a) ── 10 (eng_2)
  │   └── 5 (dir_b)
  └── 3 (vp_sales)

  環：6 (mgr_x) ──→ 8 (mgr_z) ──→ 7 (mgr_y) ──┐
      ↑                                        │
      └────────────────────────────────────────┘

  9 (eng_1) ──→ 6   ← 掛在環底下
```

`eng_1` 自己不在環裡，但他往上走**會走進環**，然後就出不來了。

`eng_2` 往上走的路徑完全在健康的樹裡，所以沒事。

</details>

<details>
<summary>Hint 2 — 遞迴 CTE 怎麼終止</summary>

執行過程：

1. 跑**非遞迴項**，結果放進 `work table`
2. 跑**遞迴項**，輸入是上一輪的 `work table`
3. 新產生的行成為新的 `work table`
4. **重複，直到某一輪產生 0 行**

有環時，第 4 步永遠不會發生 —— 每一輪都能從環裡再走一步，`work table` 永遠非空。

`result table` 無限成長 → 記憶體吃光 → 資料庫掛掉。

**`statement_timeout` 是你的保險絲。** 任何時候寫遞迴 CTE，先設它。

</details>

<details>
<summary>Hint 3 — 路徑陣列骨架</summary>

```sql
WITH RECURSIVE chain AS (
    SELECT id, name, manager_id, 1 AS depth, ARRAY[id] AS path
    FROM employees WHERE id = 9
    UNION ALL
    SELECT e.id, e.name, e.manager_id, c.depth + 1, c.path || e.id
    FROM chain c
    JOIN employees e ON e.id = c.manager_id
    WHERE NOT (e.id = ANY(c.path))          -- ← 走過的不再走
)
SELECT id, name, depth, path FROM chain;
```

`c.path || e.id` 把新節點接到路徑尾端。
`e.id = ANY(c.path)` 檢查是否已在路徑中。

**成本**：每一步都要掃一次陣列（O(深度)），而且陣列要複製。深度大時會變慢 —— 這是追問 3 的答案。

</details>

<details>
<summary>Hint 4 — C1 的稽核查詢</summary>

```sql
WITH RECURSIVE walk AS (
    SELECT id AS start_id, id, manager_id, ARRAY[id] AS path, false AS looped
    FROM employees                                 -- ← 每個員工都當起點
    UNION ALL
    SELECT w.start_id, e.id, e.manager_id, w.path || e.id, e.id = ANY(w.path)
    FROM walk w
    JOIN employees e ON e.id = w.manager_id
    WHERE NOT w.looped                             -- ← 已偵測到環就停
)
SELECT start_id, path AS loop_path FROM walk WHERE looped ORDER BY start_id;
```

關鍵是 `WHERE NOT w.looped`：**先讓它多走一步把環走出來（標記 `looped = true`），下一輪才停**。

如果寫成 `WHERE NOT (e.id = ANY(w.path))`（像 Hint 3），就會在進環之前停住，你永遠不知道有環 —— 那是「防禦」，這是「偵測」，目的不同。

</details>
