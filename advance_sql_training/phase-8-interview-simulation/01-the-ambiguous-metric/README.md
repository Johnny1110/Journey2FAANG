# Phase 8-01 — The Ambiguous Metric

> **難度**：★★★★★
> **會用到**：[5-01 留存定義](../../phase-5-time-series/01-the-retention-matrix)、[5-07 DAU/WAU/MAU](../../phase-5-time-series/07-dau-wau-mau-in-one-query)、[2-05 分母陷阱](../../phase-2-aggregation-limits/05-the-weighted-average-trap)

<br>

---

<br>

## Interview Context

> *面試官：*「幫我算一下我們的活躍用戶數。」
>
> *（然後就不說話了，看著你。）*

<br>

**這就是全部的需求。**

大多數候選人會在 10 秒內開始寫 `SELECT COUNT(DISTINCT user_id) FROM events WHERE ...`。

**那一刻他就已經輸了。**

<br>

---

<br>

## Table Schema

面試官給你這個 schema，沒有多說什麼。

```sql
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id           BIGINT PRIMARY KEY,
    email        TEXT NOT NULL,
    signed_up_at TIMESTAMPTZ NOT NULL,
    deleted_at   TIMESTAMPTZ,              -- 軟刪除
    account_type TEXT NOT NULL,            -- 'user' / 'internal' / 'bot'
    timezone     TEXT                      -- 可能是 NULL
);

CREATE TABLE events (
    id         BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL,
    event_type TEXT NOT NULL,              -- 'app_open' / 'page_view' / 'click' / 'purchase' / 'heartbeat'
    occurred_at TIMESTAMPTZ NOT NULL,
    device     TEXT
);
```

<br>

> **schema 裡藏了至少五個需要澄清的東西。** 在往下看之前，先自己找出來。

<br>

---

<br>

## Part A — 釐清（30 分）

### A1 — 寫出你的問題

寫出 **5~7 個**你會問面試官的問題。

**每一個都必須用具體情境表達**，不能是抽象的規則詢問。

參考格式：

> 「有個使用者今天早上打開了 App，但什麼都沒做就關掉了 —— 只產生一筆 `app_open`。他算活躍嗎？」

**評分重點**：問題有沒有問到真正會改變答案的地方。

### A2 — 分類你的問題

把 A1 的問題分成三類：

| 類別 | 你的問題 | 如果答錯，數字會差多少？ |
|------|---------|------------------------|
| **會大幅改變數字** | ? | ? |
| **會小幅改變數字** | ? | ? |
| **不影響數字但影響可信度** | ? | ? |

**面試時要先問第一類。** 時間有限，別浪費在第三類上。

### A3 — schema 裡的線索

針對這五個欄位，各寫出「它的存在暗示了什麼問題」：

- `accounts.deleted_at`
- `accounts.account_type`
- `accounts.timezone`
- `events.event_type` 裡的 `'heartbeat'`
- `events.device`

<br>

---

<br>

## Part B — 實作（30 分）

### B1 — 假設

面試官說：「你自己決定，說明你的假設就好。」

寫出你的完整假設清單，每一條都要有**理由**。

### B2 — 主查詢

在你的假設下，寫出「活躍用戶數」的查詢。

### B3 — 多定義並陳

**這一題的高分解法不是給一個數字，是給一張表。**

寫一個查詢，同時輸出**多種定義**下的活躍用戶數，讓對方自己挑：

```
 definition                          | active_users
-------------------------------------+--------------
 DAU (any event)                     |    ?
 DAU (excluding heartbeat)           |    ?
 DAU (excluding internal & bot)      |    ?
 WAU (7-day, any event)              |    ?
 MAU (30-day, any event)             |    ?
 "Engaged" DAU (>= 2 event types)    |    ?
```

> 這是 [5-01 B4](../../phase-5-time-series/01-the-retention-matrix) 和 [3-05 B2](../../phase-3-window-deep-water/05-sessionization-30-minute-rule) 用過的策略第三次出現：
> **需求模糊時，最好的答案不是猜一個，是把選項攤開。**

### B4 — 黏著度

加上 `DAU/MAU` 比率。

回答：
- 為什麼這個比率比絕對數字更有意義？
- 業界的基準大概多少？
- **這個比率能不能從「每日 DAU」和「每日 MAU」的平均算出來？**（回想 [5-07](../../phase-5-time-series/07-dau-wau-mau-in-one-query)）

<br>

---

<br>

## Part C — 邊界（20 分）

### C1

明確回答你**怎麼處理**下列每一種情況（處理了 / 沒處理但知道）：

| 情況 | 你的處理 |
|------|---------|
| `account_type = 'bot'` 的流量 | ? |
| 已軟刪除（`deleted_at` 不為 NULL）的帳號 | ? |
| `heartbeat` 這種背景事件 | ? |
| 同一人用兩個裝置 | ? |
| `events.account_id` 指向不存在的帳號 | ? |
| 未來時間的事件（時鐘錯誤） | ? |
| 同一秒內的重複事件 | ? |

### C2 — 時區

`accounts.timezone` 可能是 NULL。

回答：
- 「今天的 DAU」的「今天」用誰的時區？
- 用 UTC 算 vs 用使用者本地時區算，數字會差多少？哪個對？
- **如果用使用者本地時區，同一個「今天」在資料庫裡是一個時間範圍還是很多個？** 查詢要怎麼寫？
- `timezone` 是 NULL 的帳號怎麼辦？

### C3 — 自我檢查

寫出**至少兩個**驗證查詢，用來確認你的數字沒算錯。

（提示：活躍用戶數不可能超過總帳號數；DAU 不可能超過 WAU 不可能超過 MAU）

<br>

---

<br>

## Part D — 效能與取捨（20 分）

### D1

`events` 有 **500 億列**（1 億用戶 × 500 天）。

- 你的查詢跑得動嗎？
- 索引怎麼設計？
- **要不要分區？** 分區鍵選什麼？（[7-06](../../phase-7-optimization-deep-water/06-partition-pruning-gone-wrong)）

### D2

儀表板要每小時更新一次。

- 即時算、Materialized View、還是增量彙總表？（[7-07](../../phase-7-optimization-deep-water/07-materialized-view-refresh-strategy)）
- **`COUNT(DISTINCT)` 不可組合**，所以不能預先算好每天的再加總（[5-07](../../phase-5-time-series/07-dau-wau-mau-in-one-query)）。那 WAU/MAU 怎麼加速？
- HyperLogLog 在這裡適用嗎？誤差率能接受嗎？

### D3 — 最終交付

假設你只能給老闆**一個數字**。

- 你給哪一個？
- 你會在旁邊標註什麼？
- **如果下個月有人用不同定義算出不同的數字，你怎麼避免這場爭論？**

<br>

---

<br>

## 自我評分

做完之後回頭對照 [Phase 8 的評分標準](../README.md)：

| 面向 | 滿分 | 你給自己幾分 | 理由 |
|------|------|------------|------|
| 需求釐清 | 30 | ? | ? |
| SQL 正確性 | 30 | ? | ? |
| 邊界處理 | 20 | ? | ? |
| 效能取捨 | 20 | ? | ? |

**誠實一點。** 這一章的價值就在於你知道自己缺哪一塊。

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 該問的問題（不要偷看，先自己寫）</summary>

**第一類（會大幅改變數字）**：

1. 「一個使用者今天打開 App 但什麼都沒點，只產生一筆 `app_open` —— 他算活躍嗎？」
   → 決定要不要過濾 event_type

2. 「我看到 `event_type` 裡有 `heartbeat`，那是背景自動送的還是使用者操作？」
   → 如果是背景送的，所有裝著 App 的人都會「活躍」，數字會膨脹好幾倍

3. 「`account_type` 有 `internal` 和 `bot` —— 這些要算進去嗎？」
   → 內部帳號通常很活躍，佔比可能不小

4. 「『活躍用戶數』是指今天、這週、還是這個月？」
   → DAU / WAU / MAU 差好幾倍

**第二類（小幅改變）**：

5. 「已經刪除帳號的人，他們過去的事件還算嗎？」
6. 「跨日的界線用 UTC 還是使用者本地時區？」

**第三類（不影響數字但影響可信度）**：

7. 「這個數字要拿去做什麼？給投資人看還是內部追蹤？」
   → 這題其實很重要 —— **它決定了前面所有問題的答案該偏保守還是偏寬鬆**

</details>

<details>
<summary>Hint 2 — schema 裡的五個線索</summary>

| 欄位 | 它暗示的問題 |
|------|-------------|
| `deleted_at` | **軟刪除** —— 已刪除的帳號要不要排除？他們過去的事件呢？ |
| `account_type` | **非真人流量** —— internal / bot 混在裡面 |
| `timezone` | **時區問題存在，而且可能是 NULL** —— 產品刻意記錄了它，代表「本地時間」在這個產品裡是有意義的 |
| `'heartbeat'` | **背景事件** —— 這幾乎一定不該算活躍 |
| `device` | **多裝置** —— 同一人可能產生多筆，`COUNT(DISTINCT account_id)` 而非 `COUNT(*)` |

**面試技巧**：schema 裡出現的每一個「你沒預期會有」的欄位，都是設計者刻意放的線索。
主動指出它們，等於告訴面試官「我讀懂了你的 schema」。

</details>

<details>
<summary>Hint 3 — 多定義並陳的寫法</summary>

```sql
WITH real_users AS (
    SELECT id FROM accounts
    WHERE account_type = 'user' AND deleted_at IS NULL
),
real_events AS (
    SELECT e.account_id, e.event_type, e.occurred_at
    FROM events e JOIN real_users u ON u.id = e.account_id
)
SELECT 'DAU (any event)' AS definition,
       count(DISTINCT account_id) AS active_users
FROM events WHERE occurred_at::date = CURRENT_DATE
UNION ALL
SELECT 'DAU (excluding heartbeat)',
       count(DISTINCT account_id)
FROM events WHERE occurred_at::date = CURRENT_DATE AND event_type <> 'heartbeat'
UNION ALL
SELECT 'DAU (real users only)',
       count(DISTINCT account_id)
FROM real_events WHERE occurred_at::date = CURRENT_DATE AND event_type <> 'heartbeat'
UNION ALL
SELECT 'WAU (7-day)',
       count(DISTINCT account_id)
FROM real_events WHERE occurred_at >= CURRENT_DATE - 6 AND event_type <> 'heartbeat'
UNION ALL
SELECT 'MAU (30-day)',
       count(DISTINCT account_id)
FROM real_events WHERE occurred_at >= CURRENT_DATE - 29 AND event_type <> 'heartbeat';
```

**注意 `event_type <> 'heartbeat'`** —— 如果 `event_type` 可能是 NULL，這裡會漏掉那些列（[Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results)、[2-02](../../phase-2-aggregation-limits/02-filter-vs-case-when) 的教訓）。schema 寫了 `NOT NULL` 所以安全 —— **但你要在答案裡說出「我確認過它是 NOT NULL」**。

**這張表本身就是最好的交付物**：它讓對方看到「定義不同、數字差多少」，而不是逼他相信你猜的那一個。

</details>

<details>
<summary>Hint 4 — C2 時區與 D3 的最終交付</summary>

**用使用者本地時區算「今天」**，意味著同一個日曆日在 UTC 上是**一個滑動的範圍**（跨 26 小時，從 UTC+14 到 UTC-12）。

```sql
SELECT count(DISTINCT e.account_id)
FROM events e
JOIN accounts a ON a.id = e.account_id
WHERE (e.occurred_at AT TIME ZONE COALESCE(a.timezone, 'UTC'))::date = CURRENT_DATE;
```

**代價**：`occurred_at` 被函數包住 → **索引失效、分區裁剪失效**（[7-06](../../phase-7-optimization-deep-water/06-partition-pruning-gone-wrong)、[7-03](../../phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case)）。

**實務解法**：在寫入時就多存一欄 `occurred_on_local DATE`，直接索引它。**用空間換查詢能力** —— 這正是 [5-04](../../phase-5-time-series/04-the-as-of-join) D2「as-of join vs 存快照」的同一個取捨。

<br>

**D3 的答案**：

給一個數字，但**一定要附上定義**：

> 「**日活躍用戶 42,318 人**（真實用戶、排除背景事件、以使用者本地時區計算，資料截至 2026-07-31 08:00 UTC）」

**而避免下個月的爭論，靠的不是講清楚，是把定義寫進程式碼**：
把這個定義做成一個 view 或 MV（`v_dau_official`），所有人都查它。
**指標的定義一旦分散在各人的 SQL 裡，就一定會分歧。**

</details>
