# Phase 3-05 — Sessionization：The 30-Minute Rule

> **難度**：★★★★★
> **核心技巧**：`LAG` 算間隔 → 標記斷點 → `SUM() OVER` 累加成 session ID
> **對應基礎題**：[LC 1141. User Activity for the Past 30 Days I](../../../sql_training/user_activity_for_the_past_30_days_i)（你當初的日期範圍計數）

<br>

---

<br>

## Interview Context

> *面試官：*「我們的事件表只記了 `user_id`、`event_at`、`page`。產品經理要看：
>
> - 每天有幾個 session
> - 平均每個 session 幾分鐘、看幾頁
> - 跳出率（只看一頁就走的 session 佔比）
>
> 但我們沒有 session 這個欄位。**你得自己從時間戳算出來。**
>
> 業界慣例是：同一個使用者，兩個事件間隔超過 30 分鐘就算新的 session。」

<br>

**Sessionization 是資料工程面試的必考題。** Google Analytics、Mixpanel、Amplitude 全都在做這件事。而它的骨架和 [3-03](../03-gaps-and-islands-i-login-streak)、[3-04](../04-gaps-and-islands-ii-merge-intervals) 是同一個：**標斷點 → 累加成組 ID**。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS events;

CREATE TABLE events (
    id       SERIAL PRIMARY KEY,
    user_id  INT NOT NULL,
    event_at TIMESTAMP NOT NULL,
    page     VARCHAR(30) NOT NULL
);

INSERT INTO events (user_id, event_at, page) VALUES
-- user 1：三個 session
(1, '2026-03-01 09:00', '/home'),
(1, '2026-03-01 09:05', '/search'),
(1, '2026-03-01 09:20', '/item'),
(1, '2026-03-01 10:30', '/home'),      -- 距上次 70 分鐘 → 新 session
(1, '2026-03-01 10:45', '/cart'),
(1, '2026-03-01 11:00', '/checkout'),
(1, '2026-03-01 14:00', '/home'),      -- 距上次 180 分鐘 → 新 session
-- user 2：間隔「正好 30 分鐘」  ← 邊界
(2, '2026-03-01 09:00', '/home'),
(2, '2026-03-01 09:30', '/search'),
-- user 3：間隔 31 分鐘  ← 邊界的另一側
(3, '2026-03-01 08:00', '/home'),
(3, '2026-03-01 08:31', '/search'),
-- user 4：只有一個事件
(4, '2026-03-01 12:00', '/home');
```

<br>

### 正確答案（規則：間隔 **> 30** 分鐘才算新 session）

```
 user_id | session_no |       started       |        ended        | events | dur_min
---------+------------+---------------------+---------------------+--------+---------
       1 |          1 | 2026-03-01 09:00:00 | 2026-03-01 09:20:00 |      3 |      20
       1 |          2 | 2026-03-01 10:30:00 | 2026-03-01 11:00:00 |      3 |      30
       1 |          3 | 2026-03-01 14:00:00 | 2026-03-01 14:00:00 |      1 |       0
       2 |          1 | 2026-03-01 09:00:00 | 2026-03-01 09:30:00 |      2 |      30
       3 |          1 | 2026-03-01 08:00:00 | 2026-03-01 08:00:00 |      1 |       0
       3 |          2 | 2026-03-01 08:31:00 | 2026-03-01 08:31:00 |      1 |       0
       4 |          1 | 2026-03-01 12:00:00 | 2026-03-01 12:00:00 |      1 |       0
```

<br>

> **user 2 和 user 3 是刻意設計的對照組**：一個間隔正好 30 分（同 session），一個 31 分（新 session）。
> 這兩行決定了你的條件該寫 `>` 還是 `>=` —— 而這**不是技術問題**，是產品定義問題。

<br>

---

<br>

## Part A — 建立 session

### A1 — 三步驟

Sessionization 的骨架永遠是這三步。先用文字寫出每一步做什麼，再寫 SQL：

1. **算間隔**：用 `LAG` 取得前一個事件的時間，算出間隔分鐘數
2. **標斷點**：間隔 > 30 分鐘 → 標 1，否則標 0
3. **累加**：`SUM(斷點) OVER (...)` 變成 session 編號

### A2 — 第一個事件

每個使用者的**第一個事件**，`LAG` 回傳 NULL。

- `NULL > 30` 求值是什麼？（回想 [Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results)）
- 如果不特別處理，第一個事件會被標成 0 還是 1？
- 這會導致 session 編號從幾開始？**user 4（只有一個事件）會拿到 session_no 幾？**
- 寫出正確的處理方式。

### A3 — 寫出來

輸出上面那張表。欄位：`user_id`、`session_no`、`started`、`ended`、`events`、`dur_min`。

**注意 `SUM() OVER` 也要 `PARTITION BY user_id`** —— 漏掉的話 session 編號會跨使用者累加下去。自己測一次漏掉會怎樣。

<br>

---

<br>

## Part B — 邊界

### B1 — `>` 還是 `>=`

user 2 的兩個事件間隔**正好 30 分鐘**。

- 用 `> 30`：算一個 session 還是兩個？
- 用 `>= 30`：呢？
- **哪一個才對？** 你要怎麼問產品經理才能問到答案？

寫出你會問的**具體問題**（不是「請問要用大於還是大於等於」，那是把問題丟回去）。

### B2 — 兩種都實作

寫一個查詢，同時輸出 `> 30` 和 `>= 30` 兩種規則下的 session 數，讓 PM 自己選。

```
 user_id | sessions_gt30 | sessions_gte30
---------+---------------+----------------
       1 |             3 |              3
       2 |             1 |              2
       3 |             2 |              2
       4 |             1 |              1
```

> **這就是 Phase 8 的預演**：面對定義模糊的需求，最好的回答不是猜一個，是**把兩種都算出來讓對方選**。

### B3 — 跨午夜

user 1 如果在 `2026-03-01 23:50` 和 `2026-03-02 00:05` 各有一個事件（間隔 15 分鐘）：

- 依 30 分鐘規則，這是一個 session 還是兩個？
- 但「每天有幾個 session」這個指標要怎麼算？這個 session 算 3/1 還是 3/2？
- **業界標準怎麼處理？**（提示：Google Analytics 的 session 會在午夜強制中斷）
- 如果要實作「午夜強制中斷」，你的斷點條件要加什麼？

<br>

---

<br>

## Part C — PM 要的指標

### C1

用你的 session 表算出：

- 總 session 數
- 平均 session 時長（分鐘）
- 平均每 session 頁數
- **跳出率**：只有 1 個事件的 session 佔比

### C2 — 跳出率的陷阱

用 [Phase 2-02](../../phase-2-aggregation-limits/02-filter-vs-case-when) 學的 `FILTER` 寫跳出率。

然後回答：
- 「只看一頁就走」的 session，時長是 0 分鐘。這些 session 該進「平均時長」的分母嗎？
- 如果不該，平均時長會從多少變成多少？
- **這兩個數字都叫「平均 session 時長」，你會在報表上放哪一個？怎麼標註？**

### C3 — 每個 session 的入口與出口頁

用 [3-01](../01-the-last-value-that-lied) 學的東西，加上每個 session 的**第一頁**（landing page）和**最後一頁**（exit page）。

> ⚠️ 這裡就是 `LAST_VALUE` 陷阱會咬你的地方。小心。

<br>

---

<br>

## 面試官的追問

> 1. 「這個查詢每天要對 100 億行事件跑一次。你會怎麼設計？」
>    （提示：增量處理 —— 但跨批次的 session 邊界怎麼辦？）
>
> 2. 「如果事件是**亂序到達**的（行動端離線後補傳），你的查詢還對嗎？」
>
> 3. 「同一個使用者同時開了兩個瀏覽器分頁，事件交錯進來。你的 session 切割會發生什麼事？怎麼修？」
>
> 4. 「30 分鐘這個數字是怎麼來的？如果要用資料決定最佳閾值，你會怎麼做？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 三步驟骨架</summary>

```sql
WITH gapped AS (
    SELECT *,
           EXTRACT(EPOCH FROM (event_at - LAG(event_at) OVER (PARTITION BY user_id ORDER BY event_at))) / 60
             AS gap_min
    FROM events
),
flagged AS (
    SELECT *,
           CASE WHEN gap_min IS NULL OR gap_min > 30 THEN 1 ELSE 0 END AS is_new_session
    FROM gapped
),
sessioned AS (
    SELECT *,
           SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY event_at) AS session_no
    FROM flagged
)
SELECT user_id, session_no,
       MIN(event_at) AS started, MAX(event_at) AS ended,
       COUNT(*) AS events,
       EXTRACT(EPOCH FROM (MAX(event_at) - MIN(event_at))) / 60 AS dur_min
FROM sessioned
GROUP BY user_id, session_no
ORDER BY user_id, session_no;
```

**注意兩個 `PARTITION BY user_id`** —— `LAG` 要一個，`SUM` 也要一個。漏掉任何一個都會讓 session 跨使用者黏在一起。

</details>

<details>
<summary>Hint 2 — 第一個事件必須標 1</summary>

`LAG` 對每個分區的第一行回傳 **NULL**，所以 `gap_min` 是 NULL。

`NULL > 30` → **UNKNOWN** → `CASE WHEN` 走 `ELSE` → 標 0。

如果不處理，第一個事件標 0，`SUM` 從 0 開始 → **session_no 從 0 開始**，而且 user 4（唯一一個事件）會拿到 `session_no = 0`。

不只是難看 —— 如果第一個事件標 0 而第二個事件標 1，那第一個事件會被歸到 session 0、第二個歸到 session 1，看起來還算對。但語意上「第一個事件開啟了一個新 session」才是正確的模型。

所以要寫 `gap_min IS NULL OR gap_min > 30`。

**這是 [Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results) 的三值邏輯第三次出現了。**

</details>

<details>
<summary>Hint 3 — 該問 PM 什麼</summary>

不要問：「30 分鐘的邊界要用 `>` 還是 `>=`？」（技術語言，PM 聽不懂）

要問：**「使用者在 9:00 看了一頁，9:30 整又看了一頁 —— 中間隔了整整 30 分鐘。這算他還在同一次瀏覽，還是他離開後又回來了？」**

用**具體情境**問，不要用抽象規則問。這是需求釐清的基本功，Phase 8 會大量練習。

補充：業界慣例（GA4）是 **間隔 > 30 分鐘** 才開新 session，也就是正好 30 分鐘仍算同一個。但慣例不等於你們產品的需求 —— 還是要問。

</details>

<details>
<summary>Hint 4 — 午夜強制中斷</summary>

```sql
CASE WHEN gap_min IS NULL
       OR gap_min > 30
       OR event_at::date <> LAG(event_at) OVER (PARTITION BY user_id ORDER BY event_at)::date
     THEN 1 ELSE 0 END
```

多一個條件：**日期換了就強制開新 session**。

這樣「每天有幾個 session」才好算 —— 每個 session 保證只屬於一天。

代價：跨午夜的真實瀏覽行為被硬切成兩段，時長被低估。**這是刻意的取捨**，面試時要講出來。

</details>
