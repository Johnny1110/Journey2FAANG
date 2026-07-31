# Phase 8-02 — Design a Leaderboard Query

> **難度**：★★★★★
> **會用到**：[2-04 並列](../../phase-2-aggregation-limits/04-the-mode-that-ties)、[3-02 frame](../../phase-3-window-deep-water/02-rows-vs-range-vs-groups)、[7-01 ORDER BY+LIMIT](../../phase-7-optimization-deep-water/01-the-query-that-got-slower-after-adding-an-index)、[7-07 MV](../../phase-7-optimization-deep-water/07-materialized-view-refresh-strategy)

<br>

---

<br>

## Interview Context

> *面試官：*「我們遊戲要做一個排行榜。給我一個查詢。」
>
> *（停頓）*
>
> 「喔對，前端會分頁，一頁 50 個。而且玩家要能看到**自己的排名**，就算他在第 8000 名。」

<br>

排行榜看起來是最簡單的 SQL 題（`ORDER BY score DESC LIMIT 50`）。

**它其實是一道系統設計題。** 分頁、並列、即時性、規模，四個問題互相牽制。

<br>

---

<br>

## Table Schema

```sql
DROP TABLE IF EXISTS scores;
DROP TABLE IF EXISTS players;

CREATE TABLE players (
    id         BIGINT PRIMARY KEY,
    nickname   TEXT NOT NULL,
    country    TEXT NOT NULL,
    is_banned  BOOLEAN NOT NULL DEFAULT false
);

CREATE TABLE scores (
    id          BIGSERIAL PRIMARY KEY,
    player_id   BIGINT NOT NULL REFERENCES players(id),
    score       INT NOT NULL,
    season      INT NOT NULL,
    achieved_at TIMESTAMPTZ NOT NULL
);
```

<br>

**假資料（100 萬玩家、500 萬筆分數，且刻意製造大量並列）**：

```sql
INSERT INTO players (id, nickname, country, is_banned)
SELECT g, 'player_'||g,
       (ARRAY['TW','JP','KR','US'])[floor(random()*4+1)],
       random() < 0.001
FROM generate_series(1, 1000000) g;

-- 分數刻意只有 1000 種可能值 -> 大量並列
INSERT INTO scores (player_id, score, season, achieved_at)
SELECT (random()*999999+1)::bigint,
       (random()*999)::int * 10,
       1,
       now() - (random() * interval '90 days')
FROM generate_series(1, 5000000);

CREATE INDEX ON scores (player_id);
ANALYZE players; ANALYZE scores;
```

<br>

---

<br>

## Part A — 釐清（30 分）

### A1

寫出 **6~8 個**你會問的問題，用具體情境表達。

方向提示（但用你自己的話）：
- 「分數」是最高分、總分、還是最近一次？
- 兩個玩家同分怎麼排？
- 排行榜要多即時？
- 被 ban 的玩家怎麼處理？
- 賽季怎麼算？
- 「自己的排名」和榜單要一致嗎？

### A2 — 這一題的關鍵問題

在你的問題清單裡，**哪一個問題的答案會最大幅度改變你的技術方案？**

寫出：如果那個問題的答案是 A，你會怎麼做；如果是 B，你會怎麼做。

<br>

---

<br>

## Part B — 實作（30 分）

### B1 — 基本榜單

假設「分數 = 該賽季最高分」，寫出第一頁（前 50 名）。

### B2 — 並列

分數只有 1000 種可能值，100 萬玩家 —— **平均每個分數有 1000 個人並列**。

回答並實作：
- `ROW_NUMBER()` / `RANK()` / `DENSE_RANK()` 各會產生什麼榜？
- 「第 50 名和第 51 名同分」時，第一頁該切在哪裡？
- **如果用 `ROW_NUMBER()`，同分的人誰排前面？這是決定性的嗎？**（[2-04](../../phase-2-aggregation-limits/04-the-mode-that-ties)）
- 你需要一個 **tie-breaker**。選什麼？為什麼？

### B3 — 分頁

實作「第 N 頁」。

先寫 `OFFSET` 版本，然後回答：
- `OFFSET 100000 LIMIT 50` 的成本是什麼？（[sql_training Phase 7 Scenario 02](../../../sql_training/phase-7/scenario-02-pagination-pain)）
- **改成 keyset pagination（cursor-based）怎麼寫？**
- keyset 在**有並列**的情況下要注意什麼？（提示：cursor 不能只帶 `score`）

### B4 — 「我的排名」

玩家在第 8,432 名。要顯示他的名次，以及他前後各 5 名。

- 怎麼算出單一玩家的名次？（不要把整個榜算出來再找）
- 前後各 5 名怎麼取？
- **這個查詢的成本和 B1 比如何？**

<br>

---

<br>

## Part C — 邊界（20 分）

### C1

明確回答每一項：

| 情況 | 你的處理 |
|------|---------|
| 被 ban 的玩家 | 排除？保留但標記？排除後名次要不要重算？ |
| 從沒有分數的玩家 | 顯示 0 分還是不出現？ |
| 分數並列跨越分頁邊界 | ? |
| 玩家在你查詢的**同時**刷新了紀錄 | ? |
| 賽季切換的那一秒 | ? |
| 兩個玩家同暱稱 | ? |

### C2 — 一致性

玩家看到「我是第 8432 名」，但翻到第 169 頁卻找不到自己。

- 這可能發生嗎？什麼情況下？
- **「榜單」和「我的排名」用兩個查詢算，一定會有這個問題。** 怎麼避免？
- 如果榜單是快取的、我的排名是即時算的呢？

### C3 — 作弊與異常

- 分數異常高的玩家（作弊）要怎麼在查詢層處理？
- 這該不該是查詢的責任？

<br>

---

<br>

## Part D — 效能與取捨（20 分）

### D1 — 索引

回答並實測：
- B1 的查詢要什麼索引？
- **注意 [7-01](../../phase-7-optimization-deep-water/01-the-query-that-got-slower-after-adding-an-index) 的陷阱**：`ORDER BY score DESC LIMIT 50` 配上 `WHERE season=1 AND NOT is_banned` —— 索引會不會踩到同樣的坑？
- 部分索引（`WHERE NOT is_banned`）有幫助嗎？（[7-03](../../phase-7-optimization-deep-water/03-partial-index-for-the-1-percent-case)）

### D2 — 即時性的取捨

填完這張表：

| 方案 | 榜單新鮮度 | 查詢延遲 | 實作複雜度 | 「我的排名」準不準 |
|------|-----------|---------|-----------|-----------------|
| 每次即時算 | ? | ? | ? | ? |
| Materialized View（每 5 分鐘刷新） | ? | ? | ? | ? |
| 增量彙總表 | ? | ? | ? | ? |
| Redis Sorted Set | ? | ? | ? | ? |

**你選哪一個？為什麼？**

### D3 — 為什麼真實遊戲不用 SQL 做排行榜

回答：
- Redis 的 `ZADD` / `ZREVRANK` 為什麼特別適合排行榜？
- 那 SQL 資料庫在這個架構裡還負責什麼？
- **兩者的資料一致性怎麼保證？**

### D4 — 規模

1 億玩家、即時更新、全球排行榜 + 各國排行榜 + 好友排行榜。

用 200 字說明你的整體設計。

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
<summary>Hint 1 — 那個最關鍵的問題</summary>

**「排行榜要多即時？」**

這一個問題決定了整個技術方案：

- **必須即時（秒級）** → 不能用 MV，只能即時算或用 Redis。而即時算在 100 萬玩家上做全域排名很貴 → **實務上只能 Redis**
- **可以延遲 5 分鐘** → Materialized View 就夠了，SQL 全部搞定，簡單可靠
- **每日結算一次** → 一張普通彙總表，最簡單

**沒問這個就開始寫 SQL 的人，等於在賭。**

**面試技巧**：問完之後補一句「因為如果要秒級即時，我可能會建議用 Redis 而不是 SQL —— 我想先確認方向再寫」。
**這一句話展示了你知道 SQL 不是萬能的**，比寫出漂亮的 SQL 更能打動資深面試官。

</details>

<details>
<summary>Hint 2 — 並列與 tie-breaker</summary>

100 萬玩家、1000 種分數 → 平均每個分數 **1000 人並列**。

| 函數 | 第 50、51 名同分時 | 適合排行榜嗎 |
|------|-------------------|-------------|
| `ROW_NUMBER()` | 硬切，51 名被切到第二頁 | ✅ 分頁需要它 |
| `RANK()` | 兩人都是第 50 名，下一個是 52 | ❌ 沒辦法乾淨分頁 |
| `DENSE_RANK()` | 兩人都是 50，下一個是 51 | ❌ 同上 |

**排行榜通常要兩個都算**：
- `ROW_NUMBER()` 決定**位置**（分頁用）
- `RANK()` 決定**顯示的名次**（給玩家看的「你是第 50 名」）

```sql
ROW_NUMBER() OVER (ORDER BY best_score DESC, player_id ASC) AS position,
RANK()       OVER (ORDER BY best_score DESC)                AS display_rank
```

**tie-breaker 必須是唯一且穩定的** —— `player_id` 最理想。

用 `achieved_at`（先達成的排前面）在商業上更合理，但**如果兩人同時達成**就又並列了 → 還是要再加 `player_id` 兜底。

**沒有 tie-breaker 的 `ORDER BY score DESC` 是非決定性的** —— 同一個查詢跑兩次順序可能不同，玩家會看到自己的名次在跳。這是 [2-04](../../phase-2-aggregation-limits/04-the-mode-that-ties) C1 那個「LeetCode 判你過但其實錯了」的問題在真實產品裡的樣子。

</details>

<details>
<summary>Hint 3 — Keyset pagination 與並列</summary>

**`OFFSET` 版本**：

```sql
SELECT ... ORDER BY best_score DESC, player_id LIMIT 50 OFFSET 100000;
```

資料庫必須**產生並丟棄前 100,000 列**才能給你第 100,001 列開始的 50 筆。第 2000 頁比第 1 頁慢 2000 倍。

**Keyset（cursor）版本**：

```sql
SELECT ... FROM ranked
WHERE (best_score, player_id) < (:last_score, :last_player_id)   -- ← 複合比較
ORDER BY best_score DESC, player_id
LIMIT 50;
```

**關鍵：cursor 不能只帶 `score`。**

如果只帶 `WHERE best_score < :last_score`，那**所有和最後一名同分的玩家都會被跳過** —— 而本題平均每個分數有 1000 人，一頁就會漏掉 950 個人。

複合比較 `(a, b) < (x, y)` 是 SQL 標準的**列比較（row comparison）**，語意是字典序：先比 a，a 相等再比 b。**這正好對應 `ORDER BY a DESC, b` 的排序**。

**注意方向**：`ORDER BY best_score DESC, player_id ASC` 配 `(best_score, player_id) < (...)` 的方向要對得上，這裡容易寫錯。實作時務必用有大量並列的資料測試。

</details>

<details>
<summary>Hint 4 — C2 一致性與 D3 Redis</summary>

**C2：為什麼會找不到自己**

榜單和「我的排名」是**兩次查詢**，中間資料變了 → 兩個快照不一致。

在有大量並列的榜上更嚴重：8432 名附近有 1000 人同分，**任何一次刷新都可能讓你的相對位置變動幾百名**。

**解法**：
1. **同一個查詢一次算完** —— 用一個 CTE 算出排名，同時取「前 50」和「我的位置」。一次掃描、一個快照 → 保證一致
2. **兩者都讀同一份快取/MV** —— 犧牲新鮮度換一致性
3. **明白告訴使用者「排名每 5 分鐘更新」** —— 期望管理往往比技術解法有效

<br>

**D3：Redis Sorted Set**

`ZADD leaderboard <score> <player_id>` / `ZREVRANK leaderboard <player_id>`

Redis 的 sorted set 用 **skip list + hash**，讓「**取得任意成員的排名**」是 O(log N) —— 而 SQL 要算某人的排名得掃過所有分數比他高的人。

**這正是 B4 的痛點**：SQL 算「第 8432 名」很貴，Redis 是常數級的。

**分工**：
- **Redis**：即時排名查詢（讀多寫多、要求毫秒級）
- **PostgreSQL**：**真相來源**（source of truth）—— 分數的完整歷史、稽核、賽季結算、防作弊分析

**一致性保證**：寫入時先寫 PostgreSQL（交易保證），再更新 Redis。Redis 掛掉就從 PostgreSQL 重建。
**Redis 是可重建的快取，不是資料庫** —— 講出這一句，面試官就知道你想清楚了。

（這和 [Phase 6-04 D1](../../phase-6-dml-concurrency/04-the-lost-update) 的「餘額該存還是該算」是同一類架構決策。）

</details>
