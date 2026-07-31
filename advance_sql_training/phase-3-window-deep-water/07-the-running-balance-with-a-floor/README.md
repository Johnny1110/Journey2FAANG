# Phase 3-07 — The Running Balance With a Floor

> **難度**：★★★★★
> **核心技巧**：辨識 window function **做不到**的問題
> **銜接**：這一題是 [Phase 4](../../README.md#phase-4遞迴-cte-進階--圖樹與展開) 的入場券

<br>

---

<br>

## Interview Context

> *面試官：*「銀行帳戶有**餘額不足保護**：如果一筆扣款會讓餘額變成負數，這筆交易直接**被拒絕**，餘額維持不變，然後繼續處理下一筆。
>
> 給我每個帳戶每一筆交易後的餘額，以及哪些交易被拒絕了。
>
> ……我先說，這題不能用 `SUM() OVER`。你先試試看，等你發現為什麼不行，我們再聊。」

<br>

**這一題的目標不是寫出答案，是讓你撞牆。**

前面六題都在教你 window function 有多強。這一題教你它的**邊界在哪裡** —— 而知道邊界，比知道用法更重要。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    id              INT PRIMARY KEY,
    owner           VARCHAR(30) NOT NULL,
    opening_balance NUMERIC(12,2) NOT NULL
);

CREATE TABLE transactions (
    id          INT PRIMARY KEY,
    account_id  INT NOT NULL REFERENCES accounts(id),
    amount      NUMERIC(12,2) NOT NULL,      -- 正數存入、負數提領
    occurred_at TIMESTAMP NOT NULL
);

INSERT INTO accounts (id, owner, opening_balance) VALUES
(1, 'alice', 100.00),
(2, 'bob',    50.00);

INSERT INTO transactions (id, account_id, amount, occurred_at) VALUES
(1, 1,   50.00, '2026-03-01 09:00'),
(2, 1, -200.00, '2026-03-02 09:00'),      -- 會超支 → 拒絕
(3, 1,   30.00, '2026-03-03 09:00'),
(4, 1, -100.00, '2026-03-04 09:00'),
(5, 1, -100.00, '2026-03-05 09:00'),      -- 會超支 → 拒絕
(6, 1,   20.00, '2026-03-06 09:00'),
(7, 2,  -80.00, '2026-03-01 10:00'),      -- 會超支 → 拒絕
(8, 2,   40.00, '2026-03-02 10:00'),
(9, 2,  -60.00, '2026-03-03 10:00');
```

<br>

### 正確答案

```
 account_id | rn | amount  | outcome  | balance
------------+----+---------+----------+---------
          1 |  0 |         | opening  |  100.00
          1 |  1 |   50.00 | applied  |  150.00
          1 |  2 | -200.00 | REJECTED |  150.00      ← 餘額不變
          1 |  3 |   30.00 | applied  |  180.00
          1 |  4 | -100.00 | applied  |   80.00
          1 |  5 | -100.00 | REJECTED |   80.00      ← 餘額不變
          1 |  6 |   20.00 | applied  |  100.00
          2 |  0 |         | opening  |   50.00
          2 |  1 |  -80.00 | REJECTED |   50.00
          2 |  2 |   40.00 | applied  |   90.00
          2 |  3 |  -60.00 | applied  |   30.00
```

<br>

---

<br>

## Part A — 撞牆（必做，不要跳過）

### A1 — 先寫天真版

```sql
SELECT t.id, t.account_id, t.amount,
       a.opening_balance + SUM(t.amount) OVER (PARTITION BY t.account_id ORDER BY t.occurred_at)
         AS naive_balance
FROM transactions t
JOIN accounts a ON a.id = t.account_id
ORDER BY t.account_id, t.occurred_at;
```

跑出來：

```
 id | account_id | amount  | naive_balance
----+------------+---------+---------------
  1 |          1 |   50.00 |        150.00     ← 對
  2 |          1 | -200.00 |        -50.00     ← 從這裡開始全錯
  3 |          1 |   30.00 |        -20.00
  4 |          1 | -100.00 |       -120.00
  5 |          1 | -100.00 |       -220.00
  6 |          1 |   20.00 |       -200.00
```

alice 的真實餘額是 **100.00**，天真版算出 **−200.00**。

### A2 — 試著修

**認真花 15 分鐘嘗試**用 window function 修好它。以下是常見的嘗試，每一種都寫出來、跑一次、然後解釋為什麼失敗：

| 嘗試 | 為什麼失敗 |
|------|-----------|
| `GREATEST(0, opening + SUM(...) OVER (...))` | ? |
| 先把「會超支」的交易過濾掉，再 `SUM` | ? |
| 用 `LAG` 取前一行的餘額 | ? |
| 兩次 window：先算餘額，再修正 | ? |

> **第二個和第三個特別值得試。**
> 第二個：你要怎麼在**過濾之前**知道哪些會超支？而超支與否又取決於過濾的結果 —— 這是循環相依。
> 第三個：`LAG` 只能取到**原始欄位**的前一行值，取不到「前一行**計算出來**的餘額」。

### A3 — 講清楚為什麼不可能

用一句話寫出這類問題的特徵：

**「window function 算不出來的，是那些 `______` 依賴於 `______` 的問題。」**

然後回答：
- `SUM() OVER (ORDER BY ...)` 的每一行是**獨立**計算的（都是「從頭加到這裡」），還是**依賴前一行的結果**？
- 本題的餘額計算，第 n 行依賴的是什麼？
- 為什麼這個依賴關係讓它無法被表達成 window function？

<br>

---

<br>

## Part B — 什麼時候會 / 不會遇到

### B1 — 分類

判斷下列問題**能不能**用 window function 解，並說明理由：

| # | 問題 | window 可解？ |
|---|------|--------------|
| 1 | 累計營收 | ? |
| 2 | 餘額，允許負數 | ? |
| 3 | 餘額，不得低於 0（超支則拒絕） | ? |
| 4 | 餘額，不得低於 0（超支則扣到 0 為止） | ? |
| 5 | 庫存扣減，不足則部分出貨 | ? |
| 6 | 每筆交易後的最高餘額 | ? |
| 7 | 複利計算（每期利息基於上期本利和） | ? |

> **第 4 題特別注意** —— 「扣到 0 為止」和「拒絕」看起來很像，但其中一個**其實可以**用 window function 解。想清楚是哪一個、為什麼。

### B2 — 通用判準

寫出一個**判斷法則**：拿到一個「逐行推進」的問題時，你怎麼快速判斷該用 window 還是遞迴？

<br>

---

<br>

## Part C — 解法預告

### C1

這題的正解是**遞迴 CTE**：從期初餘額出發，一次處理一筆交易，每一步都用**上一步算出的餘額**來判斷。

**先不要看 [Phase 4](../../README.md#phase-4遞迴-cte-進階--圖樹與展開)。** 自己嘗試寫寫看，寫不出來沒關係 —— 把你卡住的地方記在 `answer.sql` 裡。

PostgreSQL 提示（你一定會踩到）：遞迴 CTE 的非遞迴項和遞迴項**型別必須完全一致**，包括精度。`0` 和 `bigint`、`NUMERIC(12,2)` 和 `NUMERIC` 都算不一致，會報這種錯：

```
ERROR:  recursive query "walk" column 3 has type numeric(12,2) in non-recursive term but type numeric overall
HINT:  Cast the output of the non-recursive term to the correct type.
```

解法是在非遞迴項顯式轉型（`a.opening_balance::numeric`）。

### C2 — 效能預判

遞迴 CTE 一次只能推進一行。

- 如果 `transactions` 有 1000 萬行、10 萬個帳戶，這個查詢會跑多久？
- **能不能平行處理不同帳戶？** SQL 裡做得到嗎？
- 如果不能在 SQL 裡解決，你會怎麼設計？（提示：這種計算通常不放在查詢層）

### C3 — 這題的真正答案

面試官問「怎麼算這個餘額」時，**最好的回答不是遞迴 CTE**。

想想看：
- 為什麼真實的銀行系統不會用 SQL 遞迴算餘額？
- 餘額應該是**算出來的**還是**存起來的**？
- 如果餘額存在 `accounts.balance` 欄位裡，每筆交易時更新，會有什麼併發問題？

> 最後這個問題是 [Phase 6](../../README.md#phase-6dml併發與資料正確性) 的核心。
> **Phase 3 教你怎麼算，Phase 4 教你怎麼遞迴，Phase 6 告訴你為什麼真實系統兩個都不用。**

<br>

---

<br>

## 面試官的追問

> 1. 「如果規則改成『超支的交易金額自動調整成剛好把餘額扣到 0』，還需要遞迴嗎？」
>
> 2. 「PostgreSQL 有 window function 能做『依賴前一行計算結果』的事嗎？」
>    （提示：查一下 custom aggregate / `plpgsql` 函數配 `OVER` —— 能不能做到？代價是什麼？）
>
> 3. 「這題如果允許你寫 PL/pgSQL 函數，會比遞迴 CTE 快嗎？」
>
> 4. 「如果交易是**即時進來**的，不是批次算，整個問題會變成什麼樣子？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼 GREATEST(0, ...) 不行</summary>

```sql
GREATEST(0, opening_balance + SUM(amount) OVER (ORDER BY occurred_at))
```

對 alice：`SUM` 依序是 50, -150, -120, -220, -320, -300
加上期初 100：150, -50, -20, -120, -220, -200
套 `GREATEST(0, ...)`：150, **0**, **0**, **0**, **0**, **0**

正確答案是 150, 150, 180, 80, 80, 100。

**差在哪**：`GREATEST` 只是把負數**顯示**成 0，但下一行的 `SUM` 仍然從那個負數繼續累加。它修改了輸出，沒有修改**狀態**。

真正的規則是「被拒絕的交易**根本不進入累加**」—— 而是否被拒絕，取決於當下的餘額，也就是前面所有拒絕決策的結果。

</details>

<details>
<summary>Hint 2 — 為什麼「先過濾再加總」不行</summary>

想法：先找出哪些交易會超支，`WHERE` 掉它們，再對剩下的做 `SUM() OVER`。

**循環相依**：

- 要知道交易 #5 會不會超支 → 需要知道 #4 之後的餘額
- #4 之後的餘額 → 取決於 #2 有沒有被拒絕
- #2 有沒有被拒絕 → 取決於 #1 之後的餘額
- …

你必須**依序**解開，而 `WHERE` 是一次性套用在所有行上的。

**這就是「逐行狀態機」和「集合運算」的根本差異。** SQL 擅長後者，遞迴 CTE 是它模擬前者的方式。

</details>

<details>
<summary>Hint 3 — LAG 為什麼取不到「計算出的餘額」</summary>

```sql
LAG(balance) OVER (ORDER BY occurred_at)     -- balance 是同一個 SELECT 裡算出來的欄位
```

這行不通。window function 的輸入是**表的既有欄位**，不是同一層 `SELECT` 裡其他 window function 的輸出。

你可以疊 CTE 一層一層算，但每一層只能往前推進**固定的一步**。要推進 N 步就要 N 層 CTE —— 而 N 是資料決定的，不是寫死的。

**能寫出「重複 N 次直到結束」的，只有遞迴。**

（這也是 [3-04](../04-gaps-and-islands-ii-merge-intervals) 的 `MAX() OVER` 為什麼可行的對照：那題的 `ends_on` 是**原始欄位**，不是計算結果，所以 window 讀得到。）

</details>

<details>
<summary>Hint 4 — B1 第 4 題的答案</summary>

**「超支則扣到 0 為止」其實可以用 window function 解** —— 在某些條件下。

如果規則是「餘額不得低於 0，超出的部分就不扣」，那麼**餘額 = max(0, 期初 + 累計)**……

不對，這樣還是錯的，因為之後的存款要從 0 開始加，而不是從負的累計值加。

真正可以用 window 解的版本是：**餘額 = 期初 + 累計，但顯示時取 `GREATEST(0, ...)`，且後續計算仍用真實（可能為負）的值** —— 也就是「允許負數但顯示為 0」。這只是顯示層的處理，狀態本身沒有被 clamp。

**判準（B2 的答案）**：
- 如果每一行的值可以寫成「**原始資料的某個聚合**」→ window 可解
- 如果每一行的值必須寫成「**前一行的輸出**加上某個運算」，而且那個運算**不可逆 / 有條件分支** → 需要遞迴

複利（第 7 題）是個有趣的邊界：`本金 × (1+r)^n` 可以用 `EXP(SUM(LN(...)))` 這種技巧轉成聚合 —— **乘法累積可以透過對數變成加法累積**。所以它 window 可解。

</details>
