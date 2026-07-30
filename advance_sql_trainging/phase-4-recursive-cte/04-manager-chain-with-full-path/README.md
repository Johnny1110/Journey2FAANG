# Phase 4-04 — Manager Chain With Full Path

> **難度**：★★★★☆
> **核心技巧**：路徑字串、層級深度、**子樹聚合**（每個節點的整個下屬樹）
> **對應基礎題**：[LC 1270. All People Report to the Given Manager](../../../sql_training/all_people_report_to_the_given_manager)（你當初只列出下屬名單）

<br>

---

<br>

## Interview Context

> *面試官：*「HR 要一份組織報表：
>
> 1. 每個人的完整匯報路徑（`ceo > vp_eng > dir_a > eng_2`）和層級
> 2. **每個主管底下總共有幾個人、總薪資是多少** —— 含間接下屬
>
> 第 2 點是重點。VP 底下有 7 個人，不是只有直屬的 2 個。」

<br>

[4-01](../01-the-org-chart-that-loops) 教你怎麼**不要爆炸**。這一題教你遞迴的**實際產出**：路徑、深度、以及最有價值的**子樹聚合**。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS org;

CREATE TABLE org (
    id         INT PRIMARY KEY,
    name       VARCHAR(30) NOT NULL,
    manager_id INT,
    salary     NUMERIC(10,2) NOT NULL
);

INSERT INTO org (id, name, manager_id, salary) VALUES
(1,  'ceo',      NULL, 500000),
(2,  'vp_eng',      1, 300000),
(3,  'vp_sales',    1, 290000),
(4,  'dir_a',       2, 200000),
(5,  'dir_b',       2, 195000),
(6,  'mgr_x',       4, 150000),
(7,  'mgr_y',       6, 145000),
(8,  'mgr_z',       5, 148000),
(9,  'eng_1',       6, 120000),
(10, 'eng_2',       4, 118000);
```

<br>

> 這是 [4-01](../01-the-org-chart-that-loops) **修好之後**的資料 —— 沒有環。這一題專心處理輸出。

<br>

---

<br>

## Part A — 路徑與深度

### A1

寫出遞迴 CTE，輸出每個人的深度與完整路徑，並用縮排畫出組織圖：

```
 depth |     chart     |  salary   |                 path
-------+---------------+-----------+--------------------------------------
     1 | ceo           | 500000.00 | ceo
     2 |   vp_eng      | 300000.00 | ceo > vp_eng
     3 |     dir_a     | 200000.00 | ceo > vp_eng > dir_a
     4 |       eng_2   | 118000.00 | ceo > vp_eng > dir_a > eng_2
     4 |       mgr_x   | 150000.00 | ceo > vp_eng > dir_a > mgr_x
     5 |         eng_1 | 120000.00 | ceo > vp_eng > dir_a > mgr_x > eng_1
     5 |         mgr_y | 145000.00 | ceo > vp_eng > dir_a > mgr_x > mgr_y
     3 |     dir_b     | 195000.00 | ceo > vp_eng > dir_b
     4 |       mgr_z   | 148000.00 | ceo > vp_eng > dir_b > mgr_z
     2 |   vp_sales    | 290000.00 | ceo > vp_sales
```

提示：`repeat('  ', depth-1) || name` 做縮排。

### A2 — 排序才是難點

上面的輸出**不是**依 `id` 或 `depth` 排的 —— 它是**深度優先**的組織圖順序（每個主管後面緊接著他的整棵子樹）。

- 用什麼欄位 `ORDER BY` 才能得到這個順序？
- 為什麼 `ORDER BY depth` 不對？（試一次看看）
- 如果名字裡有 `>` 這個字元，你的排序會出什麼問題？怎麼防？

### A3 — 路徑用陣列而不是字串

把 `path` 從字串改成 `INT[]`（存 id）。

- 排序行為會不會改變？
- 哪一種比較適合「判斷 A 是不是 B 的下屬」？寫出那個查詢。
- 哪一種比較適合給人看？
- **兩個都存**是不是合理的做法？

<br>

---

<br>

## Part B — 子樹聚合（重點）

### B1

寫出每個主管的**子樹統計**：底下總共幾個人（含間接）、子樹總薪資（不含自己）。

```
 manager  | reports_below | subtree_payroll
----------+---------------+-----------------
 ceo      |             9 |      1666000.00
 vp_eng   |             7 |      1076000.00
 dir_a    |             4 |       533000.00
 mgr_x    |             2 |       265000.00
 dir_b    |             1 |       148000.00
 eng_1    |             0 |            0.00
 eng_2    |             0 |            0.00
 mgr_y    |             0 |            0.00
 mgr_z    |             0 |            0.00
 vp_sales |             0 |            0.00
```

**核心技巧**：遞迴的起點不是「一個根」，而是「**每一個節點都當一次根**」。

### B2 — 驗算

- `ceo` 的 `reports_below` 是 9 —— 全公司 10 人扣掉自己。✓
- `vp_eng` 是 7 —— 手動數一次確認。
- `dir_a` 是 4 —— 哪 4 個？
- **`subtree_payroll` 為什麼要 `- o.salary`？** 如果不扣會變成什麼？

### B3 — 「不含自己」vs「含自己」

HR 又說：「我要的是**含主管本人**的部門總成本。」

改一個字就好。改哪裡？

**然後回答**：這兩個數字（含/不含）在報表上該怎麼命名，才不會讓看報表的人誤解？

### B4 — 直屬 vs 全部

再加一欄 `direct_reports`（只算直屬下屬）。

```
 manager | direct_reports | reports_below
---------+----------------+---------------
 ceo     |              2 |             9
 vp_eng  |              2 |             7
 dir_a   |              2 |             4
```

- 這一欄需要遞迴嗎？
- 把兩者放在一起，能看出什麼組織問題？（提示：`direct_reports` 很大代表什麼？兩者差很多代表什麼？）

<br>

---

<br>

## Part C — 實務考量

### C1 — 效能

B1 的做法是「每個節點都當一次根跑一次遞迴」。

- 10 個人的表，這個查詢展開成幾行？（自己數）
- 10 萬人的組織呢？寫出通式（提示：和樹的**平均深度**有關）
- 有沒有更省的做法？（提示：想想 A3 的 `path` 陣列 —— 如果每個人都知道自己的完整祖先清單…）

### C2 — 用 path 陣列一次做完

利用 A3 的 `path INT[]`，**不用第二次遞迴**就算出子樹聚合。

思路：如果 `eng_1` 的 path 是 `{1,2,4,6,9}`，那 `eng_1` 就屬於 `1`、`2`、`4`、`6` 每一個人的子樹。

寫出來（提示：`unnest`）。和 B1 比較 `EXPLAIN`。

### C3 — 物化

這份報表每天要跑一次，組織有 10 萬人。

- 你會即時算還是預先算？
- 如果預先算，存成什麼結構？（提示：closure table）
- 有人換主管時，要更新哪些資料？

<br>

---

<br>

## 面試官的追問

> 1. 「如果要找『兩個員工的最近共同主管』（lowest common ancestor），怎麼寫？」
>    （提示：用 A3 的 path 陣列會非常簡單）
>
> 2. 「`ltree` extension 是什麼？用它做這題會有什麼好處？」
>
> 3. 「組織圖的四種存法：adjacency list（本題）、path enumeration、nested set、closure table。各自的讀寫成本？」
>
> 4. 「如果一個人有兩個主管（矩陣式組織），這整套還能用嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 路徑與深度骨架</summary>

```sql
WITH RECURSIVE tree AS (
    SELECT id, name, manager_id, salary,
           1 AS depth,
           name::text AS path                    -- ← ::text 很重要，見下方
    FROM org
    WHERE manager_id IS NULL                     -- ← 根節點
    UNION ALL
    SELECT o.id, o.name, o.manager_id, o.salary,
           t.depth + 1,
           t.path || ' > ' || o.name
    FROM tree t
    JOIN org o ON o.manager_id = t.id
)
SELECT depth, repeat('  ', depth - 1) || name AS chart, salary, path
FROM tree
ORDER BY path;                                   -- ← 依路徑字串排序 = 深度優先順序
```

**`name::text` 為什麼必要**：`name` 是 `VARCHAR(30)`，而遞迴項串接出來的結果沒有長度限制。
型別不一致會報：

```
ERROR:  recursive query "tree" column 6 has type character varying(30) in non-recursive term
        but type character varying overall
```

注意錯誤訊息說的是 `character varying(30)` vs `character varying` —— **長度限制本身就構成型別差異**，不是 varchar 和 text 的差別。這個細節很容易看漏，因為兩邊「看起來」都是 varchar。

這是 [Phase 3-07](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) 提過的型別陷阱。**遞迴 CTE 的兩項型別必須完全一致，包括長度限制。**

</details>

<details>
<summary>Hint 2 — 為什麼 ORDER BY path 給出組織圖順序</summary>

字串排序是字典序。因為子節點的 path 一定以父節點的 path 為**前綴**，所以：

```
ceo
ceo > vp_eng
ceo > vp_eng > dir_a
ceo > vp_eng > dir_a > eng_2
ceo > vp_eng > dir_a > mgr_x
ceo > vp_eng > dir_a > mgr_x > eng_1
...
ceo > vp_sales
```

父節點永遠排在自己整棵子樹的前面，子樹永遠連續 —— **這就是深度優先（DFS）順序**。

`ORDER BY depth` 會變成廣度優先（同一層的人排在一起），組織圖就散掉了。

**A2 的陷阱**：如果名字含分隔符（例如某人叫 `a > b`），路徑就會歧義，排序可能錯亂。
防法：用一個名字裡不可能出現的分隔符，或改用陣列（A3）—— **陣列排序不受這個問題影響**。

</details>

<details>
<summary>Hint 3 — 子樹聚合：每個節點都當一次根</summary>

```sql
WITH RECURSIVE sub AS (
    SELECT id AS root_id, id, salary
    FROM org                                     -- ← 沒有 WHERE，每一個人都是起點
    UNION ALL
    SELECT s.root_id, o.id, o.salary             -- ← root_id 一路傳下去
    FROM sub s
    JOIN org o ON o.manager_id = s.id
)
SELECT o.name AS manager,
       COUNT(*) - 1              AS reports_below,      -- 扣掉自己
       SUM(s.salary) - o.salary  AS subtree_payroll     -- 扣掉自己
FROM sub s
JOIN org o ON o.id = s.root_id
GROUP BY o.id, o.name, o.salary
ORDER BY reports_below DESC, o.name;
```

**關鍵是 `root_id`**：它在非遞迴項被設成「起點自己」，然後在遞迴項**原封不動往下傳**。
所以最後每一行都知道「我屬於誰的子樹」。

非遞迴項沒有 `WHERE` —— 10 個人就是 10 個起點，各自展開自己的子樹。

`- 1` 和 `- o.salary` 是因為每個起點都包含了自己（非遞迴項那一行）。

</details>

<details>
<summary>Hint 4 — C2：用 path 陣列取代第二次遞迴</summary>

```sql
WITH RECURSIVE tree AS (
    SELECT id, name, salary, ARRAY[id] AS path
    FROM org WHERE manager_id IS NULL
    UNION ALL
    SELECT o.id, o.name, o.salary, t.path || o.id
    FROM tree t JOIN org o ON o.manager_id = t.id
)
SELECT anc.name AS manager,
       COUNT(*) AS reports_below,
       SUM(t.salary) AS subtree_payroll
FROM tree t
CROSS JOIN LATERAL unnest(t.path[1 : array_length(t.path,1) - 1]) AS a(ancestor_id)
JOIN org anc ON anc.id = a.ancestor_id
GROUP BY anc.id, anc.name;
```

`t.path` 去掉最後一個元素（自己）就是**所有祖先**。`unnest` 把它展開成多行 —— 每一行代表「我算在這個祖先的子樹裡」。

**一次遞迴 + 一次 unnest，取代了 N 次遞迴。**

注意這個版本不會列出 `reports_below = 0` 的人（葉節點不是任何人的祖先），要補的話 `RIGHT JOIN org` 或用 [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的骨架心法。

</details>
