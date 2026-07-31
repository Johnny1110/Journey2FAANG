# Phase 8-03 — The Fraud Detection Query

> **難度**：★★★★★
> **會用到**：[3-05 Sessionization](../../phase-3-window-deep-water/05-sessionization-30-minute-rule)、[3-03/3-04 Gaps and Islands](../../phase-3-window-deep-water/03-gaps-and-islands-i-login-streak)、[1-03 區間重疊](../../phase-1-join-dark-side/03-the-double-booked-meeting-room)、[5-04 As-Of](../../phase-5-time-series/04-the-as-of-join)

<br>

---

<br>

## Interview Context

> *面試官：*「風控團隊要一份『可疑帳號』清單。
>
> 他們給的規則是這樣寫的：
>
> - 「**短時間內大量交易**」
> - 「**異地登入**」
> - 「**金額異常**」
>
> 就這樣。他們說『你先做，做出來我們再看看對不對』。」

<br>

**這是最真實的需求形態** —— 需求方自己也不知道要什麼，他們要看到東西才知道。

這一題考的是：**你能不能把三句白話翻譯成可執行、可調整、可解釋的 SQL。**

<br>

---

<br>

## Table Schema

```sql
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS logins;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id           BIGINT PRIMARY KEY,
    email        TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL,
    home_country TEXT
);

CREATE TABLE logins (
    id         BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL,
    ip         INET NOT NULL,
    country    TEXT,                       -- 由 IP 反查，可能失敗
    logged_at  TIMESTAMPTZ NOT NULL,
    success    BOOLEAN NOT NULL
);

CREATE TABLE transactions (
    id          BIGSERIAL PRIMARY KEY,
    account_id  BIGINT NOT NULL,
    amount      NUMERIC(12,2) NOT NULL,
    currency    CHAR(3) NOT NULL,
    merchant    TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    status      TEXT NOT NULL              -- 'approved' / 'declined'
);
```

<br>

---

<br>

## Part A — 把白話翻譯成規則（30 分）

### A1 — 三個規則各需要幾個參數

「短時間內大量交易」這句話裡有**兩個未定義的數字**。找出來。

對三條規則各做一次：

| 規則 | 需要定義的參數 | 你的建議值 | 理由 |
|------|--------------|-----------|------|
| 短時間內大量交易 | ? | ? | ? |
| 異地登入 | ? | ? | ? |
| 金額異常 | ? | ? | ? |

### A2 — 你會問風控的問題

寫出 **6~8 個**問題。

**特別注意這一類**（風控題獨有的）：
- 「誤判一個好客戶的代價，和放過一個盜刷的代價，哪個比較大？」
- 「這份清單是要自動封鎖，還是給人工審核？」

**這兩題決定了你的閾值要抓鬆還是抓緊。** 問了就是專業。

### A3 — 「金額異常」的三種定義

「異常」至少有三種寫法。各寫一個，並說明適用情境：

1. **絕對閾值**：超過 X 元
2. **相對於該帳號的歷史**：超過該帳號平均值的 N 倍
3. **相對於群體分布**：超過所有帳號的 P99

第三種要用到 [2-03 的百分位](../../phase-2-aggregation-limits/03-the-median-without-a-median-function)。

**哪一種最不容易誤判新帳號？**

<br>

---

<br>

## Part B — 實作（30 分）

### B1 — 規則一：短時間內大量交易

寫出「**任意 10 分鐘視窗內，同一帳號有 ≥ 5 筆交易**」的查詢。

> ⚠️ **注意「任意視窗」不是「每 10 分鐘切一段」。**
> 09:58~10:07 之間有 5 筆，切成整點段的話會被拆成 2+3 而漏掉。
>
> 這需要**滑動視窗** —— [3-06](../../phase-3-window-deep-water/06-rolling-7-day-average) 的 `RANGE BETWEEN INTERVAL` 在這裡派上用場。

### B2 — 規則二：異地登入

寫出「**同一帳號在時間上不可能的兩地登入**」的查詢。

思路：連續兩次登入，如果 `country` 不同，而且時間間隔 **短於合理的飛行時間**，就是可疑。

- 用 [3-05](../../phase-3-window-deep-water/05-sessionization-30-minute-rule) 的 `LAG` 取前一次登入
- 簡化假設：任兩國之間最短飛行時間 2 小時
- **`country` 是 NULL（IP 反查失敗）怎麼辦？**（[Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results)）

### B3 — 規則三：金額異常

用 A3 選定的定義實作。

**注意**：如果用「相對該帳號歷史平均」，要小心 —— 帳號的第一筆交易沒有歷史。而且**不能用未來的交易算歷史平均**（那是資料洩漏）。

> 這正是 [5-04](../../phase-5-time-series/04-the-as-of-join) 的 **point-in-time 正確性**：
> 判斷第 N 筆交易是否異常時，只能用**第 1 到 N-1 筆**的統計。
> 用 window function 的 frame 可以精確表達這件事 —— 想想 `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING`（[3-04](../../phase-3-window-deep-water/04-gaps-and-islands-ii-merge-intervals) 用過）。

### B4 — 綜合評分

三條規則不該獨立輸出三份清單。**合併成一份帶分數的清單**：

```
 account_id | risk_score | triggered_rules            | evidence
------------+------------+----------------------------+------------------
        4821 |          8 | {velocity,impossible_travel} | ...
        1093 |          5 | {amount_anomaly}             | ...
```

- 每條規則給幾分？
- 觸發多條規則要不要加權？
- **`evidence` 欄位要放什麼？**（提示：人工審核的人需要看到什麼才能判斷）

<br>

---

<br>

## Part C — 邊界（20 分）

### C1

| 情況 | 你的處理 |
|------|---------|
| 新帳號（沒有歷史可比） | ? |
| `logins.country` 是 NULL | ? |
| 交易是 `declined` 的 | ? |
| 同一秒的多筆交易（重複送出） | ? |
| 跨幣別的金額比較 | ? |
| VPN 使用者（正常但看起來異地） | ? |
| 時區 / 夏令時間 | ? |

**「跨幣別的金額比較」特別注意** —— 10000 JPY 和 10000 USD 差 100 倍。
要換算的話，用**哪一天的匯率**？（[5-04](../../phase-5-time-series/04-the-as-of-join)）

### C2 — 誤判分析

寫一個查詢，估算你的規則會**標記多少個帳號**、佔總帳號的百分比。

回答：
- 如果標了 30% 的帳號，這份清單有用嗎？
- 人工審核團隊一天能看幾筆？你的閾值要怎麼調才「剛好夠用」？
- **這是技術問題還是營運問題？**

### C3 — 可解釋性

風控人員看到 `account 4821, risk_score 8` 之後，要能判斷「這真的是盜刷嗎」。

- 你的查詢要輸出什麼才夠他判斷？
- **如果他不同意你的判斷，他要怎麼給你回饋？**

<br>

---

<br>

## Part D — 效能與演進（20 分）

### D1

`transactions` 每天新增 5000 萬筆。

- 這個查詢要多久跑一次？批次還是即時？
- 只掃最近 24 小時可以嗎？**規則二（異地登入）需要看多久的歷史？**
- 索引怎麼設計？要分區嗎？（[7-06](../../phase-7-optimization-deep-water/06-partition-pruning-gone-wrong)）

### D2 — 即時 vs 批次

回答：
- 盜刷偵測要在**交易發生前**擋下來才有價值，批次跑有意義嗎？
- 哪些規則適合即時（交易當下算）、哪些適合批次（事後補抓）？
- **即時版本要怎麼寫？**（提示：只看單一帳號的最近 N 筆，成本完全不同）

### D3 — 規則會一直改

風控說「閾值改成 8 分鐘 3 筆」，下週又要改。

- 閾值寫死在 SQL 裡有什麼問題？
- 怎麼設計成可調整的？（提示：參數表 + JOIN）
- **這樣做的代價是什麼？**（提示：[7-03](../../phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case) 的計畫快取問題）

### D4 — 這該不該用 SQL 做

回答：
- SQL 做規則式風控的優勢是什麼？
- 什麼時候該換成串流處理（Flink / Kafka Streams）或 ML 模型？
- **在那之後，SQL 還負責什麼？**

<br>

---

<br>

## 自我評分

| 面向 | 滿分 | 你給自己幾分 | 理由 |
|------|------|------------|------|
| 需求釐清 | 30 | ? | ? |
| SQL 正確性 | 30 | ? | ? |
| 邊界處理 | 20 | ? | ? |
| 效能取捨 | 20 | ? | ? |

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 風控題獨有的那兩個問題</summary>

**「誤判的代價 vs 放過的代價，哪個大？」**

- **銀行轉帳**：放過一筆盜刷可能損失幾十萬 → **寧可誤判，閾值抓緊**
- **電商小額**：誤判會讓好客戶結不了帳、直接流失 → **寧可放過，閾值抓鬆**

這一個問題直接決定你的閾值方向。**不問就是在猜。**

**「自動封鎖還是人工審核？」**

- **自動封鎖** → 誤判代價極高 → 只放最有把握的規則，閾值要非常嚴
- **人工審核** → 可以放寬，但**受限於審核團隊的產能**

第二個接著推導出 C2 的問題：**如果審核團隊一天只能看 200 筆，你的規則就必須調到「一天標出約 200 筆」** ——
這不是技術最佳化，是**產能約束下的最佳化**。

**能問出這兩題的候選人，面試官會知道你做過真實的風控或營運系統。**

</details>

<details>
<summary>Hint 2 — 滑動視窗的交易速度</summary>

**錯誤做法**（切成固定時段）：

```sql
GROUP BY account_id, date_trunc('hour', occurred_at)     -- ✗
```

09:58~10:07 的 5 筆會被切成 `09:00` 那段 2 筆 + `10:00` 那段 3 筆 → **漏掉**。
（而且 `date_trunc` 包住欄位還會讓索引和分區裁剪失效 —— [7-06](../../phase-7-optimization-deep-water/06-partition-pruning-gone-wrong)。）

**正確做法**（滑動視窗）：

```sql
SELECT account_id, occurred_at,
       count(*) OVER (
           PARTITION BY account_id
           ORDER BY occurred_at
           RANGE BETWEEN INTERVAL '10 minutes' PRECEDING AND CURRENT ROW
       ) AS txn_in_window
FROM transactions
WHERE status = 'approved'
```

然後 `WHERE txn_in_window >= 5`（記得包在子查詢裡 —— **`WHERE` 在 window function 之前執行**，[3-06 Part D](../../phase-3-window-deep-water/06-rolling-7-day-average) 的教訓）。

`RANGE BETWEEN INTERVAL` 是 PG 11+ 的功能，看的是**時間值**而不是行數 —— 這正是 [3-02](../../phase-3-window-deep-water/02-rows-vs-range-vs-groups) 教的 `ROWS` vs `RANGE` 差異在真實場景的應用。

</details>

<details>
<summary>Hint 3 — 異地登入與 point-in-time 金額</summary>

**規則二**：

```sql
WITH seq AS (
    SELECT account_id, country, logged_at,
           LAG(country)   OVER (PARTITION BY account_id ORDER BY logged_at) AS prev_country,
           LAG(logged_at) OVER (PARTITION BY account_id ORDER BY logged_at) AS prev_at
    FROM logins WHERE success
)
SELECT account_id, prev_country, country, prev_at, logged_at,
       logged_at - prev_at AS gap
FROM seq
WHERE country IS NOT NULL AND prev_country IS NOT NULL     -- ← NULL 處理
  AND country <> prev_country
  AND logged_at - prev_at < interval '2 hours';
```

**`country IS NOT NULL AND prev_country IS NOT NULL` 不能省** —— 否則 `country <> prev_country` 遇到 NULL 會是 UNKNOWN，那筆就被靜靜跳過。

**但更重要的是想清楚語意**：IP 反查失敗（NULL）到底該當成「可疑」還是「不知道」？
保守做法是**單獨列出來**給人工看，而不是塞進正常規則裡。

<br>

**規則三的 point-in-time 寫法**：

```sql
SELECT id, account_id, amount, occurred_at,
       avg(amount) OVER (
           PARTITION BY account_id ORDER BY occurred_at
           ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING     -- ← 排除當前列
       ) AS hist_avg,
       count(*) OVER (
           PARTITION BY account_id ORDER BY occurred_at
           ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
       ) AS hist_n
FROM transactions WHERE status = 'approved'
```

**`AND 1 PRECEDING` 是關鍵** —— 把當前這筆排除在「歷史平均」之外。
不排除的話，一筆超大金額會把自己的平均值也拉高，**降低自己被抓到的機率**。

（這正是 [3-04](../../phase-3-window-deep-water/04-gaps-and-islands-ii-merge-intervals) 的 `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING` 第二次派上用場。）

`hist_n` 用來處理新帳號：`hist_n < 5` 的就不套用這條規則（樣本太少）。

</details>

<details>
<summary>Hint 4 — D3 參數表與 D4 的界線</summary>

**D3：閾值外部化**

```sql
CREATE TABLE fraud_rules (
    rule_name  TEXT PRIMARY KEY,
    window_min INT,
    threshold  INT,
    weight     INT NOT NULL,
    enabled    BOOLEAN NOT NULL DEFAULT true
);
```

查詢時 `CROSS JOIN fraud_rules r WHERE r.rule_name='velocity'`，用 `r.threshold` 取代寫死的 5。

**代價**：
- 閾值變成**執行期才知道的值** → planner 無法用它做選擇率估計 → 可能選錯計畫
- 而且 [7-03](../../phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case) 的部分索引在參數化條件下可能失效

**取捨**：可調整性 vs 可預測的效能。實務上常見的折衷是「參數表 + 定期重新產生 SQL」，而不是每次查詢都 JOIN 參數表。

<br>

**D4：什麼時候該離開 SQL**

**SQL 適合**：
- 規則明確、可解釋（風控必須能向監管機關解釋為什麼擋下這筆）
- 批次補抓、事後分析
- 規則數量少（< 幾十條）

**該換成串流/ML 的訊號**：
- 需要**毫秒級**在交易授權前決策 → SQL 的往返延遲就不夠了
- 規則數量爆炸（幾百條）且互相關聯 → 維護成本失控
- 需要偵測**未知模式**（規則只能抓你想得到的）

**換過去之後 SQL 還負責什麼？**
- **真相來源**與稽核軌跡
- **標記資料的產生**（訓練 ML 模型需要的 label）
- **模型效果的離線評估**（precision / recall 怎麼算？用 SQL）
- 監管報表

**這和 [8-02](../02-design-a-leaderboard-query) 的「Redis 做排名、PostgreSQL 做真相來源」是同一個架構思維** ——
**SQL 很少是唯一的答案，但它幾乎永遠是那個「說了算」的地方。**

</details>
