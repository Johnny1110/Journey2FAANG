# Phase 5-07 — DAU / WAU / MAU in One Query

> **難度**：★★★★★
> **核心技巧**：滑動視窗**去重**計數、`COUNT(DISTINCT)` 的不可組合性
> **對應基礎題**：[LC 1141. User Activity for the Past 30 Days I](../../../sql_training/user_activity_for_the_past_30_days_i)

<br>

---

<br>

## Interview Context

> *面試官：*「儀表板要 DAU、WAU、MAU 三條線。
>
> 上一位工程師的做法是：先算好每天的 DAU 存成一張表，WAU 就是**過去 7 天的 DAU 加總**，MAU 是過去 30 天加總。這樣只要掃一次原始表，超快。
>
> 他上週離職了。今天 CEO 問我：『**為什麼我們的 WAU 比註冊總用戶數還多？**』」

<br>

**DAU 加總不等於 WAU。** 這是資料分析最經典的錯誤之一，而它的根源你在 [Phase 2-05](../../phase-2-aggregation-limits/05-the-weighted-average-trap) 已經學過了：**`COUNT(DISTINCT)` 是不可組合的聚合。**

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS app_activity;

CREATE TABLE app_activity (
    user_id     INT NOT NULL,
    active_date DATE NOT NULL,
    PRIMARY KEY (user_id, active_date)
);

-- user 1、2：每天都活躍
INSERT INTO app_activity
SELECT u, d::date
FROM generate_series(1, 2) u,
     generate_series('2026-03-01'::date, '2026-03-10'::date, '1 day') d;

-- user 3、4、5：各只出現一天
INSERT INTO app_activity (user_id, active_date) VALUES
(3, '2026-03-01'),
(4, '2026-03-05'),
(5, '2026-03-10');
```

<br>

**總共只有 5 個使用者。記住這個數字。**

<br>

### 正確答案

```
     d      | dau | wau_correct | sum_of_dau_WRONG
------------+-----+-------------+------------------
 2026-03-01 |   3 |           3 |                3
 2026-03-02 |   2 |           3 |                5
 2026-03-03 |   2 |           3 |                7
 2026-03-04 |   2 |           3 |                9
 2026-03-05 |   3 |           4 |               12
 2026-03-06 |   2 |           4 |               14
 2026-03-07 |   2 |           4 |               16
 2026-03-08 |   2 |           3 |               15
 2026-03-09 |   2 |           3 |               15
 2026-03-10 |   3 |           4 |               16
```

<br>

> **`2026-03-07`：真實 WAU 是 4，加總法算出 16。**
> 全公司只有 5 個使用者 —— 一個「16 人週活躍」的數字本身就不可能成立。

<br>

---

<br>

## Part A — 重現錯誤

### A1

寫出 DAU（每天的去重活躍人數）。

### A2

寫出兩個版本的 WAU：
- **加總版**（錯）：過去 7 天 DAU 相加
- **正確版**：過去 7 天的**去重**使用者數

驗證 `2026-03-07` 分別是 16 和 4。

### A3 — 診斷

回答：
- 加總法把 user 1 算了幾次？
- **為什麼加總法的錯誤會隨著「使用者黏著度」放大？**
- 如果所有使用者都只在一週內出現一次（完全不重複），加總法會是對的嗎？
- **這解釋了什麼？** 為什麼這個 bug 在產品早期不明顯，用戶越黏著錯得越離譜？

### A4 — 連回 Phase 2-05

[Phase 2-05](../../phase-2-aggregation-limits/05-the-weighted-average-trap) Part A4 你做過一張「可組合 vs 不可組合聚合」的分類表。

- `COUNT(DISTINCT)` 你當初分在哪一類？
- 用**這一題**當具體例子，重新解釋為什麼它不可組合。
- **同一個原理，第二次咬你。**

<br>

---

<br>

## Part B — 正確的實作

### B1 — 自連接 / 相關子查詢版

對每一天，去掃過去 7 天的原始資料做 `COUNT(DISTINCT)`。

寫出來，然後跑 `EXPLAIN ANALYZE`。

回答：這個查詢掃了 `app_activity` 幾次？資料量大時可行嗎？

### B2 — Window function 版？

直覺會想：

```sql
COUNT(DISTINCT user_id) OVER (ORDER BY active_date RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW)
```

**跑跑看。**

回答：
- PostgreSQL 接受這個語法嗎？完整錯誤訊息是什麼？
- **為什麼 window function 不支援 `DISTINCT`？**（提示：想想 frame 滑動時，要維護什麼狀態才能做到去重計數？）
- 這和 [Phase 3-07](../../phase-3-window-deep-water/07-the-running-balance-with-a-floor) 的「window 做不到」是同一類限制嗎？

### B3 — 首末次活躍法（進階）

有一個聰明的做法：**對每個使用者的每一次活躍，算出他「上一次活躍」是什麼時候**。

如果 `active_date - 上次活躍 > 7`，那他在這一天是「重新進入」7 日視窗的。

用這個思路把 WAU 轉換成一個**可累加**的問題。

> 提示：把「使用者進入視窗」和「使用者離開視窗」各看成一個 +1 / −1 事件，然後對事件做累計和。
> 這是 [Phase 3-04](../../phase-3-window-deep-water/04-gaps-and-islands-ii-merge-intervals) 面試官追問 2 提到的 **sweep line** 手法。

寫出來，驗證結果和 B1 一致。

### B4 — 三個指標一起

寫出一個查詢，同時輸出 DAU / WAU / MAU（30 日）以及兩個黏著度比率：

- `DAU/MAU`（業界標準的黏著度指標）
- `WAU/MAU`

<br>

---

<br>

## Part C — 定義的坑

### C1 — 「過去 7 天」含不含今天

- `[d-6, d]` 是 7 天，`[d-7, d]` 是 8 天。你用哪一個？
- 業界慣例是哪一個？
- **這個差異在數字上有多大？**（本題資料實測一次）

### C2 — 起頭不完整

`2026-03-01` 的 WAU 只有 1 天的資料（前面沒有資料）。

- 它該顯示 3（現有的）還是 NULL（資料不足）？
- 和 [5-01](../01-the-retention-matrix) 的未成熟 cohort 是同一個問題嗎？
- 寫出「資料不足 7 天就顯示 NULL」的版本。

### C3 — MAU 是 30 天還是自然月

- 「MAU」到底是「過去 30 天」還是「本月」？
- 兩者在月初會差多少？
- **CEO 問「這個月的 MAU」時，他要的是哪一個？** 你怎麼確認？

<br>

---

<br>

## Part D — 規模

### D1

`app_activity` 有 100 億列（1 億使用者 × 100 天）。

- B1 的做法要掃幾次？
- B3 的做法呢？
- **B3 為什麼能省下這麼多？**

### D2 — 近似算法

回答：
- 什麼是 **HyperLogLog**？它解決什麼問題？
- PostgreSQL 有 `postgresql-hll` extension。用它算 WAU 的原理是什麼？
- **HLL 的 sketch 是可以合併的** —— 這代表什麼？它把 `COUNT(DISTINCT)` 變成可組合的了嗎？
- 誤差率大約多少？CEO 的儀表板可以接受嗎？

> **這一題是這一章最好的收尾**：
> 你先學到「`COUNT(DISTINCT)` 不可組合，所以不能預先彙總」，
> 然後學到「業界用近似算法讓它**變成**可組合的」。
> 能講完這兩層，面試官會知道你不只會寫 SQL。

<br>

---

<br>

## 面試官的追問

> 1. 「如果要算『**過去 7 天每天都活躍**』的使用者數（不是任一天），查詢怎麼改？」
>
> 2. 「DAU/MAU 這個比率的業界基準大概多少？為什麼它比絕對數字更有意義？」
>
> 3. 「如果一個使用者跨時區旅行，他的『活躍日』該怎麼算？」
>
> 4. 「WAU 突然掉了 20%，你會怎麼排查？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼加總會爆炸</summary>

`2026-03-01` ~ `2026-03-07` 的 DAU：`3, 2, 2, 2, 3, 2, 2` → 相加 = **16**

但實際上這 7 天只出現過 4 個不同的人：

- **user 1**：7 天都活躍 → 被算了 **7 次**
- **user 2**：7 天都活躍 → 被算了 **7 次**
- **user 3**：只有 03-01 → 算 1 次
- **user 4**：只有 03-05 → 算 1 次

`7 + 7 + 1 + 1 = 16` ✓

**誤差的來源就是「重複活躍」。** 使用者越黏著（回訪越頻繁），加總法錯得越誇張：

- 所有人每天都來 → 加總法 = 真實值 × 7
- 所有人一週只來一次 → 加總法 = 真實值（**碰巧正確**）

**這就是為什麼這個 bug 在產品早期看不出來** —— 早期用戶不黏，加總法接近正確。等產品做起來、用戶天天回訪，數字才開始離譜。

</details>

<details>
<summary>Hint 2 — 正確的 WAU</summary>

```sql
WITH spine AS (
    SELECT generate_series('2026-03-01'::date, '2026-03-10'::date, '1 day')::date AS d
)
SELECT sp.d,
       (SELECT COUNT(DISTINCT a.user_id) FROM app_activity a
        WHERE a.active_date = sp.d)                          AS dau,
       (SELECT COUNT(DISTINCT a.user_id) FROM app_activity a
        WHERE a.active_date BETWEEN sp.d - 6 AND sp.d)       AS wau,
       (SELECT COUNT(DISTINCT a.user_id) FROM app_activity a
        WHERE a.active_date BETWEEN sp.d - 29 AND sp.d)      AS mau
FROM spine sp
ORDER BY sp.d;
```

**關鍵：`COUNT(DISTINCT)` 必須直接對「原始的活躍紀錄」做**，不能對任何預先彙總過的結果做。

用 `spine` 而不是 `SELECT DISTINCT active_date` 當日期來源 —— 這樣**完全沒有人活躍的日子**也會出現在報表上（[Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的骨架心法）。

</details>

<details>
<summary>Hint 3 — window function 為什麼不支援 DISTINCT</summary>

```sql
COUNT(DISTINCT user_id) OVER (ORDER BY active_date RANGE ...)
```

PostgreSQL 回報：

```
ERROR:  DISTINCT is not implemented for window functions
```

**為什麼**：window function 的高效實作依賴「**增量更新**」—— frame 往前滑一格時，只要「加上新進來的行、減掉離開的行」就能更新結果。

`SUM`、`COUNT(*)`、`AVG` 都可以這樣增量維護。

但 `COUNT(DISTINCT)` 不行：當一個 user 離開 frame 時，你不知道該不該把計數減 1 —— **要看 frame 裡還有沒有同一個 user 的其他列**。要正確處理，你得為 frame 內每個值維護一個出現次數的字典。

**這和 [Phase 2-05](../../phase-2-aggregation-limits/05-the-weighted-average-trap) 的不可組合性是同一件事的兩個面向**：
- 不可組合 → 不能把子結果合併
- 不可增量 → 不能在滑動視窗中高效維護

**根本原因都是：`COUNT(DISTINCT)` 需要保留完整的元素集合，而不只是一個彙總數字。**

</details>

<details>
<summary>Hint 4 — B3 的 sweep line 手法</summary>

**先把問題重新表述**：使用者在 `d` 這天活躍，代表他在 `[d, d+6]` 這 7 天內都會被算進 WAU。

所以每一次活躍 = 一段**覆蓋區間** `[d, d+6]`。一個 user 對某天的 WAU 有貢獻，就是「他的某段覆蓋區間包含那天」。

於是問題變成：**把每個 user 的覆蓋區間合併，再做 sweep line。**

```sql
WITH cov AS (                                    -- 每次活躍 = 一段 7 天覆蓋
    SELECT user_id, active_date AS s, active_date + 6 AS e
    FROM app_activity
),
flagged AS (                                     -- Phase 3-04 的區間合併
    SELECT *, CASE WHEN s > MAX(e) OVER (PARTITION BY user_id ORDER BY s
                                         ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
                   THEN 1 ELSE 0 END AS newg
    FROM cov
),
grp AS (
    SELECT *, SUM(newg) OVER (PARTITION BY user_id ORDER BY s) AS g FROM flagged
),
merged AS (                                      -- 每個 user 剩下幾段互不重疊的區間
    SELECT user_id, MIN(s) AS s, MAX(e) AS e FROM grp GROUP BY user_id, g
),
ev AS (                                          -- sweep line：進 +1、出 −1
    SELECT s AS d, 1 AS delta FROM merged
    UNION ALL
    SELECT e + 1, -1 FROM merged
)
SELECT d, SUM(SUM(delta)) OVER (ORDER BY d) AS wau
FROM ev GROUP BY d ORDER BY d;
```

輸出的是**變化點**，不是每一天：

```
     d      | wau
------------+-----
 2026-03-01 |   3
 2026-03-05 |   4      ← 03-02~03-04 維持 3
 2026-03-08 |   3      ← 03-06~03-07 維持 4
 2026-03-10 |   4
 2026-03-12 |   3
 2026-03-17 |   0
```

對照 B1 的逐日結果 `3,3,3,3,4,4,4,3,3,4` —— **完全吻合**。

要變成逐日序列，就 `LEFT JOIN` 日期骨架再做 **LOCF** —— 正好是 [5-06](../06-days-with-no-sales) 學的技巧（WAU 是**存量**，缺漏的日子當然是「和前一天一樣」）。

<br>

> ⚠️ **一個很容易寫錯的版本**：只用 `LAG` 判斷「距離上次活躍超過 7 天才算重新進入」，然後在 `active_date + 7` 減 1。
>
> 這對**每天都活躍**的使用者是錯的 —— user 1 從 03-01 一路活躍到 03-10，只有第一天觸發 `+1`，卻在 03-08 就被減掉了，但他其實要到 03-17 才離開視窗。
>
> **必須先合併覆蓋區間**，否則「持續活躍」的使用者會被提早踢出。

<br>

（`SUM(SUM(delta)) OVER (...)` 的雙層 `SUM` 是 window function 套在聚合結果上 —— 內層屬於 `GROUP BY d`，外層是累計。）

**這正是 D1 的答案**：B1 每一天掃一次表（O(天數 × 資料量)），B3 只掃一次加排序（O(資料量 log 資料量)）。

**而且這一題用上了 [Phase 3-04](../../phase-3-window-deep-water/04-gaps-and-islands-ii-merge-intervals) 的區間合併 + [5-06](../06-days-with-no-sales) 的 LOCF** —— 前面學的兩個技巧在這裡合體。

</details>
