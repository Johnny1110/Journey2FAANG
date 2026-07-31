# Phase 1-06 — The Self-Join That Counted Twice

> **難度**：★★★☆☆
> **核心技巧**：對稱配對去重、自我配對邊界、`COUNT` 在自連接後的意義
> **對應基礎題**：[LC 181. Employees Earning More Than Their Managers](../../../sql_training/employees_earning_more_than_their_managers)（基礎自連接，但那題是**非對稱**關係）

<br>

---

<br>

## Interview Context

> *面試官：*「社群 App 的追蹤是**單向**的 — 我追蹤你，你不一定追蹤我。當兩個人**互相追蹤**時，我們叫做『好友』。
>
> 產品經理要三個數字：
> 1. 平台上總共有幾對好友
> 2. 列出所有好友配對
> 3. 每個人有幾個好友
>
> 上一位工程師交出來的數字是 PM 預期的**兩倍**。他堅持他的 SQL 是對的。你來看看。」

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS follows;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id       INT PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

CREATE TABLE follows (
    follower_id INT NOT NULL,
    followee_id INT NOT NULL,
    followed_at DATE NOT NULL,
    PRIMARY KEY (follower_id, followee_id)
);

INSERT INTO users (id, username) VALUES
(1, 'alice'), (2, 'bob'),   (3, 'carol'), (4, 'dave'),
(5, 'eve'),   (6, 'frank'), (7, 'grace'), (8, 'heidi');

INSERT INTO follows (follower_id, followee_id, followed_at) VALUES
(1, 2, '2026-01-10'),   -- alice → bob
(2, 1, '2026-01-11'),   -- bob → alice        ✓ 互相追蹤
(1, 3, '2026-01-12'),   -- alice → carol
(3, 1, '2026-01-12'),   -- carol → alice      ✓ 互相追蹤
(2, 3, '2026-01-15'),   -- bob → carol        ✗ 單向（carol 沒回追）
(4, 5, '2026-02-01'),   -- dave → eve
(5, 4, '2026-02-03'),   -- eve → dave         ✓ 互相追蹤
(5, 6, '2026-02-05'),   -- eve → frank        ✗ 單向
(6, 6, '2026-02-06'),   -- frank → frank      ⚠ 自我追蹤（髒資料）
(7, 8, '2026-03-01');   -- grace → heidi      ✗ 單向
```

<br>

### 正確答案

**好友配對數：3**

```
+----------+----------+
| user_a   | user_b   |
+----------+----------+
| alice    | bob      |
| alice    | carol    |
| dave     | eve      |
+----------+----------+
```

**每人好友數：**

```
+----------+--------------+
| username | friend_count |
+----------+--------------+
| alice    | 2            |
| bob      | 1            |
| carol    | 1            |
| dave     | 1            |
| eve      | 1            |
| frank    | 0            |
| grace    | 0            |
| heidi    | 0            |
+----------+--------------+
```

<br>

> **注意 frank**：他自我追蹤（`6 → 6`）。天真的自連接會判定他和自己「互相追蹤」→ 多算一對好友。這種髒資料在真實系統裡到處都是。

<br>

---

<br>

## The Broken Query

上一位工程師的版本：

```sql
SELECT COUNT(*) AS friend_pairs
FROM follows a
JOIN follows b
  ON a.follower_id = b.followee_id
 AND a.followee_id = b.follower_id;
```

**回傳：7。** PM 說應該是 3。

<br>

---

<br>

## Your Task

### Q1 — 為什麼是 7？

不要只說「因為重複算了」。請把這個自連接的**每一組匹配列出來**（會有 7 行），標示出哪些是重複、哪些是自我配對。

推導出這個公式：`7 = 3 × 2 + 1`，並說明 `× 2` 和 `+ 1` 分別是什麼。

### Q2 — 修好它

寫出正確的好友配對查詢，輸出 `user_a`、`user_b`（用 username，不是 id），排序穩定。

必須同時處理：
- 對稱重複
- 自我追蹤

**用一個條件同時解決兩件事**，不要寫兩個條件。

### Q3 — `<` vs `<>` vs `!=`

- 為什麼是 `a.follower_id < b.follower_id` 而不是 `<>`？
- 用 `<>` 的話結果會是什麼？
- 有沒有其他寫法能達到同樣效果？（想想 `LEAST` / `GREATEST`，或 `EXISTS`）
- 這三種寫法在**執行計畫**上有差別嗎？

### Q4 — 每人好友數

寫出「每人好友數」的查詢。三個必須處理的點：

- **`frank`、`grace`、`heidi` 好友數是 0，但他們必須出現在結果裡**（不能被 JOIN 濾掉）
- `alice` 有 2 個好友 — 你的去重邏輯不能把她的其中一個好友弄丟
- `frank` 的自我追蹤不能算成好友

> ⚠️ **這一題和 Q2 的去重方向是相反的。** Q2 要「每對只出現一次」，Q4 要「每對從兩端各算一次」。想清楚差別在哪，這是這一題最容易錯的地方。

### Q5 — 三種寫法對比

好友配對至少有三種寫法，都寫出來：

- **A：自連接 + `<`**
- **B：`EXISTS` 反向確認** — `SELECT * FROM follows f WHERE f.follower_id < f.followee_id AND EXISTS (...)`
- **C：`INTERSECT`** — 把 `(follower, followee)` 和反轉後的集合取交集

哪一種最好讀？哪一種最快？跑 `EXPLAIN` 驗證你的直覺。

<br>

---

<br>

## 面試官的追問

> 1. 「如果我要的是『**單向**追蹤』的配對（我追你但你沒追我），查詢怎麼改？這時候還能用 `a.id < b.id` 嗎？為什麼？」
>
> 2. 「`6 → 6` 這種自我追蹤是髒資料。你會怎麼在**資料庫層面**擋掉它？」
>
> 3. 「`follows` 有 10 億行（社群平台規模）。你的自連接還跑得動嗎？你會怎麼設計？」
>
> 4. 「PM 現在要『共同好友數最多的前 10 對用戶』。怎麼寫？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 把 7 拆開</summary>

自連接條件 `a.follower = b.followee AND a.followee = b.follower` 會匹配出：

| a | b | 說明 |
|---|---|------|
| (1,2) | (2,1) | alice-bob，方向一 |
| (2,1) | (1,2) | alice-bob，方向二 ← 重複 |
| (1,3) | (3,1) | alice-carol，方向一 |
| (3,1) | (1,3) | alice-carol，方向二 ← 重複 |
| (4,5) | (5,4) | dave-eve，方向一 |
| (5,4) | (4,5) | dave-eve，方向二 ← 重複 |
| (6,6) | (6,6) | frank 和**自己** ← 自我配對 |

`7 = 3 對 × 2 個方向 + 1 個自我配對`

</details>

<details>
<summary>Hint 2 — 一個條件解決兩個問題</summary>

```sql
WHERE a.follower_id < b.follower_id
```

- `1 < 2` TRUE，`2 < 1` FALSE → 每對只留一個方向 ✓
- `6 < 6` FALSE → 自我配對被排除 ✓

**嚴格不等號 `<` 同時完成了去重和排除自我配對。** 這就是為什麼不能用 `<>`。

</details>

<details>
<summary>Hint 3 — Q4 為什麼方向相反</summary>

Q2 問的是「**有幾對**」→ 每對算一次 → 需要 `<` 去重。

Q4 問的是「**每個人有幾個朋友**」→ alice-bob 這對，要在 alice 的計數裡算一次，**也要**在 bob 的計數裡算一次 → **不能**用 `<` 去重。

正確做法是：先找出所有互相追蹤的**有向邊**（不去重，6 條），再依 `follower_id` 分組計數。然後 `LEFT JOIN users` 把 0 好友的人補回來。

```sql
WITH mutual AS (
    SELECT f.follower_id, f.followee_id
    FROM follows f
    WHERE f.follower_id <> f.followee_id          -- 排自我追蹤
      AND EXISTS (SELECT 1 FROM follows r
                  WHERE r.follower_id = f.followee_id
                    AND r.followee_id = f.follower_id)
)
SELECT u.username, COUNT(m.followee_id) AS friend_count
FROM users u
LEFT JOIN mutual m ON m.follower_id = u.id
GROUP BY u.id, u.username
ORDER BY u.id;
```

注意最後是 `COUNT(m.followee_id)` 不是 `COUNT(*)` — 想想為什麼。這是 Phase 2-07 的預告。

</details>

<details>
<summary>Hint 4 — 用 CHECK 約束擋掉自我追蹤</summary>

```sql
ALTER TABLE follows
    ADD CONSTRAINT no_self_follow CHECK (follower_id <> followee_id);
```

**在寫入端擋住，好過在每一個查詢裡防禦。**

這是 Phase 6 的核心思維：讓錯誤狀態在資料庫層面就無法存在，而不是靠每個工程師記得在 `WHERE` 裡加條件。

</details>
