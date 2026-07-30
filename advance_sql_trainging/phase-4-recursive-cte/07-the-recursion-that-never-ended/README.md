# Phase 4-07 — The Recursion That Never Ended

> **難度**：★★★★☆
> **核心技巧**：遞迴 CTE 的五種失效模式與除錯
> **性質**：**除錯題** —— 這一章的總複習

<br>

---

<br>

## Interview Context

> *面試官：*「這是我們團隊這一年來因為遞迴 CTE 開的 5 張 bug ticket。
>
> 每一段 SQL 我都給你，你告訴我：**它會發生什麼事、為什麼、怎麼修。**
>
> 有些會報錯，有些不會報錯 —— **不報錯的那幾個比較麻煩。**」

<br>

> ⚠️ **開始之前，先設保險絲**：
>
> ```sql
> SET statement_timeout = '3s';
> ```
>
> 這一題有好幾個會跑不完。沒設的話你的 session 會卡死。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS employees;

CREATE TABLE employees (
    id         INT PRIMARY KEY,
    name       VARCHAR(30) NOT NULL,
    manager_id INT
);

INSERT INTO employees (id, name, manager_id) VALUES
(1, 'ceo',   NULL),
(2, 'alice',    1),
(3, 'bob',      1),
(4, 'carol',    2),
(5, 'dave',     8),    -- 環：5 → 8 → 7 → 5
(6, 'eve',      4),
(7, 'frank',    5),
(8, 'grace',    7);
```

<br>

---

<br>

## Ticket #1 — 「查詢跑不完，資料庫記憶體被吃光」

```sql
WITH RECURSIVE t AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM t
)
SELECT count(*) FROM t;
```

**問題**：
1. 這段會發生什麼事？
2. **缺了什麼？**
3. 寫出修正版，讓它產生 1 到 100。
4. 這種寫法（產生連續數列）有沒有更好的替代？

<br>

---

<br>

## Ticket #2 — 「說我的 CTE 不存在」

```sql
WITH t AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM t WHERE n < 5
)
SELECT * FROM t;
```

**錯誤訊息**：

```
ERROR:  relation "t" does not exist
DETAIL:  There is a WITH item named "t", but it cannot be referenced from this part of the query.
HINT:  Use WITH RECURSIVE, or re-order the WITH items to remove forward references.
```

**問題**：
1. 為什麼 CTE 明明定義了卻說不存在？
2. `WITH` 和 `WITH RECURSIVE` 在**作用域**上差在哪？
3. 如果一個 `WITH RECURSIVE` 底下有 5 個 CTE，只有 1 個是遞迴的，`RECURSIVE` 關鍵字要寫幾次？寫在哪？

<br>

---

<br>

## Ticket #3 — 「加了第二個 JOIN 就報錯」

```sql
WITH RECURSIVE t AS (
    SELECT 1 AS n
    UNION ALL
    SELECT a.n + 1 FROM t a, t b WHERE a.n < 5
)
SELECT * FROM t;
```

**錯誤訊息**：

```
ERROR:  recursive reference to query "t" must not appear more than once
```

**問題**：
1. 為什麼遞迴項只能引用自己一次？（從 work table 的執行模型解釋）
2. 如果我**真的**需要在遞迴中比較「當前層的兩行」，該怎麼做？
3. 遞迴項還有哪些限制？**自己動手測**下面每一個，記錄它是「報錯」還是「能跑」：

   | 在遞迴項裡寫 | 報錯？ | 錯誤訊息 / 實際行為 |
   |---|---|---|
   | 聚合函數（`max(n)+1`） | ? | ? |
   | `ORDER BY` / `LIMIT` | ? | ? |
   | 遞迴 CTE 放在 `LEFT JOIN` 被連接的那一側 | ? | ? |
   | `DISTINCT` | ? | ? |
   | window function（`ROW_NUMBER() OVER ()`） | ? | ? |

   > ⚠️ **最後兩個是陷阱**：它們**不會報錯**。
   > 其中一個能正常運作，另一個會讓查詢**安靜地跑不完**。
   > 測之前先設 `statement_timeout`，然後想清楚為什麼。

<br>

---

<br>

## Ticket #4 — 「型別錯誤，但我看不出哪裡型別不一樣」

```sql
WITH RECURSIVE t AS (
    SELECT 1 AS n, 0 AS total
    UNION ALL
    SELECT n + 1, total + 0.5 FROM t WHERE n < 5
)
SELECT * FROM t;
```

**問題**：
1. 完整的錯誤訊息是什麼？哪一欄有問題？
2. `0` 和 `total + 0.5` 分別是什麼型別？
3. 修正版怎麼寫？
4. 你在 [4-04](../04-manager-chain-with-full-path) 和 [4-05](../05-running-balance-recursive-edition) 各踩過一次這個坑。**把三次的型別問題歸納成一句通則。**

<br>

---

<br>

## Ticket #5 — 「同事說改成 UNION 就好了，真的假的？」

這是本題最有價值的一張 ticket。

### 5a — 有環的資料 + `UNION ALL`

```sql
WITH RECURSIVE c AS (
    SELECT id, manager_id FROM employees WHERE id = 7
    UNION ALL
    SELECT e.id, e.manager_id FROM c JOIN employees e ON e.id = c.manager_id
)
SELECT * FROM c;
```

跑不完（`frank → dave → grace → frank → ...`）。

### 5b — 同事的建議：改成 `UNION`

```sql
WITH RECURSIVE c AS (
    SELECT id, manager_id FROM employees WHERE id = 7
    UNION                                          -- ← 只改這裡
    SELECT e.id, e.manager_id FROM c JOIN employees e ON e.id = c.manager_id
)
SELECT * FROM c;
```

**它跑完了。** 回傳 3 行（`frank`、`dave`、`grace`）。

**問題**：
1. 為什麼 `UNION` 能終止而 `UNION ALL` 不能？（從 work table 的角度解釋）
2. 這算「修好了」嗎？它跟 [4-01](../01-the-org-chart-that-loops) 的 path array 方法**在結果上**有什麼差別？

### 5c — 陷阱

現在加一個 `depth` 欄位（很常見的需求）：

```sql
WITH RECURSIVE c AS (
    SELECT id, manager_id, 1 AS depth FROM employees WHERE id = 7
    UNION
    SELECT e.id, e.manager_id, c.depth + 1 FROM c JOIN employees e ON e.id = c.manager_id
)
SELECT count(*) FROM c;
```

**又跑不完了。**

**問題**：
3. 為什麼加一個 `depth` 欄位，`UNION` 的保護就失效了？
4. **寫出這句結論**：`UNION` 能終止遞迴的前提是 `______`。
5. 所以「改成 `UNION` 就好」這個建議，你會怎麼回覆同事？
6. `UNION` 每一輪都要去重，成本是什麼？在 100 萬節點的圖上，`UNION` 和 path array 哪個快？

<br>

---

<br>

## Part F — 總結

### F1 — 除錯檢查表

把五張 ticket 歸納成一份**遞迴 CTE 除錯檢查表**。

當一段遞迴 CTE 出問題時，依序檢查：

| # | 檢查項 | 症狀 |
|---|--------|------|
| 1 | ? | ? |
| 2 | ? | ? |
| … | | |

### F2 — 寫之前的自我檢查

再寫一份**「動手寫之前」的檢查表**：

- 終止條件是什麼？
- 資料裡可能有環嗎？
- 最大深度大概多少？
- 型別對齊了嗎？
- **保險絲設了嗎？**

### F3 — 保險絲

回答：
- `statement_timeout` 該設在哪一層？（session / 使用者 / 資料庫 / 連線池）
- 正式環境的唯讀分析查詢，你會設多少？
- 除了 timeout，還有什麼防護手段？（提示：`work_mem`、`temp_file_limit`、`max_stack_depth`）

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — Ticket #1 與 #2</summary>

**#1**：遞迴項 `SELECT n + 1 FROM t` **沒有 `WHERE`**，每一輪都會產生新的一行，work table 永遠非空 → 無限。

修法：`WHERE n < 100`。

更好的替代：`generate_series(1, 100)` —— **產生連續數列不需要遞迴**。遞迴 CTE 是給「結構未知的層級/圖」用的，固定數列用內建函數。

**#2**：`WITH`（不加 `RECURSIVE`）的 CTE **不能引用自己**。

`RECURSIVE` 關鍵字寫在 `WITH` 後面，**整個 `WITH` 區塊只寫一次**，即使裡面有 10 個 CTE、只有 1 個是遞迴的：

```sql
WITH RECURSIVE a AS (...),      -- 不遞迴也沒關係
               b AS (...),      -- 這個是遞迴的
               c AS (...)
SELECT ...
```

副作用：加了 `RECURSIVE` 之後，同一個 `WITH` 區塊裡的 CTE **可以互相前向引用**（後面定義的可以被前面引用）。

</details>

<details>
<summary>Hint 2 — Ticket #3 的執行模型</summary>

遞迴 CTE 的執行：

```
work_table ← 非遞迴項的結果
result ← work_table
迴圈：
    new ← 遞迴項(work_table)        ← 輸入「只有」上一輪的 work_table
    if new 是空的: 結束
    result ← result + new
    work_table ← new
```

遞迴項的輸入**就是一份** work table。引用兩次意味著要對它做自我笛卡兒積 —— SQL 標準沒有定義這個語意，所以直接禁止。

**要比較同層的兩行**：把它們放進同一行（用陣列或多個欄位攜帶狀態），或在遞迴**結束後**用 window function 處理。

**Q3 的實測結果**：

| 在遞迴項裡寫 | 報錯？ | 實際行為 |
|---|---|---|
| 聚合函數 | ✅ 報錯 | `aggregate functions are not allowed in a recursive query's recursive term` |
| `ORDER BY` / `LIMIT` | ✅ 報錯 | `ORDER BY in a recursive query is not implemented` |
| 遞迴 CTE 在 outer join 被連接側 | ✅ 報錯 | `recursive reference to query "w" must not appear within an outer join` |
| `DISTINCT` | ❌ **不報錯** | **可以正常運作**（`SELECT DISTINCT n+1 FROM w WHERE n<4` 正確回傳 1,2,3,4） |
| window function | ❌ **不報錯** | **安靜地無限迴圈** |

**window function 那一格是這一題最重要的發現。**

```sql
WITH RECURSIVE w AS (
    SELECT 1::bigint AS n
    UNION ALL
    SELECT ROW_NUMBER() OVER () FROM w WHERE n < 3
) SELECT * FROM w;      -- 跑不完
```

每一輪的 work table 只有 1 行，所以 `ROW_NUMBER() OVER ()` 永遠是 **1** → `n` 永遠是 1 → `n < 3` 永遠成立。

**不報錯 ≠ 可以用。** 遞迴項只看得到「上一輪產生的那幾行」，任何需要看到整個資料集的運算，語意上都是錯的 —— 而 PostgreSQL 不會幫你擋。

</details>

<details>
<summary>Hint 3 — Ticket #4 的型別通則</summary>

`0` 是 `integer`。`total + 0.5` 是 `numeric`。

錯誤訊息：
```
ERROR:  recursive query "t" column 2 has type integer in non-recursive term but type numeric overall
HINT:  Cast the output of the non-recursive term to the correct type.
```

修法：`SELECT 1 AS n, 0::numeric AS total`

**通則（三次踩坑的歸納）**：

> **遞迴 CTE 的欄位型別由「非遞迴項」決定，但必須能容納「遞迴項」產生的所有值。**
> PostgreSQL 不會自動放寬型別 —— 你必須在**非遞迴項**顯式轉型成最終要的型別。

三次的具體形式：
- [4-04](../04-manager-chain-with-full-path)：`VARCHAR(30)` vs `text`（**長度限制**也算不同型別）
- [4-05](../05-running-balance-recursive-edition)：`integer` vs `bigint`（`ROW_NUMBER()` 回傳 bigint）
- [4-05](../05-running-balance-recursive-edition)：`NUMERIC(12,2)` vs `NUMERIC`（**精度限制**也算）

**心法：非遞迴項的每一個常數和欄位，都主動加上你要的型別轉換。** 省不了幾個字，但省下很多困惑。

</details>

<details>
<summary>Hint 4 — Ticket #5 的完整答案</summary>

**為什麼 `UNION` 能終止**：

`UNION` 會對**整個累積結果**去重。第二次走到 `frank` 時，`(7, 5)` 這一行已經在 result 裡了 → 被去掉 → 該輪產生 0 行新資料 → **終止**。

**為什麼加 `depth` 就失效**：

第一次走到 frank 是 `(7, 5, 1)`，第二次是 `(7, 5, 4)`，第三次 `(7, 5, 7)`……

**`depth` 每一圈都不同，所以每一行都是「新」的**，去重完全不起作用 → 無限迴圈。

**結論（5.4 的答案）**：

> `UNION` 能終止遞迴的前提是：**重複走訪同一個節點時，產生的整行資料完全相同**。
> 任何「隨路徑變化的欄位」（depth、path、累計值）都會破壞這個前提。

**怎麼回覆同事**（5.5）：

> 「`UNION` 在你這個例子剛好有效，但它是**巧合**不是**解法**。只要之後有人加一個 depth 或 path 欄位，保護就失效了 —— 而且會在生產環境才爆。而且 `UNION` 每輪都要對整個累積結果做去重，圖大的時候很貴。
>
> 我建議用 path array 明確排除走過的節點，或者 PG14 以上用 `CYCLE` 子句 —— 這兩種的保護和欄位無關，而且看得出意圖。」

**效能**（5.6）：`UNION` 每輪對**整個 result** 去重是 O(結果總量)；path array 每步只查一個小陣列是 O(深度)。圖大時 path array 明顯勝出。

</details>
