# Phase 8-05 — The 90-Minute Take-Home

> **難度**：★★★★★
> **會用到**：全部八章
> **性質**：**計時作答**。這是整套訓練的畢業考。

<br>

---

<br>

## 規則

> ⚠️ **開始之前先看完這一段。**

1. **設一個 90 分鐘的計時器。** 時間到就交卷，不管寫到哪。
2. **不能看前面章節的答案。** 可以查 PostgreSQL 官方文件。
3. **一次跑完 `setup.sql`，然後開始。**
4. 交卷後再回頭對照 Hints。

<br>

### 時間配置建議

| 階段 | 建議時間 |
|------|---------|
| 讀 schema、寫下疑問 | 10 分鐘 |
| Q1 ~ Q5 | 60 分鐘（每題 12 分鐘） |
| 對帳檢查、寫取捨說明 | 15 分鐘 |
| 檢查與收尾 | 5 分鐘 |

**寫不完是正常的。** 重點是你怎麼分配、以及交出來的東西完不完整。

<br>

---

<br>

## 情境

> 你剛加入一家 B2B SaaS 公司的資料團隊。今天是第一天。
>
> 你的主管丟給你一個 schema 和五個問題，說：「**這些是我們每個月董事會要看的。前一個人離職了，他的 SQL 沒人看得懂。你重寫一份。**」
>
> 「喔對了，**資料很髒**。祝好運。」

<br>

---

<br>

## Schema

```sql
-- 帳號
CREATE TABLE accounts (
    id           BIGINT PRIMARY KEY,
    company      TEXT NOT NULL,
    country      TEXT,                      -- 可為 NULL
    signed_up_at TIMESTAMPTZ NOT NULL,
    churned_at   TIMESTAMPTZ,               -- NULL = 尚未流失
    is_internal  BOOLEAN NOT NULL DEFAULT false
);

-- 訂閱方案歷史（SCD Type 2）
CREATE TABLE subscriptions (
    id          BIGSERIAL PRIMARY KEY,
    account_id  BIGINT NOT NULL,
    plan        TEXT NOT NULL,              -- 'free' / 'pro' / 'enterprise'
    mrr         NUMERIC(10,2) NOT NULL,     -- 月經常性收入（USD）
    valid_from  DATE NOT NULL,
    valid_to    DATE                        -- NULL = 目前生效
);

-- 產品使用事件
CREATE TABLE usage_events (
    id          BIGSERIAL PRIMARY KEY,
    account_id  BIGINT NOT NULL,
    seat_email  TEXT NOT NULL,              -- 該帳號下的使用者
    feature     TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL
);

-- 發票
CREATE TABLE invoices (
    id         BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL,
    amount     NUMERIC(10,2) NOT NULL,
    currency   CHAR(3) NOT NULL,            -- 有 USD / EUR / JPY
    issued_on  DATE NOT NULL,
    paid_on    DATE                         -- NULL = 未付款
);

-- 匯率歷史
CREATE TABLE fx_rates (
    currency    CHAR(3) NOT NULL,
    rate_date   DATE NOT NULL,
    rate_to_usd NUMERIC(12,6) NOT NULL,
    PRIMARY KEY (currency, rate_date)
);
```

<br>

完整的 `setup.sql` 在同目錄下。**先跑它，再開始計時。**

<br>

---

<br>

## 五個問題

### Q1 — 月經常性收入（MRR）

> 「給我 **2026 年每個月月底的 MRR**，依方案別拆開。」

**注意**：帳號會升級/降級（`subscriptions` 是 SCD2）。「三月底的 MRR」要用**三月底當下生效**的方案。

<br>

### Q2 — 淨收入留存（NRR）

> 「2026 年 1 月的 cohort，到 6 月的**淨收入留存率**是多少？」
>
> NRR = （該 cohort 在 6 月的 MRR 總和）÷（同一批帳號在 1 月的 MRR 總和）

**先想清楚**：分子分母的帳號集合是同一批嗎？流失的帳號怎麼算？

<br>

### Q3 — 使用黏著度

> 「找出**有流失風險**的付費帳號。」
>
> 定義由你決定，但至少要考慮「使用頻率下降」。

**提示**：這需要你自己定義什麼叫「下降」。寫出你的定義和理由。

<br>

### Q4 — 應收帳款

> 「**2026 上半年開出但還沒收到錢**的發票總額，換算成 USD。」

**注意**：`invoices` 有多種幣別，`fx_rates` 有歷史匯率。

<br>

### Q5 — 這一題故意沒有定義

> 「順便告訴我，我們的**產品有多少人在用**？」

**這一題的評分完全看你怎麼處理這個問題。**

<br>

---

<br>

## 交付要求

你的 `answer.sql` 必須包含：

```
□ 開頭：我會問主管的問題（至少 5 個，用具體情境）
□ 我的假設清單（每條附理由）
□ Q1 ~ Q5 的查詢
□ 每一題的邊界處理說明（處理了什麼、知道但沒處理什麼）
□ 至少兩個對帳/自我檢查查詢
□ 效能說明：資料量 x1000 時哪一題會先爆，怎麼辦
□ 如果時間不夠：明確寫出「我沒做完什麼、為什麼優先做了其他的」
```

<br>

> **最後那一項很重要。**
>
> 真實的 take-home 幾乎沒有人做得完。**誠實說明取捨的人，分數高於硬掰做完的人。**

<br>

---

<br>

## 資料裡的陷阱（交卷後才能看）

<details>
<summary>⚠️ 交卷前不要打開</summary>

setup.sql 裡刻意埋了這些（**括號內是實際筆數**）：

| # | 陷阱 | 實際筆數 | 對應章節 |
|---|------|---------|---------|
| 1 | `accounts.country` 有 NULL —— 依國家分組時整組消失 | **17** | [1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) |
| 2 | `is_internal = true` 的內部帳號污染 MRR | **7** | [8-01](../01-the-ambiguous-metric) |
| 3 | `subscriptions` 區間**重疊** —— 點查詢回傳兩列 → 扇出 | **1 組** | [5-05](../../phase-5-time-series/05-scd-type-2-point-query) |
| 4 | `subscriptions` 區間**缺口** —— 某月查不到方案 | **1 組** | [5-05](../../phase-5-time-series/05-scd-type-2-point-query) |
| 5 | 月中升級 —— 「月底 MRR」≠「月平均 MRR」 | **2** | [5-04](../../phase-5-time-series/04-the-as-of-join) |
| 6 | 發票早於所有匯率紀錄 —— as-of join 得到 NULL | **1** | [5-04](../../phase-5-time-series/04-the-as-of-join) |
| 7 | `seat_email` 大小寫不一致 —— 幽靈 seat | **401 個** | [7-03](../../phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case) |
| 8 | `occurred_at` 在未來（時鐘錯誤） | **5** | — |
| 9 | 已流失帳號**仍在產生** usage_events | **11,456** | — |
| 10 | `invoices.paid_on` **早於** `issued_on` | **427** | [1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) |

**你抓到幾個？**

<br>

> **注意 9 和 10 的筆數** —— 它們不是「一兩筆手滑」，是**上萬筆的系統性矛盾**。
>
> 這才是真實資料的樣子：髒資料很少是孤例，通常是某個上游流程一直在產生錯誤。
>
> **看到 11,456 筆矛盾，正確反應不是「濾掉它」，是「回報並問清楚」** —— 這個量級代表你對業務流程的理解可能有誤（例如：流失後仍保留唯讀權限？`churned_at` 是「通知日」而非「生效日」？）。
>
> **這一題最高分的答案，是問對這個問題。**

</details>

<br>

---

<br>

## 自我評分

| 面向 | 滿分 | 得分 | 說明 |
|------|------|------|------|
| 需求釐清（問題品質） | 30 | ? | ? |
| SQL 正確性 | 30 | ? | ? |
| 邊界與髒資料（抓到幾個陷阱） | 20 | ? | ? |
| 效能與取捨 | 20 | ? | ? |
| **總分** | **100** | ? | |

<br>

### 分數對照

| 分數 | 意義 |
|------|------|
| **85+** | 你準備好了。去面試。 |
| **70~84** | 技術夠了，缺的是「先問再寫」的習慣。重做 [8-01](../01-the-ambiguous-metric)。 |
| **55~69** | SQL 沒問題，但邊界意識不足。回去複習 Phase 1、2、5。 |
| **< 55** | 找出失分最多的那一塊，回去把對應的 Phase 重做一遍。 |

<br>

---

<br>

## Hints（交卷後）

<details>
<summary>Hint 1 — Q1 月底 MRR 的正確做法</summary>

**核心**：這是 [5-05 SCD Type 2 點查詢](../../phase-5-time-series/05-scd-type-2-point-query) + [1-07 骨架](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 的組合。

```sql
WITH month_ends AS (
    SELECT (generate_series('2026-01-01'::date, '2026-12-01'::date, '1 month')
            + interval '1 month - 1 day')::date AS d
),
active AS (
    SELECT m.d, s.account_id, s.plan, s.mrr
    FROM month_ends m
    JOIN subscriptions s
      ON s.valid_from <= m.d
     AND (s.valid_to IS NULL OR m.d < s.valid_to)      -- ← 半開區間
    JOIN accounts a ON a.id = s.account_id
    WHERE NOT a.is_internal
)
SELECT d, plan, count(*) AS accounts, sum(mrr) AS mrr
FROM active GROUP BY d, plan ORDER BY d, plan;
```

**三個關鍵**：
- **月底日期用 `generate_series` 造骨架**，不要從資料裡取（否則沒訂閱的月份會消失）
- **半開區間** `valid_from <= d AND d < valid_to`（陷阱 3 的重疊會讓某些帳號在某天回傳兩列 → **先跑 [5-05 的重疊稽核](../../phase-5-time-series/05-scd-type-2-point-query)**）
- **排除 `is_internal`**（陷阱 2）

**加分**：主動說明「我發現 subscriptions 有重疊區間，account X 在 3 月會被算兩次，我先用稽核查詢找出來並在報表中排除／回報給資料負責人」。

</details>

<details>
<summary>Hint 2 — Q2 NRR 的分母陷阱</summary>

**NRR 的定義是「同一批帳號」的收入變化** —— 分母和分子必須是**同一個帳號集合**。

```sql
WITH cohort AS (                      -- 1 月有付費的帳號
    SELECT DISTINCT s.account_id
    FROM subscriptions s JOIN accounts a ON a.id = s.account_id
    WHERE NOT a.is_internal AND s.mrr > 0
      AND s.valid_from <= '2026-01-31' AND (s.valid_to IS NULL OR '2026-01-31' < s.valid_to)
),
mrr_at AS (
    SELECT c.account_id, m.label, COALESCE(s.mrr, 0) AS mrr    -- ← 流失的補 0，不是排除
    FROM cohort c
    CROSS JOIN (VALUES ('jan','2026-01-31'::date), ('jun','2026-06-30'::date)) m(label, d)
    LEFT JOIN subscriptions s
      ON s.account_id = c.account_id
     AND s.valid_from <= m.d AND (s.valid_to IS NULL OR m.d < s.valid_to)
)
SELECT ROUND(100.0 * sum(mrr) FILTER (WHERE label='jun')
                  / sum(mrr) FILTER (WHERE label='jan'), 1) AS nrr_pct
FROM mrr_at;
```

**最容易錯的地方**：流失的帳號在 6 月**沒有 subscription 列** →
如果用 `JOIN`，它們會從分子**和**分母一起消失 → NRR 永遠是 100%+，永遠好看。

**必須 `LEFT JOIN` 並 `COALESCE(mrr, 0)`** —— 流失的帳號在分子貢獻 0，但**仍然留在分母裡**。

**這是 [2-05 加權平均陷阱](../../phase-2-aggregation-limits/05-the-weighted-average-trap) 的同一個病根：分母定義錯了。**

</details>

<details>
<summary>Hint 3 — Q4 as-of join 與 Q5 的正解</summary>

**Q4**：

```sql
SELECT ROUND(SUM(i.amount * r.rate_to_usd), 2) AS outstanding_usd,
       COUNT(*) FILTER (WHERE r.rate_to_usd IS NULL) AS unconvertible
FROM invoices i
LEFT JOIN LATERAL (
    SELECT rate_to_usd FROM fx_rates f
    WHERE f.currency = i.currency AND f.rate_date <= i.issued_on
    ORDER BY f.rate_date DESC LIMIT 1                    -- ← as-of join
) r ON true
WHERE i.paid_on IS NULL
  AND i.issued_on >= '2026-01-01' AND i.issued_on < '2026-07-01';
```

三個重點：
- **as-of join**，不是最新匯率（[5-04](../../phase-5-time-series/04-the-as-of-join)）
- **`LEFT JOIN LATERAL ... ON true`**，用 `CROSS JOIN` 會靜靜丟掉查不到匯率的發票
- **`unconvertible` 那一欄** —— 主動報告「有幾張換不了」，而不是讓它們消失在 `SUM` 裡

<br>

**Q5 的正解是：不要直接寫 SQL。**

「產品有多少人在用」至少有五種答案：

| 定義 | 數字來源 |
|------|---------|
| 付費帳號數 | `subscriptions` |
| 所有帳號數（含 free） | `accounts` |
| 活躍席次數（seat） | `COUNT(DISTINCT seat_email)` |
| 月活躍席次（MAU） | 同上 + 時間窗 |
| 活躍帳號數 | `COUNT(DISTINCT account_id) FROM usage_events` |

**「帳號」和「人（seat）」是完全不同的東西** —— 一個 enterprise 帳號可能有 500 個 seat。
董事會問「多少人在用」，**十之八九要的是 seat 數，但他說的是「帳號」的語言**。

而 `seat_email` **有大小寫不一致**（陷阱 7）→ `COUNT(DISTINCT seat_email)` 會重複計算 →
必須 `COUNT(DISTINCT lower(seat_email))`（[7-03 表達式索引](../../phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case) 的同一個問題）。

**滿分答案**：把五個數字都列出來，標明定義，然後說「我建議董事會用 XX，因為……，但我想先確認你要的是哪一個」。

</details>

<details>
<summary>Hint 4 — 十個陷阱的完整處理</summary>

| # | 陷阱 | 處理 | 對應章節 |
|---|------|------|---------|
| 1 | `country` 有 NULL | `COALESCE(country,'(unknown)')`，不要讓它消失 | [1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) |
| 2 | `is_internal` 帳號 | 全部查詢都要 `WHERE NOT is_internal` | [8-01](../01-the-ambiguous-metric) |
| 3 | SCD2 區間重疊 | 先跑稽核查詢找出來、回報、報表中去重 | [5-05](../../phase-5-time-series/05-scd-type-2-point-query) |
| 4 | SCD2 區間缺口 | `LEFT JOIN` 讓它顯示 NULL，不要靜靜消失 | [5-05](../../phase-5-time-series/05-scd-type-2-point-query) |
| 5 | 月中升級 | 明確定義「月底快照」vs「月加權平均」並說明選擇 | [5-04](../../phase-5-time-series/04-the-as-of-join) |
| 6 | 發票早於匯率 | `LEFT JOIN LATERAL`，單獨列出 unconvertible | [5-04](../../phase-5-time-series/04-the-as-of-join) |
| 7 | `seat_email` 大小寫 | `lower(seat_email)` | [7-03](../../phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case) |
| 8 | 未來時間的事件 | `WHERE occurred_at <= now()`，並回報有幾筆 | [8-01](../01-the-ambiguous-metric) |
| 9 | 已流失帳號仍有事件 | 資料矛盾 → **回報，不要自己決定** | — |
| 10 | `paid_on < issued_on` | 同上，回報 | [1-04](../../phase-1-join-dark-side/04-ledger-reconciliation) |

**陷阱 9 和 10 是這一題的最高分項**：

它們**不是你該自己修的東西**。正確反應是寫一個「資料品質報告」查詢，把矛盾的列挑出來，
在 `answer.sql` 裡說：

> 「我發現 N 筆資料矛盾（已流失帳號仍有使用事件、付款日早於開立日）。
> 我在報表中先排除它們，但這需要資料負責人確認是資料錯誤還是我對業務流程的理解有誤。清單如下：…」

**「知道什麼不該自己決定」是資深工程師和一般工程師最大的差別。**

</details>
