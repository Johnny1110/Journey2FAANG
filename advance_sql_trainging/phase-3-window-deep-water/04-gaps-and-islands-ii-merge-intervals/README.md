# Phase 3-04 — Gaps and Islands II：Merge Overlapping Intervals

> **難度**：★★★★★
> **核心技巧**：Running MAX 判斷斷點、區間合併、`LAG` 為什麼不夠
> **對應基礎題**：[Phase 1-03. The Double-Booked Meeting Room](../../phase-1-join-dark-side/03-the-double-booked-meeting-room)（那題**偵測**重疊，這題**合併**重疊）

<br>

---

<br>

## Interview Context

> *面試官：*「行銷部門要知道每個產品**總共被投放廣告幾天**。
>
> 麻煩的是同一個產品常常有多個檔期同時在跑 —— 業務簽了一檔、品牌部又簽了一檔、時間重疊。
>
> **重疊的天數只能算一次。** 直接把每檔天數加起來會嚴重高估。」

<br>

這是 Gaps and Islands 的**進階版**。[3-03](../03-gaps-and-islands-i-login-streak) 處理的是**點**（一天一個登入），這題處理的是**區間** —— 而區間可以互相包含，這讓判斷斷點的方式完全不同。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS campaigns;

CREATE TABLE campaigns (
    id        INT PRIMARY KEY,
    product   VARCHAR(10) NOT NULL,
    starts_on DATE NOT NULL,
    ends_on   DATE NOT NULL           -- 閉區間：ends_on 當天仍在投放
);

INSERT INTO campaigns (id, product, starts_on, ends_on) VALUES
-- P1：兩檔重疊 + 一檔分開
(1, 'P1', '2026-01-01', '2026-01-10'),
(2, 'P1', '2026-01-05', '2026-01-15'),
(3, 'P1', '2026-01-20', '2026-01-25'),
-- P2：兩檔剛好相接 + 一檔分開
(4, 'P2', '2026-02-01', '2026-02-05'),
(5, 'P2', '2026-02-05', '2026-02-10'),
(6, 'P2', '2026-02-20', '2026-02-22'),
-- P3：一檔長的包住兩檔短的  ← 這組是這題的殺著
(7, 'P3', '2026-03-01', '2026-03-31'),
(8, 'P3', '2026-03-10', '2026-03-15'),
(9, 'P3', '2026-03-20', '2026-03-25');
```

<br>

### 正確答案（合併後）

```
 product |   from_d   |    to_d    | merged
---------+------------+------------+--------
 P1      | 2026-01-01 | 2026-01-15 |      2
 P1      | 2026-01-20 | 2026-01-25 |      1
 P2      | 2026-02-01 | 2026-02-10 |      2
 P2      | 2026-02-20 | 2026-02-22 |      1
 P3      | 2026-03-01 | 2026-03-31 |      3     ← 三檔合成一段
```

### 總投放天數

```
 product | 正確 | 直接相加（高估）
---------+------+-----------------
 P1      |   21 |              27
 P2      |   13 |              14
 P3      |   31 |              43
```

<br>

---

<br>

## Part A — 天真的做法

### A1

先寫出「直接把每檔天數加起來」的查詢，得到 27 / 14 / 43。

`ends_on - starts_on + 1` 是天數（閉區間要 +1）。

### A2

為什麼 P3 高估最多（43 vs 31）？用資料解釋。

<br>

---

<br>

## Part B — 用 `LAG` 合併（會出錯）

### B1

依照 [3-03](../03-gaps-and-islands-i-login-streak) 的直覺，你可能會這樣寫：

```sql
WITH flagged AS (
    SELECT *,
           CASE WHEN starts_on > LAG(ends_on) OVER (PARTITION BY product ORDER BY starts_on, ends_on)
                THEN 1 ELSE 0 END AS is_new_island
    FROM campaigns
),
grouped AS (
    SELECT *, SUM(is_new_island) OVER (PARTITION BY product ORDER BY starts_on, ends_on) AS grp
    FROM flagged
)
SELECT product, MIN(starts_on) AS from_d, MAX(ends_on) AS to_d, COUNT(*) AS merged
FROM grouped GROUP BY product, grp ORDER BY 1, 2;
```

跑出來：

```
 product |   from_d   |    to_d    | merged
---------+------------+------------+--------
 P1      | 2026-01-01 | 2026-01-15 |      2     ← 對
 P1      | 2026-01-20 | 2026-01-25 |      1     ← 對
 P2      | 2026-02-01 | 2026-02-10 |      2     ← 對
 P2      | 2026-02-20 | 2026-02-22 |      1     ← 對
 P3      | 2026-03-01 | 2026-03-31 |      2     ← 錯
 P3      | 2026-03-20 | 2026-03-25 |      1     ← 錯
```

**P1 和 P2 全對，只有 P3 錯。**

### B2 — 看出荒謬之處

盯著 P3 的兩行看：

```
 P3      | 2026-03-01 | 2026-03-31 |
 P3      | 2026-03-20 | 2026-03-25 |
```

第二段 **完全被第一段包住**。

- 「合併後的區間」應該是互斥的。這個輸出在邏輯上根本不可能成立。
- **這就是自我檢查的價值**：你不需要知道正確答案，光看輸出就知道錯了。寫一個 SQL 稽核查詢，自動偵測「合併結果彼此重疊」的情況。（提示：這正是 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 的查詢）

### B3 — 診斷

把 P3 依 `starts_on` 排序，逐行列出 `LAG(ends_on)`：

| id | starts_on | ends_on | LAG(ends_on) | starts_on > LAG? |
|----|-----------|---------|--------------|------------------|
| 7 | 03-01 | 03-31 | ? | ? |
| 8 | 03-10 | 03-15 | ? | ? |
| 9 | 03-20 | 03-25 | ? | ? |

回答：
- 第 3 行（id=9）的 `LAG(ends_on)` 是多少？
- 它被拿來和 `03-20` 比較，判定為「新島」。**為什麼這個判斷是錯的？**
- **`LAG` 只看到前一行，但正確的判斷需要看到什麼？**

<br>

---

<br>

## Part C — Running MAX（正解）

### C1

把 `LAG(ends_on)` 換成「**前面所有行的 `ends_on` 最大值**」。

寫出這個 window 運算式（提示：frame 要排除當前行）。

### C2

寫出完整的正確查詢，驗證 P3 合併成一段。

### C3 — 逐行驗證

對 P3 列出 `prev_max_end` 和判斷結果，證明它為什麼對：

| id | starts_on | ends_on | prev_max_end | 新島？ |
|----|-----------|---------|--------------|--------|
| 7 | 03-01 | 03-31 | ? | ? |
| 8 | 03-10 | 03-15 | ? | ? |
| 9 | 03-20 | 03-25 | ? | ? |

### C4 — 總投放天數

用合併結果算出正確的總天數（21 / 13 / 31）。

<br>

---

<br>

## Part D — 邊界

### D1 — 相接算不算重疊

P2 的兩檔是 `[02-01, 02-05]` 和 `[02-05, 02-10]` —— **02-05 這天兩檔都在跑**。

以閉區間來說它們是重疊的（共用 02-05），所以合併成 `[02-01, 02-10]` = 10 天。

現在假設資料改成 `[02-01, 02-05]` 和 `[02-06, 02-10]` —— **相接但不重疊**。

- 你的查詢會合併它們嗎？
- 行銷部門想要合併嗎？（連續投放 10 天，中間沒斷）
- 怎麼改判斷條件讓「相接」也算同一島？

### D2 — 半開區間

如果 schema 改用**半開區間** `[starts_on, ends_on)`（`ends_on` 當天**不**投放），你的判斷條件要怎麼改？

天數計算要怎麼改？

> 回去對照 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 的半開區間討論。**同一個語意問題，在不同題目反覆出現。**

### D3 — 排序的必要性

`ORDER BY starts_on, ends_on` 裡的 `ends_on` 是必要的嗎？

拿掉它，看看有沒有影響。然後回答：**什麼樣的資料會讓「少一個 tie-breaker」變成 bug？**

<br>

---

<br>

## 面試官的追問

> 1. 「這個查詢的時間複雜度是什麼？和 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 的自連接偵測法比呢？」
>
> 2. 「如果要算『**同時**有幾檔在跑』隨時間的變化曲線（不是合併，是計數），怎麼寫？」
>    （提示：把每個區間拆成 `+1` 和 `-1` 兩個事件，然後累加 —— 這叫 sweep line）
>
> 3. 「PostgreSQL 有 `daterange` 型別和 `range_agg` 聚合函數。用它們寫一版，和你的手寫版比較。」
>
> 4. 「這題如果只有 `LAG` 可用（例如 MySQL 5.7 沒有 window function），你會怎麼做？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — LAG 為什麼不夠</summary>

P3 依 `starts_on` 排序：

| id | starts_on | ends_on | LAG(ends_on) | starts_on > LAG? |
|----|-----------|---------|--------------|------------------|
| 7 | 03-01 | 03-31 | NULL | (第一行) |
| 8 | 03-10 | 03-15 | **03-31** | 03-10 > 03-31 → 否 ✓ |
| 9 | 03-20 | 03-25 | **03-15** | 03-20 > 03-15 → **是** ✗ |

第 3 行的 `LAG` 只看到**前一行**（id=8，結束於 03-15），完全不知道 id=7 一路投放到 03-31。

**`LAG` 有記憶失憶症** —— 它只記得上一行，忘了更早的行。

而區間問題必須知道「**到目前為止，覆蓋範圍最遠到哪裡**」，也就是所有前行 `ends_on` 的**最大值**。

在 [3-03](../03-gaps-and-islands-i-login-streak) 用 `LAG`（或序號差）可以，是因為那題的資料是**點**，而且已經排序 —— 前一個點就是最近的點。**區間不一樣：後面的區間可能比前面的短很多，被完全包住。**

</details>

<details>
<summary>Hint 2 — Running MAX 的寫法</summary>

```sql
MAX(ends_on) OVER (
    PARTITION BY product
    ORDER BY starts_on, ends_on
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING    -- ← 排除當前行
) AS prev_max_end
```

`ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING` = 「從分區開頭到**前一行**」，不含自己。

**為什麼要排除當前行？** 因為要判斷「我的起點有沒有超出前面所有人的覆蓋範圍」。把自己算進去的話，`prev_max_end` 至少會是自己的 `ends_on`，判斷就永遠是「否」。

**這裡必須用 `ROWS` 不能用 `RANGE`** —— 想想 [3-02](../02-rows-vs-range-vs-groups) 學的：如果兩檔的 `starts_on` 相同（peer），`RANGE` 會把它們一起算進 frame，破壞「排除當前行」的意圖。

</details>

<details>
<summary>Hint 3 — 完整骨架</summary>

```sql
WITH flagged AS (
    SELECT *,
           MAX(ends_on) OVER (PARTITION BY product ORDER BY starts_on, ends_on
                              ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS prev_max_end
    FROM campaigns
),
marked AS (
    SELECT *,
           CASE WHEN prev_max_end IS NULL OR starts_on > prev_max_end
                THEN 1 ELSE 0 END AS is_new_island
    FROM flagged
),
grouped AS (
    SELECT *, SUM(is_new_island) OVER (PARTITION BY product ORDER BY starts_on, ends_on) AS grp
    FROM marked
)
SELECT product, MIN(starts_on) AS from_d, MAX(ends_on) AS to_d, COUNT(*) AS merged
FROM grouped
GROUP BY product, grp
ORDER BY product, from_d;
```

**四層，每層一件事**：算覆蓋範圍 → 標斷點 → 累加成島 ID → 彙總。

`prev_max_end IS NULL` 處理每個分區的第一行（沒有前行）—— 別忘了，不然第一行的 flag 是 NULL，`SUM` 會出問題。

</details>

<details>
<summary>Hint 4 — 「相接也算同島」</summary>

目前的條件：

```sql
starts_on > prev_max_end                       -- 03-06 > 03-05 → 新島
```

改成：

```sql
starts_on > prev_max_end + INTERVAL '1 day'    -- 03-06 > 03-06 → 否，同島
```

**這是商業定義問題，不是技術問題。** 面試時要主動問：「相接的兩檔，行銷部門視為連續投放還是兩次投放？」

問了就是加分。直接假設就是賭 —— 而且賭錯了整個數字都是錯的。

</details>
