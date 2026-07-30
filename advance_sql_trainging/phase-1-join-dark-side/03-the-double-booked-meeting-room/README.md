# Phase 1-03 — The Double-Booked Meeting Room

> **難度**：★★★★☆
> **核心技巧**：區間重疊自連接、半開區間語意、對稱配對去重
> **對應基礎題**：[LC 197. Rising Temperature](../../../sql_training/rising_temperature)（基礎自連接 + 日期運算）

<br>

---

<br>

## Interview Context

> *面試官：*「今天早上有兩組人同時走進同一間會議室，然後尷尬地站在門口對看。
>
> 我們的訂位系統沒有做重複檢查。現在我需要你先**找出所有已經衝突的訂位**，我們才能一個一個打電話去道歉。
>
> 順便告訴我 — 為什麼 9:00-10:00 和 10:00-11:00 這兩筆**不算**衝突？」

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS bookings;

CREATE TABLE bookings (
    id        INT PRIMARY KEY,
    room_id   INT NOT NULL,
    booked_by VARCHAR(50) NOT NULL,
    starts_at TIMESTAMP NOT NULL,
    ends_at   TIMESTAMP NOT NULL
);

INSERT INTO bookings (id, room_id, booked_by, starts_at, ends_at) VALUES
-- Room 101
(1, 101, 'Alice', '2026-03-02 09:00', '2026-03-02 10:00'),
(2, 101, 'Bob',   '2026-03-02 09:30', '2026-03-02 10:30'),   -- 和 1 重疊
(3, 101, 'Carol', '2026-03-02 10:00', '2026-03-02 11:00'),   -- 和 1 相接（不算重疊），和 2 重疊
(4, 101, 'Dave',  '2026-03-02 14:00', '2026-03-02 15:00'),   -- 不衝突
-- Room 102
(5, 102, 'Eve',   '2026-03-02 09:00', '2026-03-02 17:00'),   -- 包場一整天
(6, 102, 'Frank', '2026-03-02 12:00', '2026-03-02 13:00'),   -- 完全被 5 包住
(7, 102, 'Grace', '2026-03-03 09:00', '2026-03-03 10:00'),   -- 不同天，不衝突
-- Room 103
(8, 103, 'Heidi', '2026-03-02 09:00', '2026-03-02 10:00');   -- 唯一一筆
```

<br>

### 正確答案應該是（3 組配對）

```
+------+------+---------+
| id_a | id_b | room_id |
+------+------+---------+
| 1    | 2    | 101     |
| 2    | 3    | 101     |
| 5    | 6    | 102     |
+------+------+---------+
```

<br>

> **注意**：`(1, 3)` **不在**答案裡 — 9:00-10:00 和 10:00-11:00 只是「相接」不是「重疊」。這是**半開區間** `[start, end)` 的語意。你的查詢必須正確處理這個邊界。

<br>

---

<br>

## Your Task

在 `answer.sql` 中完成：

### Q1 — 從第一原理推導重疊條件

**先不要寫 SQL。** 用文字或圖說明：

兩個區間 A = `[a_start, a_end)` 和 B = `[b_start, b_end)`，**不重疊**只有哪兩種情況？把這兩種情況寫成不等式，然後取反（De Morgan）得到重疊條件。

> 面試技巧：直接背「重疊條件是 `a.start < b.end AND b.start < a.end`」會被追問到破功。從「不重疊」反推是唯一講得清楚的方式。

### Q2 — 寫出查詢

輸出所有衝突配對，欄位：`id_a`、`id_b`、`room_id`、`booked_by_a`、`booked_by_b`、`overlap_minutes`（重疊的分鐘數）。

三個必須處理的點：
- 同一間會議室才算衝突
- 每組配對只能出現**一次**（不是 `(1,2)` 和 `(2,1)` 各一次）
- 一筆訂位不能和自己衝突

### Q3 — 半開 vs 閉區間

把你的條件從 `<` 改成 `<=`，重跑一次。多出哪一筆？請說明：
- 什麼商業情境下 `(1, 3)` **應該**算衝突？
- 你會怎麼在 schema 上讓這個語意變得明確、不靠註解？

### Q4 — PostgreSQL 的原生解法

PostgreSQL 有兩個內建工具可以直接表達區間重疊：

- `OVERLAPS` 運算子
- `tsrange` 型別 + `&&` 運算子

各用一種重寫你的查詢。回答：
- `OVERLAPS` 的區間語意是半開還是閉？（**查文件確認，不要猜**）
- `tsrange(a, b)` 預設的邊界是什麼？怎麼顯式指定 `[)` / `[]` / `(]`？

### Q5 — 規模

`bookings` 現在有 500 萬筆。

- 你的自連接的時間複雜度是什麼？
- 加什麼 index 有幫助？
- 如果只需要檢查**今天**的衝突，查詢怎麼改？
- 有沒有辦法讓這個查詢從 O(n²) 降到接近 O(n log n)？（提示：想想 Phase 3 的 window function）

<br>

---

<br>

## 面試官的追問

> 1. 「你找出了衝突。但更好的做法是**一開始就不讓它發生**。你會怎麼做？」
>    （這題的答案在 [Phase 6-03](../../README.md#phase-6dml併發與資料正確性) — 先想想，之後會正式練。）
>
> 2. 「如果我在應用層先 `SELECT` 檢查有沒有衝突，沒有才 `INSERT`，這樣夠嗎？」
>
> 3. 「三筆訂位互相重疊（A-B、B-C、A-C），你的查詢回傳 3 組配對。但使用者想看到的是『這個時段有 3 筆衝突』。怎麼改？」
>
> 4. 「`overlap_minutes` 怎麼算？如果一筆完全被另一筆包住呢？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 不重疊的兩種情況</summary>

```
情況一：A 完全在 B 之前
   A: [====]
   B:        [====]
   條件：a_end <= b_start

情況二：A 完全在 B 之後
   A:        [====]
   B: [====]
   條件：b_end <= a_start
```

不重疊 = `a_end <= b_start OR b_end <= a_start`

重疊 = `NOT (a_end <= b_start OR b_end <= a_start)`
　　 = `a_end > b_start AND b_end > a_start`
　　 = `a_start < b_end AND b_start < a_end`

**只需要兩個不等式，不需要 4 個 `CASE`。** 很多人第一次寫會列出「A 包住 B」「B 包住 A」「左邊部分重疊」「右邊部分重疊」四種情況 — 那是正確但囉嗦的，而且很容易漏掉一種。

</details>

<details>
<summary>Hint 2 — 為什麼是 a.id < b.id 而不是 a.id <> b.id</summary>

`<>` 只排除自我配對，但 `(1,2)` 和 `(2,1)` 都還在 → 每組出現兩次。

`<` 同時做到兩件事：排除自我配對（`1 < 1` 為 false），且每組只保留一個方向。

</details>

<details>
<summary>Hint 3 — overlap_minutes</summary>

重疊區間的長度 = `LEAST(a_end, b_end) - GREATEST(a_start, b_start)`

`TIMESTAMP` 相減得到 `INTERVAL`。轉成分鐘用 `EXTRACT(EPOCH FROM ...) / 60`。

</details>

<details>
<summary>Hint 4 — tsrange 與索引</summary>

```sql
SELECT ...
FROM bookings a
JOIN bookings b
  ON a.room_id = b.room_id
 AND a.id < b.id
 AND tsrange(a.starts_at, a.ends_at, '[)') && tsrange(b.starts_at, b.ends_at, '[)');
```

`&&` 是「重疊」運算子。`'[)'` 顯式指定左閉右開。

B-tree index 對 `&&` **沒用**。範圍型別要用 **GiST index**：

```sql
CREATE INDEX idx_bookings_range
  ON bookings USING gist (room_id, tsrange(starts_at, ends_at, '[)'));
```

（`room_id` 這個純量欄位要進 GiST 索引需要 `btree_gist` extension。）

</details>
