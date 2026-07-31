# Phase 5-01 — The Retention Matrix

> **難度**：★★★★★
> **核心技巧**：Cohort 分群、Day-N 留存、**分母與「第 N 天」的定義**
> **對應基礎題**：[LC 550. Game Play Analysis IV](../../../sql_training/game_play_analysis_iv)（你當初只算了「隔天回來」）

<br>

---

<br>

## Interview Context

> *面試官：*「算一下我們產品的 7 日留存率。」

<br>

**這一題最重要的動作是：先不要寫 SQL。**

「7 日留存率」這句話至少有兩種合理解讀，而它們在同一份資料上會給出 **50%** 和 **75%** —— 差 25 個百分點，足以決定一個功能該不該砍。

你在基礎訓練寫的 [LC 550](../../../sql_training/game_play_analysis_iv) 算的是「第 1 天回來」，題目把定義寫死了。**真實面試不會。**

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS activity;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id          INT PRIMARY KEY,
    signup_date DATE NOT NULL
);

CREATE TABLE activity (
    user_id     INT NOT NULL,
    active_date DATE NOT NULL,
    PRIMARY KEY (user_id, active_date)
);

INSERT INTO users (id, signup_date) VALUES
(1, '2026-03-01'), (2, '2026-03-01'), (3, '2026-03-01'), (4, '2026-03-01'),
(5, '2026-03-02'), (6, '2026-03-02');

INSERT INTO activity (user_id, active_date) VALUES
-- user 1：第 0、1、7、30 天都活躍
(1, '2026-03-01'), (1, '2026-03-02'), (1, '2026-03-08'), (1, '2026-03-31'),
-- user 2：第 0~3 天連續活躍，之後消失
(2, '2026-03-01'), (2, '2026-03-02'), (2, '2026-03-03'), (2, '2026-03-04'),
-- user 3：第 0 天，然後「正好第 7 天」才回來
(3, '2026-03-01'), (3, '2026-03-08'),
-- user 4：只有註冊當天
(4, '2026-03-01'),
-- user 5、6：03-02 的 cohort
(5, '2026-03-02'), (5, '2026-03-03'),
(6, '2026-03-02');
```

<br>

---

<br>

## Part A — 先問問題

### A1 — 三個必問

**在寫任何 SQL 之前**，寫出你會問面試官的三個問題。

提示方向（但用你自己的話，而且要用**具體情境**問，不要用抽象規則問）：

1. 分母是誰？
2. 「第 7 天留存」的「第 7 天」怎麼算？
3. 「活躍」的定義是什麼？時區怎麼處理？

### A2 — 為什麼問題比答案重要

回答：如果你不問就直接寫，寫錯的機率有多高？如果面試官說「你自己假設」，你該怎麼回應？

<br>

---

<br>

## Part B — 兩種定義，兩個答案

### B1 — 定義一：**恰好第 N 天**

「第 N 天留存」= 在 `signup_date + N` **那一天**有活躍。

寫出留存矩陣：

```
   cohort   | cohort_size | d1 | d7 | d30 | d1_pct | d7_pct
------------+-------------+----+----+-----+--------+--------
 2026-03-01 |           4 |  2 |  2 |   1 |   50.0 |   50.0
 2026-03-02 |           2 |  1 |  0 |   0 |   50.0 |    0.0
```

### B2 — 定義二：**第 1 到第 N 天內任一天**

「7 日留存」= 註冊後 7 天內**至少回來過一次**。

```
   cohort   | cohort_size | w1 | w7 | w7_pct
------------+-------------+----+----+--------
 2026-03-01 |           4 |  2 |  3 |   75.0
 2026-03-02 |           2 |  1 |  1 |   50.0
```

### B3 — 差在誰身上

`2026-03-01` 這個 cohort：定義一是 **50%**，定義二是 **75%**。

- 差的那一個人是誰？
- 他的行為是什麼？
- **哪一種定義比較能反映「這個產品留得住人」？**
- 業界（GA、Amplitude、Mixpanel）通常用哪一種？兩種各叫什麼名字？

### B4 — 兩種都給

寫一個查詢**同時輸出兩種定義**，讓 PM 自己挑。

> 這是 [Phase 3-05](../../phase-3-window-deep-water/05-sessionization-30-minute-rule) Part B2 用過的策略：
> **需求模糊時，最好的回答不是猜一個，是把兩種都算出來。**

<br>

---

<br>

## Part C — 分母的陷阱

### C1 — cohort 大小從哪來

`cohort_size` 是「那天註冊的人數」。

回答：
- 如果改用「那天**活躍**的人數」當分母，數字會怎麼變？這樣算的是什麼指標？
- user 4 註冊當天有活躍紀錄，user 6 也有。**如果有人註冊了但註冊當天完全沒有活躍紀錄**，他該進分母嗎？
- 分母應該來自 `users` 表還是 `activity` 表？**為什麼這個選擇很重要？**

### C2 — 未成熟的 cohort

今天是 `2026-03-10`。

- `2026-03-02` 這個 cohort 的「30 日留存」該顯示多少？**0% 對嗎？**
- 這種「時間還沒到」的格子，報表上該怎麼呈現？
- 寫出正確處理：資料不足的格子顯示 `NULL` 而不是 `0%`。

> **這是留存矩陣最常見的錯誤。** 新 cohort 的長期留存一律顯示 0%，
> 讓整張圖看起來像是「產品最近變差了」—— 其實只是時間還沒到。

### C3 — 完整矩陣

輸出標準的三角形留存矩陣（D0/D1/D3/D7/D14/D30），並正確處理未成熟格子。

<br>

---

<br>

## Part D — 規模

### D1

`activity` 有 500 億行（每個使用者每天一行）。

- 你的查詢會怎樣？
- `JOIN users ON ...` 加上日期運算，索引用得上嗎？
- 你會怎麼設計？（提示：預先算好 `day_n` 存起來？）

### D2

留存矩陣通常是**每天重算**還是**增量更新**？

- 昨天的 cohort 今天的 D1 才確定 —— 這代表歷史資料會不斷被修改嗎？
- 這對報表系統的設計有什麼影響？

<br>

---

<br>

## 面試官的追問

> 1. 「什麼是 rolling retention？和 classic retention 差在哪？」
>
> 2. 「如果一個使用者刪除帳號又重新註冊，他算一個人還是兩個人？你的查詢怎麼處理？」
>
> 3. 「留存率一直在跌，但活躍用戶數一直在漲。這可能嗎？怎麼解釋？」
>
> 4. 「怎麼判斷一個 cohort 的留存曲線『打平』了？為什麼這個點很重要？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 該怎麼問</summary>

**不要問**：「留存的定義是什麼？」（太空泛，對方會說「就是留存啊」）

**要問**（用具體使用者的行為當例子）：

> 「假設有個使用者 3/1 註冊，之後 3/2、3/3、3/4 都有回來，但 3/8 沒有。
>
> 在『7 日留存』這個指標裡，他算留存還是流失？」

對方一定答得出來，而且答案直接決定你寫哪一版 SQL。

**第二個問題**：
> 「分母我打算用『當天註冊的總人數』。但有些人註冊完就再也沒開過 App —— 他們要算進分母嗎？」

**第三個問題**：
> 「跨日的界線用哪個時區？使用者本地時間還是 UTC？」
> （這個問題會讓面試官知道你做過真實的資料工作）

</details>

<details>
<summary>Hint 2 — 骨架</summary>

```sql
WITH cohorts AS (
    SELECT signup_date AS cohort, COUNT(*) AS cohort_size
    FROM users GROUP BY signup_date
),
day_n AS (
    SELECT u.signup_date AS cohort,
           a.user_id,
           (a.active_date - u.signup_date) AS dn        -- ← date - date = integer
    FROM activity a
    JOIN users u ON u.id = a.user_id
)
SELECT c.cohort, c.cohort_size,
       COUNT(DISTINCT d.user_id) FILTER (WHERE d.dn = 1) AS d1,
       COUNT(DISTINCT d.user_id) FILTER (WHERE d.dn = 7) AS d7,
       ROUND(100.0 * COUNT(DISTINCT d.user_id) FILTER (WHERE d.dn = 7) / c.cohort_size, 1) AS d7_pct
FROM cohorts c
LEFT JOIN day_n d ON d.cohort = c.cohort              -- ← LEFT JOIN，別讓空 cohort 消失
GROUP BY c.cohort, c.cohort_size
ORDER BY c.cohort;
```

`FILTER` 是 [Phase 2-02](../../phase-2-aggregation-limits/02-filter-vs-case-when) 學的 —— 一次掃描產出所有 Day-N 欄位。

`COUNT(DISTINCT ...)` 不能省：一個使用者一天可能有多筆活躍紀錄。

定義二只要把 `d.dn = 7` 換成 `d.dn BETWEEN 1 AND 7`。**一個字的差別，25 個百分點。**

</details>

<details>
<summary>Hint 3 — 差的那個人</summary>

**user 2**。

他在第 1、2、3 天都活躍，但第 7 天（03-08）沒有。

- 定義一（恰好第 7 天）→ **不算留存**
- 定義二（7 天內回來過）→ **算留存**

業界術語：
- 定義一叫 **Classic / Day-N Retention**（Amplitude、Mixpanel 預設）
- 定義二叫 **Range / Bracket Retention**（GA 偏好）
- 還有第三種 **Rolling Retention**：「第 N 天**或之後**還有回來」—— 用來看長期黏著度

**三種都是業界標準，沒有哪個「對」。** 重點是報表上要標清楚用的是哪一種。

</details>

<details>
<summary>Hint 4 — 未成熟 cohort</summary>

```sql
CASE WHEN c.cohort + 30 <= CURRENT_DATE
     THEN ROUND(100.0 * COUNT(DISTINCT d.user_id) FILTER (WHERE d.dn = 30) / c.cohort_size, 1)
     ELSE NULL                                      -- ← 時間還沒到，不是 0%
END AS d30_pct
```

判斷條件：**這個 cohort 的第 30 天是否已經過去了？**

沒過去 → `NULL`（報表上顯示空白或「—」），不是 `0`。

**為什麼這件事重要**：留存矩陣通常是三角形的，右下角一定是空的。如果你用 0 填滿，整張圖會變成一個假的「留存崩塌」趨勢，而 PM 會據此做決策。

</details>
