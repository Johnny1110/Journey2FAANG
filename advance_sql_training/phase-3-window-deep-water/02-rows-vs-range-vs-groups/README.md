# Phase 3-02 — ROWS vs RANGE vs GROUPS

> **難度**：★★★★☆
> **核心技巧**：三種 frame 模式在有並列值時的語意差異
> **對應基礎題**：[LC 1321. Restaurant Growth](../../../sql_training/restaurant_growth)（你當初的 `ROWS BETWEEN` 移動平均）

<br>

---

<br>

## Interview Context

> *面試官：*「你在履歷上寫熟悉 window function。那我問一個簡單的：
>
> `ROWS BETWEEN` 和 `RANGE BETWEEN` 差在哪？
>
> ……如果你的答案是『差不多，`ROWS` 比較常用』，那我們就不用往下聊了。」

<br>

**這一題不解 bug，只做實驗。** 目標是建立你對 frame 的肌肉記憶 —— 因為 [3-04](../04-gaps-and-islands-ii-merge-intervals)、[3-06](../06-rolling-7-day-average) 會直接用到，而且會用錯就出事。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS scores;

CREATE TABLE scores (
    id     INT PRIMARY KEY,
    player VARCHAR(20) NOT NULL,
    score  INT NOT NULL
);

INSERT INTO scores (id, player, score) VALUES
(1, 'ann', 10),
(2, 'ben', 20),
(3, 'cid', 20),     -- ← 三個 20，這是全題的關鍵
(4, 'dot', 20),
(5, 'eli', 30),
(6, 'fay', 40);
```

> **只有 6 行，全部用手算得出來。** 這一題的目的是讓你**看懂**，不是讓你寫複雜查詢。

<br>

---

<br>

## Part A — 累計 frame

### A1

跑這個查詢：

```sql
SELECT player, score,
  SUM(score) OVER (ORDER BY score ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_sum,
  SUM(score) OVER (ORDER BY score RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS range_sum,
  COUNT(*)   OVER (ORDER BY score ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_cnt,
  COUNT(*)   OVER (ORDER BY score RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS range_cnt
FROM scores ORDER BY score, player;
```

你會得到：

```
 player | score | rows_sum | range_sum | rows_cnt | range_cnt
--------+-------+----------+-----------+----------+-----------
 ann    |    10 |       10 |        10 |        1 |         1
 ben    |    20 |       30 |        70 |        2 |         4
 cid    |    20 |       50 |        70 |        3 |         4
 dot    |    20 |       70 |        70 |        4 |         4
 eli    |    30 |      100 |       100 |        5 |         5
 fay    |    40 |      140 |       140 |        6 |         6
```

### A2

回答：

- `rows_sum` 為什麼是 10, 30, 50, 70…？（每一行的 frame 包含哪幾行？）
- `range_sum` 為什麼三個 20 **都是 70**？
- **用一句話定義**：`ROWS` 數的是 `______`，`RANGE` 看的是 `______`。
- 「peer（同伴行）」的定義是什麼？三個 20 是彼此的 peer 嗎？`ann`（10）和 `ben`（20）是嗎？

### A3 — 和 RANK 的關係

同一個查詢再加兩欄：

```sql
RANK()       OVER (ORDER BY score) AS rnk,
DENSE_RANK() OVER (ORDER BY score) AS dnsrnk
```

你會得到 `rnk` = 1, 2, 2, 2, 5, 6 和 `dnsrnk` = 1, 2, 2, 2, 3, 4。

回答：
- `range_cnt`（1, 4, 4, 4, 5, 6）和 `rnk`（1, 2, 2, 2, 5, 6）有什麼關係？寫出公式。
- **`RANK()` 為什麼會跳號（2 之後直接到 5）？** 用 `RANGE` frame 的概念解釋 —— 這兩件事是同一個原理。
- 能不能只用 `COUNT(*) OVER (... RANGE ...)` 手工做出 `RANK()`？寫出來。

<br>

---

<br>

## Part B — 滑動 frame（三者終於全部分家）

### B1

跑這個：

```sql
SELECT player, score,
  SUM(score) OVER (ORDER BY score ROWS   BETWEEN 1 PRECEDING AND CURRENT ROW) AS rows_1p,
  SUM(score) OVER (ORDER BY score RANGE  BETWEEN 1 PRECEDING AND CURRENT ROW) AS range_1p,
  SUM(score) OVER (ORDER BY score GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW) AS groups_1p
FROM scores ORDER BY score, player;
```

三欄**完全不同**：

```
 player | score | rows_1p | range_1p | groups_1p
--------+-------+---------+----------+-----------
 ann    |    10 |      10 |       10 |        10
 ben    |    20 |      30 |       60 |        70
 cid    |    20 |      40 |       60 |        70
 dot    |    20 |      40 |       60 |        70
 eli    |    30 |      50 |       30 |        90
 fay    |    40 |      70 |       40 |        70
```

### B2 — 逐欄推導

**對每一欄，寫出 `eli`（score=30）那一行的 frame 到底包含哪幾行**，並算出總和驗證。

| 模式 | `1 PRECEDING` 的意思 | eli 的 frame 包含 | 總和 |
|------|---------------------|------------------|------|
| `ROWS` | ? | ? | 50 |
| `RANGE` | ? | ? | 30 |
| `GROUPS` | ? | ? | 90 |

> **提示**：`RANGE 1 PRECEDING` 的 `1` 不是「一行」，是「**score 值減 1**」。所以 eli 的窗是 `score ∈ [29, 30]` —— 只有他自己。
> `GROUPS 1 PRECEDING` 的 `1` 是「**一個 peer 群組**」。

### B3 — 各自適合什麼

填完這張表，每一格都要有**具體場景**：

| | `ROWS` | `RANGE` | `GROUPS` |
|---|---|---|---|
| 單位 | ? | ? | ? |
| 並列值會被 | ? | ? | ? |
| 典型用途 | ? | ? | ? |
| 需要 `ORDER BY` 幾個欄位 | ? | ? | ? |

### B4 — `RANGE` 的限制

跑這個，你會拿到錯誤：

```sql
SELECT SUM(score) OVER (ORDER BY score, player RANGE BETWEEN 1 PRECEDING AND CURRENT ROW)
FROM scores;
```

```
ERROR:  RANGE with offset PRECEDING/FOLLOWING requires exactly one ORDER BY column
```

回答：
- 為什麼 `RANGE` 有這個限制而 `ROWS` 沒有？
- `ORDER BY` 的欄位型別有沒有限制？（試試看 `ORDER BY player RANGE BETWEEN 1 PRECEDING ...`）
- `GROUPS` 有同樣的限制嗎？自己測。

<br>

---

<br>

## Part C — 回頭修基礎題

### C1

打開你基礎訓練的 [LC 1321. Restaurant Growth](../../../sql_training/restaurant_growth)（7 日移動平均）。

當時你寫的大概是 `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`。

回答：
- 那題的 `visited_on` 有沒有重複值？如果有兩位客人同一天來，你的答案會怎樣？
- 如果**中間有一天沒有任何客人**，`ROWS BETWEEN 6 PRECEDING` 涵蓋的是「7 天」還是「7 筆」？
- **你的答案在 LeetCode 通過，是因為對，還是因為測資剛好每天都有資料且已經彙總過？**

### C2

把那題改寫成「即使有缺漏日期也正確」的版本。

> 做不出來沒關係 —— 這正是 [3-06](../06-rolling-7-day-average) 的主題。先感受一下問題在哪。

<br>

---

<br>

## 面試官的追問

> 1. 「`RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW` 這種寫法，`ORDER BY` 的欄位要是什麼型別？」
>
> 2. 「`GROUPS` 是哪個版本加入 PostgreSQL 的？如果我要寫相容舊版的 SQL，怎麼模擬 `GROUPS`？」
>
> 3. 「`RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` 對有並列值的資料是什麼行為？」
>
> 4. 「效能上三者有差嗎？`RANGE` 需要額外做什麼？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 三個單位</summary>

| 模式 | `N PRECEDING` 的單位 |
|------|---------------------|
| `ROWS` | **實體行數** —— 往回數 N 行 |
| `RANGE` | **`ORDER BY` 欄位的值** —— 往回到 `值 - N` |
| `GROUPS` | **peer 群組數** —— 往回數 N 個「並列群組」 |

**peer（同伴行）** = `ORDER BY` 的值完全相同的那些行。三個 20 互為 peer；10 和 20 不是。

`RANGE` 的核心規則：**peer 一定同進同出**。要嘛全在 frame 裡，要嘛全不在。這就是為什麼三個 20 的 `range_sum` 一定相同。

</details>

<details>
<summary>Hint 2 — eli（score=30）的三個 frame</summary>

排序後的行：`ann(10), ben(20), cid(20), dot(20), eli(30), fay(40)`

**`ROWS BETWEEN 1 PRECEDING AND CURRENT ROW`**
往回數 1 **行** → `dot(20)` + `eli(30)` = **50**

**`RANGE BETWEEN 1 PRECEDING AND CURRENT ROW`**
score 落在 `[30-1, 30]` = `[29, 30]` 的所有行 → 只有 `eli(30)` = **30**
（沒有任何一行的 score 是 29）

**`GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW`**
往回數 1 個 **peer 群組**。群組是：`{10}`, `{20,20,20}`, `{30}`, `{40}`
eli 在第 3 群，往回 1 群 = 第 2 群 → `{20,20,20}` + `{30}` = 60 + 30 = **90**

</details>

<details>
<summary>Hint 3 — RANGE 為什麼只能有一個 ORDER BY 欄位</summary>

`RANGE N PRECEDING` 要計算 `當前值 - N`。這需要：

1. `ORDER BY` 欄位必須支援**減法**（數值、日期、時間）
2. 必須**只有一個**欄位 —— 因為「`(score, player)` 減 1」沒有意義

`ROWS` 只是數行，不碰值，所以沒有任何限制。

`GROUPS` 數的是群組，也不碰值，所以**也沒有**這個限制（可以多欄位 `ORDER BY`）。

**這就是 `GROUPS` 存在的理由**：想要「並列同進同出」的語意，但 `ORDER BY` 是多欄位或非數值型別時，`RANGE` 用不了，`GROUPS` 可以。

</details>

<details>
<summary>Hint 4 — 用 COUNT + RANGE 手工做 RANK</summary>

```sql
SELECT player, score,
       RANK() OVER (ORDER BY score) AS builtin_rank,
       COUNT(*) OVER (ORDER BY score RANGE BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) + 1 AS manual_rank
FROM scores ORDER BY score;
```

`RANK` 的定義就是「**比我小的行數 + 1**」。`RANGE ... AND 1 PRECEDING` 剛好排除掉所有 peer，只數嚴格小於當前值的行。

理解這個等式，`RANK` 為什麼跳號就不用背了 —— 三個 20 各自「比我小的只有 1 行（ann）」，所以 rank 都是 2；eli 前面有 4 行比他小，所以 rank 是 5。

</details>
