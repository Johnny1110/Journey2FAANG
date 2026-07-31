# Phase 5-02 — Funnel Analysis With Order Constraint

> **難度**：★★★★★
> **核心技巧**：事件**順序**約束、逐步收斂的漏斗、`MIN(event_at)` 遞進
> **對應基礎題**：[LC 1141. User Activity for the Past 30 Days I](../../../sql_training/user_activity_for_the_past_30_days_i)（你當初只數了 `COUNT DISTINCT`）

<br>

---

<br>

## Interview Context

> *面試官：*「電商漏斗：瀏覽 → 加購物車 → 結帳 → 付款。給我每一步的人數和轉換率。
>
> 這是我們現在儀表板上的數字：
>
> ```
>  view: 6 → add_to_cart: 4 → checkout: 3 → purchase: 3
> ```
>
> 產品經理很開心，說**結帳到付款的轉換率是 100%**。
>
> 你覺得呢？」

<br>

**「100% 轉換率」是一個荒謬到應該立刻警鈴大作的數字。** 這一題訓練的就是這種嗅覺。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS events;

CREATE TABLE events (
    id         SERIAL PRIMARY KEY,
    user_id    INT NOT NULL,
    event_type VARCHAR(20) NOT NULL,
    event_at   TIMESTAMP NOT NULL
);

INSERT INTO events (user_id, event_type, event_at) VALUES
-- user 1：完整走完，順序正確
(1,'view','2026-03-01 09:00'),(1,'add_to_cart','2026-03-01 09:05'),
(1,'checkout','2026-03-01 09:10'),(1,'purchase','2026-03-01 09:15'),
-- user 2：走到結帳就跑了
(2,'view','2026-03-01 10:00'),(2,'add_to_cart','2026-03-01 10:05'),
(2,'checkout','2026-03-01 10:10'),
-- user 3：瀏覽後「直接付款」，沒有加購物車也沒有結帳  ← 資料異常
(3,'view','2026-03-01 11:00'),(3,'purchase','2026-03-01 11:05'),
-- user 4：先加購物車才瀏覽（順序顛倒）  ← 資料異常
(4,'add_to_cart','2026-03-01 12:00'),(4,'view','2026-03-01 12:30'),
-- user 5：兩段 session，第一段放棄，第二段完整走完
(5,'view','2026-03-02 09:00'),(5,'add_to_cart','2026-03-02 09:02'),
(5,'view','2026-03-02 14:00'),(5,'add_to_cart','2026-03-02 14:05'),
(5,'checkout','2026-03-02 14:10'),(5,'purchase','2026-03-02 14:20'),
-- user 6：只瀏覽
(6,'view','2026-03-03 09:00');
```

<br>

### 兩種算法

```
        步驟      | 天真版 | 有順序約束
------------------+--------+------------
 1 view           |      6 |          6
 2 add_to_cart    |      4 |          3
 3 checkout       |      3 |          3
 4 purchase       |      3 |          2
```

<br>

---

<br>

## Part A — 天真版與它的荒謬之處

### A1

寫出天真版：對每個 `event_type` 數 `COUNT(DISTINCT user_id)`。

確認你得到 6 / 4 / 3 / 3。

### A2 — 為什麼 100% 是不可能的

`checkout = 3`、`purchase = 3` → 轉換率 100%。

回答：
- 這在商業上可能嗎？
- 更根本的問題：**天真版算出來的「purchase 人數」和「checkout 人數」，是同一批人嗎？**
- 把每個步驟的**使用者名單**列出來，證明它們不是同一批人。

### A3 — 逐一檢視

寫一個查詢，輸出每個使用者的完整事件序列：

```
 user_id | journey
---------+------------------------------------------------------------------
       1 | view -> add_to_cart -> checkout -> purchase
       2 | view -> add_to_cart -> checkout
       3 | view -> purchase
       4 | add_to_cart -> view
       5 | view -> add_to_cart -> view -> add_to_cart -> checkout -> purchase
       6 | view
```

然後對每個使用者判斷：**天真版把他算進哪幾步？順序約束版呢？**

| user | 天真版計入 | 順序版計入 | 差異原因 |
|------|-----------|-----------|---------|
| 1 | ? | ? | ? |
| 2 | ? | ? | ? |
| 3 | ? | ? | ? |
| 4 | ? | ? | ? |
| 5 | ? | ? | ? |
| 6 | ? | ? | ? |

<br>

---

<br>

## Part B — 加上順序約束

### B1

漏斗的正確語意：**每一步必須發生在前一步之後**。

寫出有順序約束的版本，得到 6 / 3 / 3 / 2。

核心思路：逐步收斂 —— 每一層只保留「在前一層時間點之後」還有下一個事件的使用者。

### B2 — 驗證兩個異常使用者

- **user 3**（view → purchase）：天真版算他 purchase，順序版**不算**。為什麼？這樣對嗎？
- **user 4**（add_to_cart → view）：天真版算他 add_to_cart，順序版**不算**。為什麼？

回答：
- 這兩筆是「資料錯誤」還是「真實但異常的使用者行為」？
- user 3 的情況在真實系統可能怎麼發生？（提示：一鍵購買、追蹤事件漏送、深層連結）
- **如果 user 3 是真實行為，把他從漏斗剔除對嗎？**

### B3 — user 5 的兩段 session

user 5 第一段 `view → add_to_cart` 就放棄了，第二段才走完。

- 你的查詢用 `MIN(event_at)` 取每一步的第一次。這對 user 5 產生什麼結果？
- **他的第一次 `add_to_cart`（09:02）配上第二次的 `checkout`（14:10）** —— 這樣算「同一次轉換」嗎？
- 如果要求「必須在**同一個 session** 內完成」，怎麼改？
  （提示：先用 [Phase 3-05](../../phase-3-window-deep-water/05-sessionization-30-minute-rule) 的方法切 session，再對每個 session 跑漏斗）

### B4 — 轉換率

在漏斗上加兩欄：

- **步驟轉換率**（相對前一步）
- **總轉換率**（相對第一步）

兩種算法的數字都要，並回答：**PM 看哪一個？分析師看哪一個？**

<br>

---

<br>

## Part C — 進階

### C1 — 時間窗限制

真實漏斗通常有時間限制：「**7 天內**完成付款才算轉換」。

加上這個約束。user 5 的兩段 session 跨了一天多，還算嗎？

### C2 — 流失點分析

PM 問：「**使用者主要卡在哪一步？**」

輸出每一步的流失人數與流失率，並找出最大的流失點。

### C3 — 一次掃描

B1 的寫法用了 4 層 CTE，每層都掃一次 `events`。

用 window function 改寫成**一次掃描**的版本。

（提示：對每個使用者，用 `MIN(event_at) FILTER (WHERE event_type = ...)` 一次取出四個時間點，然後比較大小）

跑 `EXPLAIN` 對比兩種寫法。

### C4 — 這個寫法的破綻

C3 的一次掃描版本，對 **user 5** 會算出什麼？和 B1 一樣嗎？

如果不一樣，**哪一個是對的？**

> 提示：`MIN(...) FILTER` 取的是「全域第一次」，B1 的逐層收斂取的是「前一步之後的第一次」。
> 對 user 5 這種「放棄後重來」的使用者，兩者可能不同。**想清楚你的漏斗要表達什麼。**

<br>

---

<br>

## 面試官的追問

> 1. 「如果漏斗有 10 步，你的 CTE 要寫 10 層嗎？有沒有更通用的寫法？」
>
> 2. 「這個查詢每天要跑在 1000 億筆事件上。你會怎麼設計？」
>
> 3. 「怎麼做 A/B 測試的漏斗比較？兩組的漏斗數字要怎麼比才公平？」
>
> 4. 「如果使用者可以從第 3 步跳回第 2 步（改購物車內容），你的漏斗會怎麼算？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼天真版的 100% 是假的</summary>

天真版每一步的使用者名單：

- `view`：{1, 2, 3, 4, 5, 6}
- `add_to_cart`：{1, 2, 4, 5}
- `checkout`：{1, 2, 5}
- `purchase`：{1, 3, 5}

**`checkout` 是 {1,2,5}，`purchase` 是 {1,3,5}。**

兩個集合大小都是 3，但**內容不同** —— user 2 結帳沒付款，user 3 沒結帳卻付款了。

天真版只是「湊巧」讓兩個數字相等，然後被解讀成 100% 轉換率。

**漏斗的每一步必須是前一步的子集合。** 天真版不保證這件事 —— 這是它根本上的錯誤，而不只是「不夠精確」。

**自我檢查**：寫一個查詢驗證「每一步的使用者集合都是前一步的子集」。天真版會失敗，順序版會通過。

</details>

<details>
<summary>Hint 2 — 逐層收斂骨架</summary>

```sql
WITH s1 AS (
    SELECT user_id, MIN(event_at) AS t
    FROM events WHERE event_type = 'view'
    GROUP BY user_id
),
s2 AS (
    SELECT e.user_id, MIN(e.event_at) AS t
    FROM events e
    JOIN s1 ON s1.user_id = e.user_id
    WHERE e.event_type = 'add_to_cart'
      AND e.event_at > s1.t                    -- ← 必須在前一步之後
    GROUP BY e.user_id
),
s3 AS (
    SELECT e.user_id, MIN(e.event_at) AS t
    FROM events e
    JOIN s2 ON s2.user_id = e.user_id
    WHERE e.event_type = 'checkout' AND e.event_at > s2.t
    GROUP BY e.user_id
),
s4 AS (
    SELECT e.user_id, MIN(e.event_at) AS t
    FROM events e
    JOIN s3 ON s3.user_id = e.user_id
    WHERE e.event_type = 'purchase' AND e.event_at > s3.t
    GROUP BY e.user_id
)
SELECT '1 view' AS step, COUNT(*) AS users FROM s1
UNION ALL SELECT '2 add_to_cart', COUNT(*) FROM s2
UNION ALL SELECT '3 checkout',    COUNT(*) FROM s3
UNION ALL SELECT '4 purchase',    COUNT(*) FROM s4;
```

**兩個關鍵**：
- `JOIN s(n-1)` 保證只有走到前一步的人才有資格進這一步 → **子集合性質成立**
- `event_at > s(n-1).t` 保證順序

</details>

<details>
<summary>Hint 3 — 兩個異常使用者</summary>

**user 3**（`view 11:00 → purchase 11:05`）
沒有 `add_to_cart`，所以進不了 `s2`；進不了 `s2` 就進不了 `s3`、`s4`。
→ 順序版只算他在 `view` 那一步。

**這是對的** —— 他沒有走完漏斗。天真版把他算進 `purchase`，等於憑空製造了一個「完成轉換」的人。

**user 4**（`add_to_cart 12:00 → view 12:30`）
他的 `view` 在 12:30，而唯一的 `add_to_cart` 在 12:00 —— **不在 view 之後**。
→ 進不了 `s2`。

真實成因通常是：追蹤事件的時間戳來自客戶端、時鐘不同步、或事件亂序上報。
**這正是 [Phase 3-05](../../phase-3-window-deep-water/05-sessionization-30-minute-rule) 面試官追問 2 的那個問題** —— 亂序事件會污染所有依賴順序的分析。

</details>

<details>
<summary>Hint 4 — C3 一次掃描</summary>

```sql
WITH t AS (
    SELECT user_id,
           MIN(event_at) FILTER (WHERE event_type = 'view')        AS t1,
           MIN(event_at) FILTER (WHERE event_type = 'add_to_cart') AS t2,
           MIN(event_at) FILTER (WHERE event_type = 'checkout')    AS t3,
           MIN(event_at) FILTER (WHERE event_type = 'purchase')    AS t4
    FROM events GROUP BY user_id
)
SELECT COUNT(*) FILTER (WHERE t1 IS NOT NULL)                          AS s1,
       COUNT(*) FILTER (WHERE t2 > t1)                                 AS s2,
       COUNT(*) FILTER (WHERE t3 > t2 AND t2 > t1)                     AS s3,
       COUNT(*) FILTER (WHERE t4 > t3 AND t3 > t2 AND t2 > t1)         AS s4
FROM t;
```

一次 `GROUP BY` 取出四個時間點，之後純粹是比較 —— **一次掃描搞定**。

`NULL` 的比較自動處理了「沒做過這一步」的情況（`NULL > NULL` 是 UNKNOWN，不計入）—— [Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results) 的三值邏輯在這裡幫了忙。

**C4 的答案**：對 user 5，`t2` 是 **09:02**（全域第一次加購物車），`t3` 是 14:10。
`14:10 > 09:02` 成立 → 他仍然被算進 `s3`、`s4`，和 B1 結果相同。

但如果他第二段沒有再 `add_to_cart`（只有 `view → checkout`），一次掃描版會用第一段的 09:02 判定通過，而逐層收斂版也會 —— **兩者其實等價**，因為都用「最早的合格時間」。

差異會出現在「要求同一 session」或「要求嚴格相鄰」時。**C3 的價值是效能，不是語意差異** —— 講清楚這點才算真懂。

</details>
