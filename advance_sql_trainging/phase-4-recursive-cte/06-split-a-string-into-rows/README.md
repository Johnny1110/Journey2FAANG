# Phase 4-06 — Split a String Into Rows

> **難度**：★★★☆☆
> **核心技巧**：遞迴字串切割、`string_to_table` / `unnest` / `WITH ORDINALITY`、set-returning function 的隱形 INNER JOIN
> **對應基礎題**：[LC 1795. Rearrange Products Table](../../../sql_training/rearrange_products_table)（你當初的反 Pivot）

<br>

---

<br>

## Interview Context

> *面試官：*「我們接手了一個十年前的系統。文章的標籤是**逗號分隔存在一個 TEXT 欄位裡**的。
>
> 產品要做標籤雲和標籤篩選，所以我要把它正規化。
>
> 兩件事：
> 1. 用**遞迴 CTE** 寫一版 —— 我想看你會不會
> 2. 用 PostgreSQL 內建函數寫一版 —— 然後告訴我，**內建版本有沒有把資料弄丟**」

<br>

第二點才是重點。內建函數又快又短，但它有兩個安靜的陷阱。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS articles;

CREATE TABLE articles (
    id    INT PRIMARY KEY,
    title VARCHAR(60) NOT NULL,
    tags  TEXT                       -- ← 逗號分隔，可為 NULL
);

INSERT INTO articles (id, title, tags) VALUES
(1, 'Indexing Deep Dive', 'sql,postgres,performance'),
(2, 'Window Functions',   'sql'),
(3, 'Draft Post',         ''),           -- ← 空字串
(4, 'Untagged Post',      NULL),         -- ← NULL
(5, 'Trailing Comma',     'sql,nosql,'), -- ← 結尾多一個逗號
(6, 'Double Comma',       'a,,b');       -- ← 中間連續兩個逗號
```

<br>

**6 篇文章。記住這個數字。**

<br>

---

<br>

## Part A — 內建函數

### A1

```sql
SELECT a.id, a.title, t.tag
FROM articles a, LATERAL string_to_table(a.tags, ',') AS t(tag)
ORDER BY a.id, t.tag;
```

跑出來 **10 行**，但只涵蓋 **4 篇文章**。

**id 3 和 id 4 完全消失了。**

### A2 — 診斷消失

跑這個確認邊界行為：

```sql
SELECT 'empty'    AS input, count(*) FROM string_to_table('', ',')
UNION ALL SELECT 'null',     count(*) FROM string_to_table(NULL, ',')
UNION ALL SELECT 'single',   count(*) FROM string_to_table('sql', ',')
UNION ALL SELECT 'trailing', count(*) FROM string_to_table('a,b,', ',');
```

```
  input   | count
----------+-------
 empty    |     0
 null     |     0
 single   |     1
 trailing |     3
```

回答：
- `string_to_table('', ',')` 回傳幾行？（**不是 1 行空字串**）
- 一個 set-returning function 回傳 0 行時，`FROM a, LATERAL f(...)` 這一篇文章會怎樣？
- **這是哪一種 JOIN 的行為？**
- 這和 [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的 `LEFT JOIN` 降級是同一類問題嗎？

### A3 — 修好資料遺失

改寫查詢，讓 6 篇文章**全部**出現（沒有標籤的顯示 NULL 或空）。

提示：`LEFT JOIN LATERAL ... ON true`

驗證輸出的 `DISTINCT id` 是 6 不是 4。

### A4 — 髒標籤

id 5（`'sql,nosql,'`）和 id 6（`'a,,b'`）各產生了一個**空字串標籤**。

- 這是 bug 還是資料本身的問題？
- 你會在查詢裡過濾掉它，還是回報給資料擁有者？
- 寫出過濾版本，並想想 `WHERE tag <> ''` 和 `WHERE NULLIF(tag,'') IS NOT NULL` 有沒有差別。

### A5 — 順序

`string_to_table` 的輸出**沒有位置資訊**。如果標籤的順序有意義（第一個是主標籤），怎麼辦？

用 `WITH ORDINALITY` 寫出來：

```
 id |     tag     | pos
----+-------------+-----
  1 | sql         |   1
  1 | postgres    |   2
  1 | performance |   3
  6 | a           |   1
  6 |             |   2
  6 | b           |   3
```

<br>

---

<br>

## Part B — 遞迴版本

### B1

用遞迴 CTE 寫出字串切割。

思路：每一輪從剩餘字串切下第一個 token，剩下的傳給下一輪。

技巧提示：
- `position(',' in rest)` 找第一個逗號位置
- `substring(rest from 1 for pos-1)` 取出 token
- `substring(rest from pos+1)` 取出剩餘
- **在字串尾端補一個分隔符**可以讓最後一個 token 也被正常處理

### B2 — 對照

你的遞迴版和 `string_to_table` 版：

| | 遞迴 | `string_to_table` |
|---|---|---|
| 行數 | ? | ? |
| id 3、4 有沒有出現 | ? | ? |
| 有沒有位置資訊 | ? | ? |
| 空標籤怎麼處理 | ? | ? |
| 效能 | ? | ? |

### B3 — 面試怎麼答

面試官問「把逗號分隔字串拆成多行」，你該：

- 直接寫 `string_to_table`？
- 直接寫遞迴 CTE？
- 還是先問什麼？

**寫出你的完整回答腳本**（30 秒內講完）。

<br>

---

<br>

## Part C — 正規化

### C1

寫出完整的正規化 DDL + DML：把 `articles.tags` 拆成兩張表。

```sql
CREATE TABLE tags (id SERIAL PRIMARY KEY, name VARCHAR(50) UNIQUE NOT NULL);
CREATE TABLE article_tags (article_id INT, tag_id INT, PRIMARY KEY (article_id, tag_id));
```

用 `INSERT ... SELECT` 灌進去（[基礎 Phase 5](../../../sql_training) 的 DML 技巧）。

要求：
- 標籤去重（`sql` 只能有一筆）
- 空標籤不要進去
- id 3、4 沒有標籤，不該有 `article_tags` 記錄，但**文章本身不能消失**

### C2 — 驗證遷移

寫出**遷移驗證查詢**：確認正規化後的資料和原始資料一致。

至少檢查：
- 每篇文章的標籤數量是否吻合
- 有沒有標籤在遷移中遺失
- 有沒有多出來的標籤

> **任何資料遷移都必須有驗證查詢。** 面試時主動提這件事就是加分。

### C3 — 為什麼一開始不該這樣存

回答：
- 逗號分隔存法有什麼問題？（至少列 4 個）
- 有沒有情況它是合理的？
- PostgreSQL 的 `TEXT[]` 陣列型別算不算「正規化」？它解決了哪些問題、沒解決哪些？
- 如果用 `JSONB` 存呢？

<br>

---

<br>

## 面試官的追問

> 1. 「`regexp_split_to_table` 和 `string_to_table` 差在哪？什麼時候需要前者？」
>
> 2. 「如果分隔符是**多個字元**（`' | '`）或者標籤裡本身含分隔符，怎麼辦？」
>
> 3. 「1000 萬篇文章要做這個遷移，你會一次跑完嗎？」
>
> 4. 「`unnest(string_to_array(x, ','))` 和 `string_to_table(x, ',')` 有差別嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼 id 3、4 會消失</summary>

`FROM articles a, LATERAL f(...)` 這個逗號語法是 **`CROSS JOIN LATERAL`** 的簡寫。

`CROSS JOIN` 的語意：左邊每一行 × 右邊每一行。當右邊是 **0 行**時，乘積就是 **0 行** —— 這一篇文章整個消失。

- id 3（`tags = ''`）→ `string_to_table` 回傳 0 行 → 消失
- id 4（`tags = NULL`）→ 回傳 0 行 → 消失

**修法**：

```sql
FROM articles a
LEFT JOIN LATERAL string_to_table(a.tags, ',') AS t(tag) ON true
```

`LEFT JOIN LATERAL ... ON true` 保證左邊每一行至少出現一次，右邊沒東西就補 NULL。

**這和 [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 是同一個病根**：某個 JOIN 悄悄變成了 INNER，行數變少但沒有錯誤訊息。
[Phase 1-05](../../phase-1-join-dark-side/05-top-n-four-ways) 面試官追問 2 問的也正是這個 `CROSS JOIN LATERAL` vs `LEFT JOIN LATERAL ON true`。

</details>

<details>
<summary>Hint 2 — 遞迴切割骨架</summary>

```sql
WITH RECURSIVE split AS (
    SELECT id, title,
           tags || ',' AS rest,        -- ← 尾端補分隔符，讓最後一個 token 也有逗號可切
           ''::text    AS tag,
           0           AS n
    FROM articles
    WHERE tags IS NOT NULL AND tags <> ''
    UNION ALL
    SELECT id, title,
           substring(rest from position(',' in rest) + 1),      -- 剩餘
           substring(rest from 1 for position(',' in rest) - 1), -- 這一個 token
           n + 1
    FROM split
    WHERE position(',' in rest) > 0                             -- ← 終止條件
)
SELECT id, title, tag, n FROM split WHERE n > 0 ORDER BY id, n;
```

三個重點：
- **`tags || ','`**：不補的話最後一個 token（沒有尾隨逗號）會被漏掉
- **`WHERE position(',' in rest) > 0`**：切完就停，這是終止條件
- **`WHERE n > 0`**：濾掉非遞迴項那一行（它的 `tag` 是空的佔位符）

`n` 天然就是位置編號 —— **遞迴版免費附贈 `WITH ORDINALITY` 的功能**。

</details>

<details>
<summary>Hint 3 — B3 的回答腳本</summary>

> 「PostgreSQL 有內建的 `string_to_table`，一行就能解決，實務上我會用它。
>
> 但有兩個陷阱要注意：第一，空字串和 NULL 會讓函數回傳 0 行，配 `CROSS JOIN LATERAL` 的話整篇文章會消失 —— 要用 `LEFT JOIN LATERAL ON true`。第二，它不保證輸出順序也沒有位置資訊，如果標籤順序有意義要加 `WITH ORDINALITY`。
>
> 如果是要展示遞迴 CTE，我也可以寫 —— 邏輯是每輪切下第一個 token、剩餘傳下一輪，位置編號免費得到。但正式環境我不會這樣寫，內建函數快很多。」

**這個回答同時展示了：知道內建、知道陷阱、知道遞迴、知道取捨。** 四件事，30 秒。

</details>

<details>
<summary>Hint 4 — C3 逗號分隔的問題</summary>

1. **無法建索引** —— 「找出所有標 `sql` 的文章」只能 `LIKE '%sql%'`，全表掃描，而且會誤中 `nosql`
2. **無法保證引用完整性** —— 標籤打錯字沒人擋得住（`postgres` / `postgre` / `Postgres`）
3. **無法統計** —— 「最熱門的 10 個標籤」要先拆才能 `GROUP BY`
4. **更新困難** —— 把 `sql` 改名成 `SQL` 要對每一行做字串取代，而且有子字串誤傷風險
5. **無法附加屬性** —— 標籤沒辦法有自己的描述、顏色、建立時間

**`TEXT[]` 陣列**解決了 1（GIN 索引支援 `@>`）和 3（`unnest` 更直接），但沒解決 2、4、5。

**`JSONB`** 類似，多了彈性但一樣沒有引用完整性。

**關聯表**（C1）全部解決，代價是多一次 JOIN。**這是標準答案** —— 但要能講出「什麼時候陣列就夠了」：標籤數量少、不需要獨立屬性、不需要重新命名時，`TEXT[]` + GIN 索引是很務實的選擇。

</details>
