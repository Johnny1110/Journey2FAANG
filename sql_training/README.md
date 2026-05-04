# SQL 高頻面試題系統刷題大綱

> **目標**：從 JOIN / GROUP BY 基礎開始，漸進式建立手寫 SQL 的面試技巧
> **使用方式**：每個 Phase 按順序推進，全部完成後進入隨機刷題階段  
> **建議節奏**：每日 1 題，搭配 LeetCode SQL 題庫練習  

<br>

在開始練習前，請先佈置環境．使用 Docker 啟動 postgreSQL 容器。在每一個章節使用 testing schema 初始化測試資料。

```bash
docker run --name postgres-leetcode -e POSTGRES_USER=root -e POSTGRES_PASSWORD=root -e POSTGRES_DB=lico -p 5432:5432 -d postgres:latest
```


Docker Postgres 資料庫連線參數:

```
user     :  "root"
password :  "root"
dbname   :  "lico"
domain   :  "localhost:5432"
```

* 請使用任何的 db GUI 輔助工具連接進行測試．

* **每一題的 link 點進去，都會有題目敘述與供測試使用的 table schema + testing data，請自行在 lico database 新增 tables 與測試資料，完成後即可開始練習**

Happy Coding~

<br>
<br>

---

<br>
<br>

## Phase 1：JOIN 與 GROUP BY 基本功

**為什麼從這裡開始**：面試 SQL 題 80% 以上需要 JOIN + GROUP BY + 聚合函數的組合。這一階段的目標是讓你能不用思考地把多表關聯和分組統計寫出來。

### 核心概念

| 概念 | 你需要能手寫的程度 |
|------|-------------------|
| INNER / LEFT / RIGHT JOIN | 理解 NULL 行為差異，能判斷何時用哪種 |
| GROUP BY + HAVING | 能區分 WHERE vs HAVING 的過濾時機 |
| COUNT / SUM / AVG / MAX / MIN | 搭配 DISTINCT 使用 |
| 多表 JOIN + GROUP BY | 3 張表以上的組合查詢 |

### 練習題（建議順序）

- **LC 175. Combine Two Tables** — 最基礎的 LEFT JOIN -> [link](combine_2_tables)
- **LC 181. Employees Earning More Than Their Managers** — Self JOIN -> [link](employees_earning_more_than_their_managers)
- **LC 182. Duplicate Emails** — GROUP BY + HAVING COUNT -> [link](duplicate_emails)
- **LC 183. Customers Who Never Order** — LEFT JOIN + IS NULL（反向匹配） -> [link](customers_who_never_order)
- **LC 197. Rising Temperature** — Self JOIN + 日期運算 -> [link](rising_temperature)
- **LC 511. Game Play Analysis I** — GROUP BY + MIN 聚合 -> [link](game_play_analysis_i)
- **LC 577. Employee Bonus** — LEFT JOIN 處理 NULL ->[link](employee_bonus)
- **LC 586. Customer Placing the Largest Number of Orders** — GROUP BY + ORDER BY + LIMIT -> [link](customer_placing_the_largest_number_of_orders)
- **LC 1068. Product Sales Analysis I** — 基礎 JOIN -> [link](product_sales_analysis_i)
- **LC 1581. Customer Who Visited but Did Not Make Any Transaction** — LEFT JOIN + IS NULL + COUNT -> [link](customer_who_visited_but_did_not_make_any_transaction)

### Phase 1 自我檢測

能不能在 10 分鐘內徒手寫出：「找出從未下過訂單的客戶名稱」？  
如果能，進入 Phase 2。

```
Assume:
table: customer, order

Answer:
select c.username 
from customer as c 
where not exists (
    select 1 
    from order as o 
    where o.customer_id = c.id
);
```


<br>
<br>

---

<br>
<br>

## Phase 2：子查詢與多層邏輯（中階思維）

**為什麼需要這個**：很多面試題不是一次 SELECT 能解決的。你需要學會把問題拆成「先算出中間結果，再基於它做篩選」的思路。子查詢（subquery）就是這個「中間結果」的載體。

### 核心概念

| 概念 | 重點 |
|------|------|
| WHERE 中的子查詢 | `WHERE col IN (SELECT ...)` |
| FROM 中的子查詢（派生表） | `FROM (SELECT ...) AS sub` |
| 相關子查詢 | 外層每一行都觸發內層查詢，理解效能代價 |
| EXISTS vs IN | 語義差異與效能差異 |

### 練習題

- **LC 176. Second Highest Salary** — 子查詢 + LIMIT OFFSET / IFNULL 處理邊界 -> [link](second_highest_salary)
- **LC 184. Department Highest Salary** — 子查詢找每組最大值 -> [link](department_highest_salary)
- **LC 196. Delete Duplicate Emails** — 用子查詢輔助 DELETE（DML 暖身）-> [link](delete_duplicate_emails)
- **LC 512. Game Play Analysis II** — 子查詢配合 GROUP BY -> [link](game_play_analysis_ii)
- **LC 550. Game Play Analysis IV** — 多層子查詢 + 日期偏移 -> [link](game_play_analysis_iv)
- **LC 602. Friend Requests II** — UNION + 子查詢統計 -> [link](friend_reequests_ii)
- **LC 1084. Sales Analysis III** — 條件過濾 + NOT IN / NOT EXISTS -> [link](sales_analysis_iii)
- **LC 1141. User Activity for the Past 30 Days I** — 日期範圍 + COUNT DISTINCT -> [link](user_activity_for_the_past_30_days_i)
- **LC 1164. Product Price at a Given Date** — 子查詢找最近一筆記錄 -> [link](product_price_at_a_given_date)

### Phase 2 自我檢測

能不能寫出：「找出每個部門薪水最高的員工姓名」？  
關鍵是你能判斷這題要用子查詢而不是單純 GROUP BY。

<br>

assume table: employees

```
department_id, employee_id, salary
```
<br>

answer:

```sql
with as tmp (
    select department_id, max(salary) as salary 
    from employees 
    group by department_id
    )
select department_id, employee_id, salary 
from employees as e
inner join tmp as t on t.department_id = e.department_id and t.salary = e.salary
```

<br>
<br>

---

<br>
<br>

## Phase 3：Window Functions（面試高頻拉分項）

**為什麼這是拉分項**：Window Function 讓你能在「不折疊行」的情況下做排名、累計、前後行比較。很多中高難度面試題用 Window Function 可以優雅解決，不用的話要寫巢狀子查詢，又慢又容易出錯。

### 核心概念

| 函數 | 用途 | 常見考法 |
|------|------|---------|
| `ROW_NUMBER()` | 每組內唯一排名 | Top-N per group |
| `RANK()` / `DENSE_RANK()` | 處理並列名次 | 薪水排名、成績排名 |
| `LAG()` / `LEAD()` | 取前一行 / 後一行 | 連續天數、日期比較 |
| `SUM() OVER()` | 累計加總 | Running total |
| `PARTITION BY` | 分組窗口 | 每組分別計算 |
| `ROWS/RANGE BETWEEN` | 窗口範圍控制 | 移動平均 |

### 練習題

- **LC 178. Rank Scores** — DENSE_RANK 基礎用法 -> [link](rank_scores)
- **LC 180. Consecutive Numbers** — LAG / LEAD 檢查連續值 ->[link](consecutive_numbers)
- **LC 185. Department Top Three Salaries** — DENSE_RANK + PARTITION BY（經典 Top-N per group）->[link](department_top_three_salaries)
- **LC 534. Game Play Analysis III** — SUM OVER 累計計算 -> [link](game_play_analysis_iii)
- **LC 1070. Product Sales Analysis III** — RANK + 篩選第一年 -> [link](product_sales_analysis_iii)
- **LC 1158. Market Analysis I** — Window Function 配合 JOIN -> [link](market_analysis_i)
- **LC 1204. Last Person to Fit in the Bus** — Running SUM + 條件截斷 -> [link](last_person_to_fit_in_the_bus)
- **LC 1321. Restaurant Growth** — ROWS BETWEEN 移動平均 -> [link](restaurant_growth)
- **LC 1341. Movie Rating** — RANK + UNION ALL 多維度排名 -> [link](movie_rating)
- **LC 1907. Count Salary Categories** — 條件分組 + Window（CASE WHEN 搭配）-> [link](count_salary_categories)

### Phase 3 自我檢測

能不能寫出：「找出每個部門薪水前 3 名的員工，允許並列」？

Assule Table:
```sql
create table salary (
    department_id int,
    employee_name int,
    salary int
)
```

Solutation:
```sql
select department_id, employee_name
from (select department_id,
             employee_name,
             salary,
             dense_rank() over (partition by department_id order by salary desc) as ranked
      from salary) as t
where t.ranked <= 3
order by department_id, ranked;
```

<br>
<br>

---

<br>
<br>

## Phase 4：CTE 與複雜查詢組裝（進階結構化）

**為什麼需要 CTE**：CTE (`WITH ... AS`) 讓你把複雜查詢拆成命名步驟，可讀性和可維護性大幅提升。面試時用 CTE 組織答案，考官一眼就看得出你的思路。遞迴 CTE 則是處理樹狀 / 層級資料的利器。

### 核心概念

| 概念 | 重點 |
|------|------|
| 非遞迴 CTE | 用 `WITH` 拆解多步驟查詢 |
| 多個 CTE 串接 | `WITH a AS (...), b AS (...)` |
| 遞迴 CTE | `WITH RECURSIVE` 處理層級關係 |
| CTE vs 子查詢 | CTE 可複用，子查詢不行 |

### 練習題

- **LC 1225. Report Contiguous Dates** — CTE 處理連續日期分組（Islands and Gaps）-> [link](report_contiguous_dates)
- **LC 1270. All People Report to the Given Manager** — 遞迴 CTE 找管理鏈 -> [link](all_people_report_to_the_given_manager/README.md)
- **LC 1384. Total Sales Amount by Year** — 遞迴 CTE 生成日期序列
- **LC 1613. Find the Missing IDs** — 遞迴 CTE 生成連續數列
- **LC 1767. Find the Subtasks That Did Not Execute** — 遞迴 CTE + LEFT JOIN
- **LC 185（改用 CTE 重寫）** — 對比子查詢版本的清晰度差異

### Phase 4 自我檢測

能不能用 CTE 寫出：「列出所有直接或間接向 CEO 匯報的員工」？  
這需要遞迴 CTE 遍歷管理鏈。

<br>
<br>

---

<br>
<br>

## Phase 5：DML — INSERT / UPDATE / DELETE 技巧

**為什麼面試會考 DML**：不是所有面試題都是 SELECT。有些題目考的是「如何安全地修改資料」，這在實際工作中也非常重要。

### 核心概念

| 概念 | 重點 |
|------|------|
| DELETE + 子查詢 | 刪除重複資料（保留最小 ID） |
| UPDATE + JOIN | 跨表更新 |
| INSERT + SELECT | 批量插入 |
| UPSERT 模式 | `ON CONFLICT DO UPDATE`（PostgreSQL）/`ON DUPLICATE KEY UPDATE`（MySQL） |
| 安全修改 | 先 SELECT 確認影響範圍再執行 |

### 練習題

- **LC 196. Delete Duplicate Emails** — DELETE + 自連接保留最小 ID
- **LC 627. Swap Salary** — UPDATE + CASE WHEN 值交換
- **LC 1873. Calculate Special Bonus** — 條件 UPDATE
- **練習題（自設）**：寫一個 UPSERT — 如果 user_id 存在就更新 last_login，不存在就插入新行
- **練習題（自設）**：用 `INSERT INTO ... SELECT` 把統計結果寫入報表表

### Phase 5 自我檢測

能不能寫出：「刪除 Person 表中重複的 email，只保留 ID 最小的那條」？  
注意 MySQL 不允許在 DELETE 的子查詢中引用被刪除的表本身。

<br>
<br>

---

<br>
<br>

## Phase 6：Pivot / 行列轉換 與報表格式化

**為什麼特別獨立這一章**：你幣安面試的 SQL 第二題，最後要把結果轉成橫向欄位格式，就是 Pivot。這類題型看似簡單但如果沒練過，現場很難即興寫出來。

### 核心概念

| 概念 | 重點 |
|------|------|
| 條件聚合 Pivot | `MAX(CASE WHEN ... THEN ... END)` |
| GROUP_CONCAT / STRING_AGG | 把多行合併成一個字串 |
| UNION ALL 反 Pivot | 把橫向欄位拆回多行 |
| 動態欄位 | 面試通常不考，但要知道概念 |

### 練習題

- **LC 618. Students Report By Geography** — 經典行轉列 Pivot
- **LC 1179. Reformat Department Table** — CASE WHEN Pivot（月份轉欄位）
- **LC 1777. Product's Price for Each Store** — 條件聚合
- **LC 1795. Rearrange Products Table** — UNION ALL 反 Pivot
- **練習題（自設，模擬幣安原題）**：給定部門表、員工表、專案表、員工專案關聯表，寫出 Top-3 專案最多的部門並以橫向格式輸出

### Phase 6 自我檢測

能不能把這種輸出：

| dept | project_count |
|------|--------------|
| ADMIN | 15 |
| PAYMENT | 12 |
| CORE | 10 |

轉成這種格式：

| 1st | 2nd | 3rd |
|-----|-----|-----|
| ADMIN | PAYMENT | CORE |

<br>
<br>

---

<br>
<br>

## Phase 7：效能優化與 EXPLAIN（系統設計加分項）

**為什麼要學這個**：Senior 面試常會追問「這個查詢怎麼優化」。不需要背 B+ Tree 的每個細節，但要能看懂 EXPLAIN 輸出、判斷該加什麼 Index。

### 核心概念

| 概念 | 重點 |
|------|------|
| EXPLAIN / EXPLAIN ANALYZE | 看懂 Seq Scan vs Index Scan vs Bitmap Scan |
| Index 設計 | 單列 vs 複合索引、覆蓋索引 |
| WHERE 順序 vs Index 順序 | 最左前綴原則 |
| JOIN 順序與 Hash Join vs Nested Loop | 小表驅動大表 |
| 避免全表掃描的常見陷阱 | 函數包裹欄位、隱式型別轉換、LIKE '%...' |
| 分頁優化 | OFFSET 大了怎麼辦 → Cursor-based pagination |
| COUNT 優化 | COUNT(*) vs COUNT(col) vs 近似值 |

### 學習方式（非刷題，而是實驗）

- 在本地 PostgreSQL 建一張 100 萬行的假資料表
- 對同一查詢分別跑 `EXPLAIN ANALYZE`：無 Index → 加單列 Index → 加複合 Index
- 觀察 Seq Scan → Index Scan 的切換點
- 試一次 `WHERE LOWER(name) = 'xxx'` vs `WHERE name = 'Xxx'`，觀察 Index 失效
- 試一次 `OFFSET 100000 LIMIT 10` vs cursor-based 分頁的效能差異
- 讀懂一次 Hash Join vs Nested Loop 的 EXPLAIN 輸出

### Phase 7 自我檢測

面試官問你：「這個查詢跑很慢，你怎麼排查？」  
你能不能有條理地回答：EXPLAIN → 看 Scan Type → 判斷 Index → 檢查篩選條件 → 考慮改寫查詢。

<br>
<br>

---

<br>
<br>


## 刷題總路線圖


完成以上 7 個 Phase 後 → **進入隨機刷題階段**，建議從 LeetCode SQL 50 題精選開始。

<br>
<br>

---

<br>
<br>

## 附錄：面試現場手寫 SQL 的注意事項

1. **先釐清 schema**：拿到題目先確認有哪些表、欄位、關聯關係。畫出來。
2. **先寫 FROM + JOIN**：確定表的連接方式是解題的骨架。
3. **再加 WHERE / GROUP BY / HAVING**：篩選和分組是血肉。
4. **最後處理格式**：ORDER BY、LIMIT、Pivot 放最後。
5. **邊界情況要提**：NULL 處理、空結果、重複資料。即使沒寫進 SQL，講出來就是加分。
6. **不確定語法就用虛擬碼**：面試官看的是思路，語法小錯通常不扣分。