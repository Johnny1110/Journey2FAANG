# SQL 進階訓練 — Advanced SQL Training

> **前置條件**：已完成 [sql_training](../sql_training) 全部 7 個 Phase
> **目標**：從「寫得出來」進化到「寫得對、寫得快、講得清楚」
> **定位**：這裡沒有一題是抄得到答案的。每一題都是基礎題的**變化題** — 場景重寫、加上真實世界的髒資料與邊界，並附上面試官的追問。
> **建議節奏**：每日 1 題。一題可能要花 40~60 分鐘，這是正常的。

<br>

---

<br>

## 這套訓練和 sql_training 有什麼不同？

| | sql_training | advance_sql_training |
|---|---|---|
| 題目來源 | LeetCode 原題 | **自設情境題**（Google 不到答案） |
| 資料乾淨度 | 乾淨、無 NULL、無重複 | **髒資料**：NULL、重複、邊界值、缺漏 |
| 正確標準 | 跑出正確結果 | 結果正確 **+ 邊界正確 + 能講出為什麼** |
| 交付內容 | `answer.sql` | `answer.sql`（含註解回答面試官追問） |
| 考點 | 語法會不會 | **語意懂不懂**（三值邏輯、frame、隔離級別） |

每一題都會標註「**對應基礎題**」，回去對照你當初怎麼寫的，感受一下差距在哪。

<br>

---

<br>

## 環境佈置

沿用 sql_training 的容器，但**開一個新的 database**，避免 table 名稱撞車：

```bash
# 容器還在的話直接用
docker start postgres-leetcode

# 容器不在就重建
docker run --name postgres-leetcode \
  -e POSTGRES_USER=root -e POSTGRES_PASSWORD=root -e POSTGRES_DB=lico \
  -p 5432:5432 -d postgres:latest
```

```bash
# 建立進階訓練專用 database
docker exec -it postgres-leetcode psql -U root -d lico -c "CREATE DATABASE lico_adv;"
```

連線參數：

```
user     :  "root"
password :  "root"
dbname   :  "lico_adv"     <- 注意，不是 lico
domain   :  "localhost:5432"
```

部分題目需要額外的 extension（題目內會標註）：

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- Phase 6 區間約束會用到
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- Phase 7 選用
```

> **PostgreSQL 版本要求**：建議 15 以上。Phase 6 的 `MERGE` 需要 PG 15+，Phase 4 的 `CYCLE` 子句需要 PG 14+，Phase 3 的 `GROUPS` frame 需要 PG 11+。

<br>

---

<br>

## 作答方式

和 sql_training 一樣：

```
{phase}/{problem}/README.md      <- 題目、schema、測試資料、面試官追問
{phase}/{problem}/answer.sql     <- 你的答案（含註解回答追問）
{phase}/{problem}/feedback.md    <- 我的評分與建議
```

**評分請說**：`sql-adv: phase-1 01` 或 `sql-adv: the null that ate your results`

**要我建下一題請說**：`init sql-adv: phase-1 02`

<br>

### `answer.sql` 建議格式

進階題不只要 SQL，還要**能講**。請用註解回答面試官的追問：

```sql
-- ============================================
-- Q1: 為什麼第一個查詢回傳 0 筆？
-- ============================================
-- 你的文字回答寫這裡...

-- ============================================
-- Q2: 正確的寫法
-- ============================================
SELECT ...
```

面試現場你講不出來就是 0 分，寫得再漂亮都沒用。

<br>

---

<br>

## 進度

** 一共 54 題，每一題都有 `README.md` + `setup.sql` + `answer.sql`，
測試資料與預期輸出全部在 PostgreSQL 18 上實跑驗證過 —— README 裡的每一個數字都是真的跑出來的，不是推算的。

想追蹤自己的進度，把做完的題目在下面各 Phase 的表格裡自己打勾就好。

<br>

---

<br>

## Phase 1：JOIN 的暗面 — 當 `=` 不夠用時

> **變化自**：sql_training Phase 1（JOIN 與 GROUP BY 基本功）

**為什麼是這裡開始**：你已經會寫 `INNER / LEFT JOIN` 了。但面試真正篩掉人的不是「會不會寫 JOIN」，而是「知不知道 JOIN 在髒資料下會發生什麼事」。這一階段全部是**基礎 JOIN 題被加上一個 NULL、一個重複、或一個等號拿掉**之後的樣子。

### 核心概念

| 概念 | 你需要能講清楚的程度 |
|------|---------------------|
| 三值邏輯（TRUE / FALSE / **UNKNOWN**） | 為什麼 `NOT IN` 遇到 NULL 會整個爆掉 |
| Anti-Join 三寫法 | `NOT IN` / `NOT EXISTS` / `LEFT JOIN ... IS NULL` 的語意與計畫差異 |
| Non-Equi Join（Band Join） | 用 `BETWEEN` / `<` 關聯兩表，以及它的成本 |
| 區間重疊判定 | 從「不重疊的兩種情況」反推重疊條件 |
| `IS DISTINCT FROM` | NULL-safe 比較，對帳題的救命符 |
| FULL OUTER JOIN | 雙向差異比對 + `COALESCE` 補鍵 |
| LATERAL JOIN | 每組取 N 筆的第四種寫法，什麼時候它比 window 快 |
| 對稱配對去重 | `a.id < b.id` 為什麼是必須的（含自我配對） |
| LEFT JOIN + WHERE 陷阱 | 條件放 `ON` 還是 `WHERE`，結果完全不同 |

### 學習筆記 (Phase - 1 考點)

* [Nested Loop / Hash / Merge Join 三種 Join 演算法](notes/three_join.md)

### 練習題

| # | 題目 | 核心技巧 | 難度 | 狀態 |
|---|------|---------|------|------|
| 01 | [The NULL That Ate Your Results](phase-1-join-dark-side/01-the-null-that-ate-your-results) | Anti-Join 三寫法 × 三值邏輯 | ★★★☆☆ | 🟢 |
| 02 | [Price Tier Assignment](phase-1-join-dark-side/02-price-tier-assignment) | Non-Equi Join、無上限邊界、區間重疊偵測 | ★★★☆☆ | 🟢 |
| 03 | [The Double-Booked Meeting Room](phase-1-join-dark-side/03-the-double-booked-meeting-room) | 區間重疊自連接、半開區間 | ★★★★☆ | 🟠 |
| 04 | [Ledger Reconciliation](phase-1-join-dark-side/04-ledger-reconciliation) | FULL OUTER JOIN、`IS DISTINCT FROM` | ★★★★☆ | 🟢 |
| 05 | [Top-3 Orders per Customer, Four Ways](phase-1-join-dark-side/05-top-n-four-ways) | LATERAL vs Window vs Correlated vs `DISTINCT ON` | ★★★★☆ | ⏳ |
| 06 | [The Self-Join That Counted Twice](phase-1-join-dark-side/06-the-self-join-that-counted-twice) | 對稱配對去重、自我配對邊界 | ★★★☆☆ |  |
| 07 | [The Report With Missing Rows](phase-1-join-dark-side/07-the-report-with-missing-rows) | CROSS JOIN 維度骨架、`ON` vs `WHERE` 陷阱 | ★★★★☆ |  |

### Phase 1 自我檢測

面試官給你這張表和這個查詢：

```sql
CREATE TABLE orders (id INT, customer_id INT);  -- customer_id 可為 NULL

SELECT name FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);
```

問你：「這個查詢在生產環境跑了兩年都對，昨天突然回傳 0 筆，資料也沒少。發生什麼事？」

你要能在 **60 秒內**講完：三值邏輯 → `NOT IN` 展開成什麼 → 為什麼 UNKNOWN 不等於 TRUE → 三種修法 → 你會選哪一種以及為什麼。

<br>
<br>

---

<br>
<br>

## Phase 2：聚合的極限 — 一次查詢完成整張報表

> **變化自**：sql_training Phase 1（GROUP BY）+ Phase 6（Pivot）

**為什麼需要**：你會 `GROUP BY` + `CASE WHEN` 了。但當 PM 要「總計 + 各區小計 + 各產品小計，全部在一張表」時，你要嘛跑三次查詢 `UNION ALL`（慢、醜），要嘛一行 `GROUPING SETS` 解決。這一階段把聚合從「算數字」推到「產報表」。

### 核心概念

| 概念 | 重點 |
|------|------|
| `GROUPING SETS` / `ROLLUP` / `CUBE` | 一次掃描產生多層小計 |
| `GROUPING()` 函數 | 區分「小計行的 NULL」與「資料本身的 NULL」 |
| `FILTER (WHERE ...)` | 比 `CASE WHEN` 更清楚的條件聚合，且 planner 更好處理 |
| Ordered-Set Aggregate | `PERCENTILE_CONT` / `PERCENTILE_DISC` / `MODE()` |
| `DISTINCT ON`（PG 專屬） | 每組取一筆的最短寫法 |
| 加權平均陷阱 | `AVG(AVG(x))` 為什麼是錯的 |
| 分桶 | `width_bucket` / `NTILE`，以及空桶怎麼補 |
| 聚合裡的 NULL | `COUNT(*)` vs `COUNT(col)` vs `SUM` 遇到全 NULL |

### 練習題

| # | 題目 | 核心技巧 | 難度 | 狀態 |
|---|------|---------|------|------|
| 01 | [One Query, Four Subtotals](phase-2-aggregation-limits/01-one-query-four-subtotals) | `GROUPING SETS` + `GROUPING()` 辨識小計行 | ★★★★☆ |  |
| 02 | [FILTER vs CASE WHEN](phase-2-aggregation-limits/02-filter-vs-case-when) | `FILTER` 子句、`COUNT` 的 NULL 語意、計畫對比 | ★★★☆☆ |  |
| 03 | [The Median Without a Median Function](phase-2-aggregation-limits/03-the-median-without-a-median-function) | `PERCENTILE_CONT` vs `DISC` + 手寫雙向排名版 | ★★★★☆ |  |
| 04 | [The Mode That Ties](phase-2-aggregation-limits/04-the-mode-that-ties) | 眾數並列全取、`RANK` vs `ROW_NUMBER`、非決定性查詢 | ★★★☆☆ |  |
| 05 | [The Weighted Average Trap](phase-2-aggregation-limits/05-the-weighted-average-trap) | `AVG(AVG())` 謬誤、聚合可組合性 | ★★★☆☆ |  |
| 06 | [Histogram With Empty Buckets](phase-2-aggregation-limits/06-histogram-with-empty-buckets) | `width_bucket` 邊界溢位、空桶補齊、vs `NTILE` | ★★★★☆ |  |
| 07 | [The COUNT That Lied](phase-2-aggregation-limits/07-the-count-that-lied) | JOIN 扇出放大、`COUNT(*)` vs `COUNT(col)` vs `DISTINCT` | ★★★★☆ |  |

### Phase 2 自我檢測

面試官寫下這個查詢，問你：「這裡有一個 bug，30 秒內告訴我。」

```sql
SELECT COUNT(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed
FROM orders;
```

你要能立刻說出：`COUNT()` 數的是「不為 NULL 的值」，`ELSE 0` 讓每一行都有值 → 它回傳的是總行數。修法有三種。

<br>

第二題，能不能用**一個查詢**產出含小計與總計的報表，並且**分辨得出**哪些 NULL 是小計行、哪些是資料本身的 NULL？

```
region  | product | revenue
--------+---------+---------
APAC    | A       | 100
APAC    | B       | 200
APAC    | (NULL)  | 300     <- APAC 小計
(NULL)  | A       | 300     <- 未知區域的明細
(NULL)  | (NULL)  | 400     <- 未知區域的小計
(NULL)  | (NULL)  | 900     <- 總計   ← 和上一行長得一模一樣
```

最後兩行的 `region` 和 `product` 都是 NULL。`WHERE region IS NULL` 分不出來，你要知道用什麼分。

<br>
<br>

---

<br>
<br>

## Phase 3：Window Function 深水區 — Frame 才是真正的考點

> **變化自**：sql_training Phase 3（Window Functions）

**為什麼這是分水嶺**：你會 `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` 了 — 但這只是 window function 的 30%。真正拉開差距的是 **frame（窗框）**：`ROWS` vs `RANGE` vs `GROUPS`、預設 frame 是什麼、以及 **Gaps and Islands** 這個所有資深 SQL 面試都會出現的模式。

> ⚠️ 這是全套訓練最重要的一個 Phase。Gaps and Islands 沒練過，面試現場 100% 寫不出來。

### 核心概念

| 概念 | 重點 |
|------|------|
| **預設 frame** | 有 `ORDER BY` 時預設是 `RANGE UNBOUNDED PRECEDING AND CURRENT ROW`，不是全窗！ |
| `ROWS` vs `RANGE` vs `GROUPS` | 有並列值時三者結果完全不同 |
| `LAST_VALUE` 陷阱 | 為什麼它總是回傳當前行 |
| `FIRST_VALUE` / `NTH_VALUE` | 配合 frame 才有意義 |
| **Gaps and Islands** | `序號差值分組`：連續登入、連續天數、區間合併 |
| Sessionization | `LAG` 判斷斷點 + 條件累加建 session_id |
| Frame with `INTERVAL` | `RANGE BETWEEN INTERVAL '7 days' PRECEDING` |
| Window 的極限 | 哪些「依賴前一行計算結果」的問題 window **做不到**，必須遞迴 |
| `EXCLUDE` 子句 | `EXCLUDE CURRENT ROW` / `EXCLUDE TIES` |

### 練習題

| # | 題目 | 核心技巧 | 難度 | 狀態 |
|---|------|---------|------|------|
| 01 | [The LAST_VALUE That Lied](phase-3-window-deep-water/01-the-last-value-that-lied) | 預設 frame 陷阱、三種修法 | ★★★★☆ |  |
| 02 | [ROWS vs RANGE vs GROUPS](phase-3-window-deep-water/02-rows-vs-range-vs-groups) | 並列值下的 frame 語意差異 | ★★★★☆ |  |
| 03 | [Gaps and Islands I — The Login Streak](phase-3-window-deep-water/03-gaps-and-islands-i-login-streak) | 經典 islands（序號差值分組） | ★★★★☆ |  |
| 04 | [Gaps and Islands II — Merge Overlapping Intervals](phase-3-window-deep-water/04-gaps-and-islands-ii-merge-intervals) | 進階 islands（running max 判斷斷點） | ★★★★★ |  |
| 05 | [Sessionization: The 30-Minute Rule](phase-3-window-deep-water/05-sessionization-30-minute-rule) | `LAG` + 條件累加建 session_id | ★★★★★ |  |
| 06 | [Rolling 7-Day Average With Missing Days](phase-3-window-deep-water/06-rolling-7-day-average) | `RANGE BETWEEN INTERVAL` + 三種分母定義 | ★★★★☆ |  |
| 07 | [The Running Balance With a Floor](phase-3-window-deep-water/07-the-running-balance-with-a-floor) | window **解不出來**的題（為 Phase 4 鋪路） | ★★★★★ |  |

### Phase 3 自我檢測

給你一張登入紀錄表，找出每個使用者**最長的連續登入天數**。

你要能在 5 分鐘內講出核心技巧：`event_date - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_date))::INT` 為什麼在連續區段內是常數。講不出「為什麼」就是背的，面試官一追問就破功。

<br>
<br>

---

<br>
<br>

## Phase 4：遞迴 CTE 進階 — 圖、樹、與展開

> **變化自**：sql_training Phase 4（CTE 與遞迴）

**為什麼需要**：你會用遞迴 CTE 找管理鏈了。但真實資料會有**環**（A 的主管是 B，B 的主管是 A — 資料錯誤但你的查詢會無限迴圈跑爆 DB）。這一階段處理的是遞迴的真實世界版本：環偵測、路徑追蹤、數量累乘、以及「window function 做不到，只能遞迴」的那類題。

### 核心概念

| 概念 | 重點 |
|------|------|
| 環偵測 | `path` 陣列 + `NOT (id = ANY(path))`，或 PG 14+ 的 `CYCLE` 子句 |
| 路徑追蹤 | 累積 array / string 記錄完整路徑 |
| 深度限制 | `WHERE depth < N` 防止爆炸 |
| 累乘 / 累加 | BOM 展開時數量要沿路徑相乘 |
| BFS vs DFS | 遞迴 CTE 預設行為，以及怎麼控制 |
| `UNION` vs `UNION ALL` | 在遞迴中 `UNION` 會自動去重（也會變慢） |
| 遞迴 vs Window | 什麼時候非遞迴不可 |

### 練習題

| # | 題目 | 核心技巧 | 難度 | 狀態 |
|---|------|---------|------|------|
| 01 | [The Org Chart That Loops](phase-4-recursive-cte/01-the-org-chart-that-loops) | 遞迴 + 環偵測（path array / `CYCLE` / 深度上限） | ★★★★★ |  |
| 02 | [Bill of Materials Explosion](phase-4-recursive-cte/02-bill-of-materials-explosion) | 沿路徑累乘 + 跨路徑加總 | ★★★★★ |  |
| 03 | [Shortest Path Between Two Users](phase-4-recursive-cte/03-shortest-path-between-two-users) | 遞迴 BFS + 無向圖剪枝 + 最短路徑 | ★★★★★ |  |
| 04 | [Manager Chain With Full Path](phase-4-recursive-cte/04-manager-chain-with-full-path) | 路徑字串 + 深度 + 子樹聚合 | ★★★★☆ |  |
| 05 | [The Running Balance, Recursive Edition](phase-4-recursive-cte/05-running-balance-recursive-edition) | 解 Phase 3-07 解不出的題 | ★★★★★ |  |
| 06 | [Split a String Into Rows](phase-4-recursive-cte/06-split-a-string-into-rows) | 遞迴字串切割 + set-returning function 的隱形 INNER JOIN | ★★★☆☆ |  |
| 07 | [The Recursion That Never Ended](phase-4-recursive-cte/07-the-recursion-that-never-ended) | 五種失效模式除錯（含兩個**不報錯**的陷阱） | ★★★★☆ |  |

### Phase 4 自我檢測

面試官說：「我們的組織表有髒資料，某兩個人互為對方的主管。你的遞迴查詢會怎樣？怎麼防？」

你要能講出：無限迴圈 → work table 永遠不空 → 記憶體爆掉。防法有三種（path array、深度上限、PG 14 `CYCLE` 子句），並說出各自的取捨。

<br>
<br>

---

<br>
<br>

## Phase 5：時間序列與行為分析 — 資料分析職缺的主戰場

> **變化自**：sql_training Phase 2/3（Game Play Analysis 系列、日期偏移）

**為什麼獨立成一章**：Game Play Analysis I~IV 是這個領域的**入門版**。真實的成長團隊面試會問：留存矩陣、漏斗轉換、cohort 曲線、DAU/WAU/MAU。這些題的共同點是 — **時間軸上的正確性**比 SQL 語法難得多。

### 核心概念

| 概念 | 重點 |
|------|------|
| 留存矩陣 | Day-N 留存的定義（當日 vs 累計）、分母是誰 |
| 漏斗分析 | 事件**順序**約束，不是單純 `COUNT DISTINCT` |
| Cohort 分群 | 以首次行為時間分組，追蹤後續表現 |
| Calendar Spine | `generate_series` 造日期骨架，補齊沒資料的日子 |
| LOCF | Last Observation Carried Forward（前值填補） |
| **As-Of Join** | Point-in-time 正確性：用「當時」的匯率，不是「現在」的 |
| SCD Type 2 | 緩慢變化維度的時間切片查詢 |
| 滑動視窗去重計數 | DAU / WAU / MAU 為什麼不能直接 `SUM` |

### 練習題

| # | 題目 | 核心技巧 | 難度 | 狀態 |
|---|------|---------|------|------|
| 01 | [The Retention Matrix](phase-5-time-series/01-the-retention-matrix) | Day-N 留存、分母定義、未成熟 cohort | ★★★★★ |  |
| 02 | [Funnel Analysis With Order Constraint](phase-5-time-series/02-funnel-analysis-with-order-constraint) | 事件順序約束、逐層收斂 | ★★★★★ |  |
| 03 | [Cohort Revenue Curve](phase-5-time-series/03-cohort-revenue-curve) | Cohort 分群 + 累計曲線 + ARPU/ARPPU | ★★★★☆ |  |
| 04 | [The As-Of Join](phase-5-time-series/04-the-as-of-join) | Point-in-time 正確性（歷史匯率） | ★★★★★ |  |
| 05 | [SCD Type 2 Point Query](phase-5-time-series/05-scd-type-2-point-query) | 區間重疊/缺口稽核、半開區間 | ★★★★☆ |  |
| 06 | [Days With No Sales](phase-5-time-series/06-days-with-no-sales) | **流量 vs 存量**的填補策略、LOCF | ★★★★☆ |  |
| 07 | [DAU / WAU / MAU in One Query](phase-5-time-series/07-dau-wau-mau-in-one-query) | 滑動視窗去重、`COUNT(DISTINCT)` 不可組合 | ★★★★★ |  |

### Phase 5 自我檢測

面試官問：「算一下我們產品的 7 日留存率。」

**先不要寫 SQL。** 你要先反問三個問題：
1. 分母是誰？（當日新增用戶 / 當日活躍用戶）
2. 「第 7 日留存」是指「恰好第 7 天有回來」還是「第 1~7 天內有回來」？
3. 時區怎麼算？跨日的定義是什麼？

**問對問題比寫對 SQL 更能拿分。**

<br>
<br>

---

<br>
<br>

## Phase 6：DML、併發、與資料正確性

> **變化自**：sql_training Phase 5（DML）

**為什麼難度跳一級**：sql_training 的 DML 題（刪重複 email、UPDATE 加獎金）都是**單人操作**。真實系統是**多個 process 同時在改同一張表**。這一階段的每一題，答案在單執行緒下都是對的，在併發下都是錯的。

> 這是 Backend Engineer 面試的高頻區。你的 PostgreSQL 實戰經驗在這裡會很吃香。

### 核心概念

| 概念 | 重點 |
|------|------|
| Idempotent Upsert | `INSERT ... ON CONFLICT DO UPDATE`、部分唯一索引 |
| `MERGE`（PG 15+） | 語法、與 `ON CONFLICT` 的差異、它**不**保證的事 |
| 隔離級別 | Read Committed / Repeatable Read / Serializable 的實際差異 |
| Lost Update | 讀-改-寫的經典錯誤 + 樂觀鎖（version 欄位） |
| `FOR UPDATE SKIP LOCKED` | Job Queue 的正確做法 |
| `EXCLUDE` 約束 | 用 GiST 索引在**寫入時**擋掉區間重疊 |
| 死鎖避免 | 固定鎖順序 |
| 大表安全刪除 | 分批 + `ctid` + 鎖持有時間 |

### 練習題

> ⚠️ **這一章的題目多數需要「同時開兩個 session」。**
> 開始前先讀 [Phase 6 章節說明](phase-6-dml-concurrency)（怎麼開兩個 session、怎麼查誰擋住誰、保命習慣）。

| # | 題目 | 核心技巧 | 難度 | 狀態 |
|---|------|---------|------|------|
| 01 | [The Idempotent Upsert](phase-6-dml-concurrency/01-the-idempotent-upsert) | `ON CONFLICT`、部分唯一索引、冪等性 | ★★★★☆ |  |
| 02 | [The Job Queue That Double-Processed](phase-6-dml-concurrency/02-the-job-queue-that-double-processed) | `FOR UPDATE SKIP LOCKED` | ★★★★★ |  |
| 03 | [Preventing Double Booking](phase-6-dml-concurrency/03-preventing-double-booking) | `EXCLUDE` 約束（Phase 1-03 的寫入端解法） | ★★★★★ |  |
| 04 | [The Lost Update](phase-6-dml-concurrency/04-the-lost-update) | 隔離級別、樂觀鎖 vs 悲觀鎖 | ★★★★★ |  |
| 05 | [Transfer Money Atomically](phase-6-dml-concurrency/05-transfer-money-atomically) | 交易原子性、死鎖與鎖順序 | ★★★★☆ |  |
| 06 | [Deduplicate a 10M-Row Table](phase-6-dml-concurrency/06-deduplicate-a-10m-row-table) | `ctid`、分批刪除、鎖持有時間 | ★★★★★ |  |
| 07 | [MERGE vs ON CONFLICT](phase-6-dml-concurrency/07-merge-vs-on-conflict) | PG15 `MERGE` 的**併發陷阱** | ★★★☆☆ |  |

### Phase 6 自我檢測

面試官給你這段程式碼：

```sql
SELECT balance FROM accounts WHERE id = 1;       -- 讀到 1000
-- 應用層計算 1000 - 300 = 700
UPDATE accounts SET balance = 700 WHERE id = 1;  -- 寫回
```

問：「兩個人同時提款 300，最後餘額是多少？應該是多少？怎麼修？」

你要能講出：Lost Update → 結果是 700（應該是 400）→ 三種修法（`SET balance = balance - 300`、樂觀鎖 version、`SELECT FOR UPDATE`）→ 各自的取捨。

<br>
<br>

---

<br>
<br>

## Phase 7：查詢優化深水區

> **變化自**：sql_training Phase 7（4 個 Scenario）

**為什麼還要更深**：sql_training Phase 7 教你「加對 index」。這一階段教你 **planner 為什麼不用你加的 index** — 統計資訊誤估、選擇性判斷、分區裁剪失效。Senior/Staff 面試追問到最後都是這一層。

> 先確認你讀過 [PostgreSQL Scan Types 完整教學](../sql_training/postgresql_scan_types.md)。

### 核心概念

| 概念 | 重點 |
|------|------|
| 統計資訊 | `ANALYZE`、`n_distinct`、MCV list、planner 怎麼估行數 |
| 擴展統計 | `CREATE STATISTICS`：相關欄位的聯合選擇性 |
| Partial Index | 只索引 1% 的資料，索引小 10 倍 |
| Expression Index | `CREATE INDEX ... ON t (LOWER(email))` |
| Covering Index | `INCLUDE` 子句 + Index Only Scan + `VACUUM` 的關係 |
| 分區裁剪 | Partition pruning 什麼時候失效 |
| Correlated Subquery 改寫 | N+1 式查詢 → window function |
| Materialized View | 刷新策略、`CONCURRENTLY`、增量設計 |
| `random_page_cost` | 為什麼 SSD 環境的預設值是錯的 |

### 練習題

> 這一章每一題都要跑 `EXPLAIN (ANALYZE, BUFFERS)`，**把實際輸出貼進 `answer.sql`** —— 數字就是證據。
> 資料量比較大（最大 100 萬列），`setup.sql` 執行需要數十秒。

| # | 題目 | 核心技巧 | 難度 | 狀態 |
|---|------|---------|------|------|
| 01 | [The Query That Got Slower After Adding an Index](phase-7-optimization-deep-water/01-the-query-that-got-slower-after-adding-an-index) | `ORDER BY`+`LIMIT` 的提前終止誤判 | ★★★★★ |  |
| 02 | [Correlated Subquery → Window Rewrite](phase-7-optimization-deep-water/02-correlated-subquery-to-window-rewrite) | N+1 查詢、`loops=N` 的意義 | ★★★★☆ |  |
| 03 | [Partial Index for the 1% Case](phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case) | Partial / Expression Index、計畫快取 | ★★★★☆ |  |
| 04 | [The Covering Index That Stopped Covering](phase-7-optimization-deep-water/04-the-covering-index-that-stopped-covering) | Index Only Scan、Visibility Map、`VACUUM` | ★★★★☆ |  |
| 05 | [The Statistics Lie](phase-7-optimization-deep-water/05-the-statistics-lie) | 欄位獨立性假設、`CREATE STATISTICS` | ★★★★★ |  |
| 06 | [Partition Pruning Gone Wrong](phase-7-optimization-deep-water/06-partition-pruning-gone-wrong) | 裁剪失效的三種原因、Runtime Pruning | ★★★★★ |  |
| 07 | [Materialized View Refresh Strategy](phase-7-optimization-deep-water/07-materialized-view-refresh-strategy) | `REFRESH` 的鎖行為、增量刷新設計 | ★★★★☆ |  |

### Phase 7 自我檢測

面試官問：「你加了 index，`EXPLAIN` 顯示 planner 還是選 Seq Scan。你怎麼排查？」

你要能給出**有順序的排查流程**，而不是猜：
1. `EXPLAIN ANALYZE` 對比 `rows=` 估計值 vs `actual rows=` — 差距大就是統計問題
2. 跑 `ANALYZE`，再看一次
3. 檢查最左前綴、檢查欄位有沒有被函數包住、有沒有隱式型別轉換
4. `SET enable_seqscan = off` 強制走 index，比較 cost — planner 是**故意的**還是**估錯了**
5. 都不是的話看 `random_page_cost` 設定

<br>
<br>

---

<br>
<br>

## Phase 8：面試實戰模擬 — 模糊需求下的完整作答

> **新增章節，無對應基礎題**

**為什麼要有這一章**：前面 7 個 Phase 每題都有明確的正確答案。**真實面試沒有。** 面試官會丟一句「幫我算一下活躍用戶」，然後看你：會不會問清楚定義、會不會提出邊界、會不會講取捨。這一章每一題都是**故意寫得模糊的**。

### 這一章的評分標準不同

| 面向 | 佔比 |
|------|------|
| 需求釐清（你問了什麼問題） | 30% |
| SQL 正確性 | 30% |
| 邊界與髒資料處理 | 20% |
| 效能考量與取捨說明 | 20% |

**你的 `answer.sql` 必須以「我會先問面試官這幾個問題」開頭。** 直接寫 SQL 的一律扣 3 分。

### 練習題

> 開始前先讀 [Phase 8 章節說明](phase-8-interview-simulation)（評分標準、作答結構、通關標準）。

| # | 題目 | 場景 | 難度 | 狀態 |
|---|------|------|------|------|
| 01 | [The Ambiguous Metric](phase-8-interview-simulation/01-the-ambiguous-metric) | 「算一下活躍用戶數」— 需求釐清 + 多定義並陳 | ★★★★★ |  |
| 02 | [Design a Leaderboard Query](phase-8-interview-simulation/02-design-a-leaderboard-query) | 排行榜：排名、分頁、並列、即時性 | ★★★★★ |  |
| 03 | [The Fraud Detection Query](phase-8-interview-simulation/03-the-fraud-detection-query) | 多訊號盜刷偵測（三條白話規則） | ★★★★★ |  |
| 04 | [Debug This Query](phase-8-interview-simulation/04-debug-this-query) | 一段有 **5 個 bug** 的報表 SQL（唯一有標準答案的一題） | ★★★★★ |  |
| 05 | [The 90-Minute Take-Home](phase-8-interview-simulation/05-the-90-minute-take-home) | **計時畢業考**：完整 schema + 5 題 + 10 個資料陷阱 | ★★★★★ |  |

### Phase 8 自我檢測

**這一章沒有自我檢測。** 通過的標準是：你能不能在 45 分鐘內，對著一個陌生 schema 和一句模糊需求，交出一份**你敢寄給面試官**的 `answer.sql`。

<br>
<br>

---

<br>
<br>

## 總覽

**全部 54 題已建立完成。** 每一題的測試資料與預期輸出都在 PostgreSQL 18 上實跑驗證過。

| Phase | 主題 | 題數 | 變化自 | 建議天數 | 狀態 |
|-------|------|------|--------|---------|------|
| [1](#phase-1join-的暗面--當--不夠用時) | JOIN 的暗面 | 7 | 基礎 Phase 1 | 7 |  |
| [2](#phase-2聚合的極限--一次查詢完成整張報表) | 聚合的極限 | 7 | 基礎 Phase 1/6 | 7 |  |
| [3](#phase-3window-function-深水區--frame-才是真正的考點) | Window Function 深水區 | 7 | 基礎 Phase 3 | 10 |  |
| [4](#phase-4遞迴-cte-進階--圖樹與展開) | 遞迴 CTE 進階 | 7 | 基礎 Phase 4 | 8 |  |
| [5](#phase-5時間序列與行為分析--資料分析職缺的主戰場) | 時間序列與行為分析 | 7 | 基礎 Phase 2/3 | 10 |  |
| [6](#phase-6dml併發與資料正確性) | DML、併發、資料正確性 | 7 | 基礎 Phase 5 | 8 |  |
| [7](#phase-7查詢優化深水區) | 查詢優化深水區 | 7 | 基礎 Phase 7 | 8 |  |
| [8](#phase-8面試實戰模擬--模糊需求下的完整作答) | 面試實戰模擬 | 5 | — | 7 |  |
| | **合計** | **54** | | **~65 天** | |

<br>

### 貫穿全書的五條線

這 54 題不是獨立的。有五個觀念會反覆出現，**每次換一個場景咬你一次**：

| 主題 | 出現在 |
|------|--------|
| **NULL 與三值邏輯** | 1-01 → 1-04 → 2-02 → 3-05 → 4-06 → 8-04 |
| **半開區間 `[a, b)`** | 1-03 → 2-06 → 5-05 → 6-03 → **7-06（這次會算錯答案）** |
| **JOIN 扇出 / 預聚合** | 2-07 → 5-05 → 7-02 → 8-04 |
| **骨架補齊（缺漏的維度）** | 1-07 → 2-06 → 3-06 → 5-06 → 8-05 |
| **讓錯誤狀態無法被表達** | 1-02 → 1-06 → 4-01 → 5-05 → **6-03（寫入端解法）** |

<br>

### 三條跨章節的問題線

| 問題 | 提出 | 深化 | 收束 |
|------|------|------|------|
| 有下限的餘額怎麼算 | [3-07](phase-3-window-deep-water/07-the-running-balance-with-a-floor) window 做不到 | [4-05](phase-4-recursive-cte/05-running-balance-recursive-edition) 遞迴做得到但慢 | [6-04](phase-6-dml-concurrency/04-the-lost-update) 真實系統兩個都不用 |
| 區間重疊怎麼處理 | [1-03](phase-1-join-dark-side/03-the-double-booked-meeting-room) 偵測已發生的 | [3-04](phase-3-window-deep-water/04-gaps-and-islands-ii-merge-intervals) 合併它們 | [6-03](phase-6-dml-concurrency/03-preventing-double-booking) 寫入時就擋掉 |
| 為什麼估計會錯 | [7-01](phase-7-optimization-deep-water/01-the-query-that-got-slower-after-adding-an-index) 位置分布誤判 | [7-05](phase-7-optimization-deep-water/05-the-statistics-lie) 欄位相關性誤判 | [7-05 D1](phase-7-optimization-deep-water/05-the-statistics-lie) 統計修不好 7-01 —— 工具的能力邊界 |

<br>

### 建議推進順序

**不要跳章。** 但如果時間有限，優先順序是：

1. **Phase 3**（Window 深水區）— 最高投報率，Gaps and Islands 幾乎必考
2. **Phase 1**（JOIN 暗面）— NULL 陷阱是最常見的淘汰點
3. **Phase 5**（時間序列）— 資料職缺主戰場
4. **Phase 6**（併發）— Backend 職缺主戰場
5. 其餘依序

<br>
<br>

---

<br>
<br>

## 附錄：進階面試的加分習慣

sql_training 的附錄教你怎麼**寫出來**。這裡教你怎麼**贏**。

1. **先講邊界，再寫 SQL**
   拿到題目先說：「我假設 `customer_id` 可能為 NULL，這會影響我選 `NOT EXISTS` 而不是 `NOT IN`。」— 這一句話就贏過 80% 的候選人。

2. **主動說出你的取捨**
   「這裡我用 window function 而不是 LATERAL，因為客戶數多；如果客戶數少但訂單數大，LATERAL + 索引會快很多。」

3. **寫完主動找自己的 bug**
   「等一下，如果兩筆訂單金額並列，`ROW_NUMBER` 會隨機挑一筆，這裡應該用 `DENSE_RANK`。」— 自己抓到 bug 是加分，被面試官抓到是扣分。

4. **量化你的優化**
   不要說「這樣會比較快」，要說「Seq Scan 掃 15 萬行變成 Index Scan 掃 487 行，大約 300 倍」。

5. **不知道就說不知道，然後說你會怎麼查**
   「我不確定 PG 的 `MERGE` 在併發下的行為，我會查文件確認它是否需要額外的鎖。」— 比硬掰好一百倍。

6. **每題寫完問自己三個問題**
   - 資料有 NULL 會怎樣？
   - 資料有重複會怎樣？
   - 資料量 ×1000 會怎樣？

<br>

