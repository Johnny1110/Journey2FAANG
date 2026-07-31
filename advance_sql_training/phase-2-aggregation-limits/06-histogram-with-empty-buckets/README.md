# Phase 2-06 — Histogram With Empty Buckets

> **難度**：★★★★☆
> **核心技巧**：`width_bucket`、等寬 vs 等量分桶、`NTILE` 的誤用、邊界溢位
> **對應基礎題**：[Phase 1-07. The Report With Missing Rows](../../phase-1-join-dark-side/07-the-report-with-missing-rows)（骨架補齊，同一個心法換個場景）

<br>

---

<br>

## Interview Context

> *面試官：*「SRE 團隊要一張 API 回應時間的分布圖：0 到 500 毫秒切成 10 個桶，每桶 50 毫秒。
>
> 上一版工程師交出來的圖只有 5 根長條，中間坑坑洞洞的，而且 y 軸加起來的總數**比實際請求數少**。
>
> 兩個 bug，你找找看。」

<br>

第一個 bug 你在 Phase 1 學過了。**第二個 bug 是新的，而且更陰險 —— 它會安靜地吃掉你的資料。**

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS api_requests;

CREATE TABLE api_requests (
    id          SERIAL PRIMARY KEY,
    endpoint    VARCHAR(40) NOT NULL,
    response_ms INT NOT NULL
);

INSERT INTO api_requests (endpoint, response_ms) VALUES
('/login',     12), ('/login',     18), ('/login',     25), ('/login',    31),
('/login',     44), ('/login',     47), ('/login',    180), ('/login',   195),
('/search',    15), ('/search',    22), ('/search',   380), ('/search',  412),
('/search',   455), ('/checkout',   8), ('/checkout',  11), ('/checkout', 19),
('/checkout', 492),
('/checkout', 500),      -- ← 正好等於上界
('/search',   640);      -- ← 超過上界（逾時的請求）
```

<br>

**總共 19 筆。記住這個數字。**

<br>

---

<br>

## Part A — 第一個 bug：消失的空桶

### A1

用 `width_bucket(response_ms, 0, 500, 10)` 加 `GROUP BY` 寫出直方圖。

你會得到 **6 行**，不是 10 行：

```
 bucket | count
--------+-------
      1 |    11
      4 |     2
      8 |     1
      9 |     1
     10 |     2
     11 |     2      ← 這是什麼？
```

### A2

桶 2、3、5、6、7 去哪了？為什麼 `GROUP BY` 生不出它們？

**這和 [Phase 1-07](../../phase-1-join-dark-side/07-the-report-with-missing-rows) 是完全相同的病根。** 用一句話講清楚那個共通原則。

### A3

用 `generate_series(1, 10)` 造骨架 + `LEFT JOIN` 補齊，輸出完整 10 行，並附上每個桶的區間下界和上界：

```
 bucket | lo  | hi  |  n
--------+-----+-----+-----
      1 |   0 |  50 |  11
      2 |  50 | 100 |   0
      3 | 100 | 150 |   0
      4 | 150 | 200 |   2
      5 | 200 | 250 |   0
      6 | 250 | 300 |   0
      7 | 300 | 350 |   0
      8 | 350 | 400 |   1
      9 | 400 | 450 |   1
     10 | 450 | 500 |   2
```

<br>

---

<br>

## Part B — 第二個 bug：被吃掉的資料

### B1 — 對帳

把 A3 的 `n` 全部加起來：**11 + 0 + 0 + 2 + 0 + 0 + 0 + 1 + 1 + 2 = 17**。

但表裡有 **19** 筆。

**兩筆資料消失了。去哪了？**

### B2 — `width_bucket` 的邊界行為

跑這三個，記下結果：

```sql
SELECT width_bucket(-5,  0, 500, 10) AS below,
       width_bucket(600, 0, 500, 10) AS above,
       width_bucket(500, 0, 500, 10) AS at_max;
```

回答：
- 低於下界回傳什麼？
- 高於上界回傳什麼？
- **`500` 正好等於上界，回傳 10 還是 11？為什麼？**
- 用區間符號寫出第 k 桶的範圍：是 `[lo, hi]` 還是 `[lo, hi)`？

### B3 — 修好它

你的骨架是 `generate_series(1, 10)`，所以 `LEFT JOIN` 時桶 0 和桶 11 **匹配不到任何骨架行，直接被丟掉** —— 而且沒有任何錯誤訊息。

寫出正確版本，要求：
- 桶 0（低於下界）和桶 11（高於上界）必須顯示為 `< 0ms` 和 `>= 500ms`
- 總數必須等於 19
- **加上一行自我檢查的 SQL**，驗證直方圖總數 = 原始行數

> **這是這一題最重要的產出。** 任何會被拿去做決策的彙總查詢，都該附帶一個對帳檢查。
> 面試時主動寫出這個檢查，等於直接告訴面試官「我在正式環境被燒過」。

### B4

`response_ms = 500` 這一筆現在被歸到「>= 500ms 的溢位桶」。

- 從 SRE 的角度，這樣分類**對嗎**？
- 如果 SRE 說「500ms 應該算在最後一個正常桶裡」，你怎麼改？
- 改完之後，`width_bucket` 的上界參數該填多少？

<br>

---

<br>

## Part C — `NTILE` 不是你要的東西

### C1

跑這個：

```sql
SELECT ntile_bucket, COUNT(*) AS n, MIN(response_ms) AS lo, MAX(response_ms) AS hi
FROM (SELECT response_ms, NTILE(4) OVER (ORDER BY response_ms) AS ntile_bucket
      FROM api_requests) t
GROUP BY 1 ORDER BY 1;
```

你會看到每桶的**數量**大致相同，但**寬度**天差地別。

### C2

用一句話說清楚 `width_bucket` 和 `NTILE` 的根本差異。

填完這張表：

| | `width_bucket` | `NTILE` |
|---|---|---|
| 每桶固定的是什麼 | ? | ? |
| 桶會不會是空的 | ? | ? |
| 適合回答什麼問題 | ? | ? |

### C3

SRE 問：「**P95 回應時間**是多少？」

- 這該用 `width_bucket`、`NTILE`、還是別的？
- 用 [Phase 2-03](../03-the-median-without-a-median-function) 學的東西寫出來。
- 為什麼監控系統關心 P95/P99 而不是平均值？（用本題的資料證明：算出平均和 P95，比較兩者）

<br>

---

<br>

## 面試官的追問

> 1. 「`width_bucket` 有兩種簽名，另一種吃一個陣列當桶邊界。什麼時候會需要**不等寬**的桶？」
>    （提示：回應時間的分布通常是長尾的）
>
> 2. 「如果我不知道資料的範圍，要動態決定 min/max，怎麼寫？有什麼風險？」
>
> 3. 「這張表有 10 億行，每次畫圖都全表掃描。你會怎麼設計？」
>
> 4. 「`GROUP BY (response_ms / 50)` 和 `width_bucket` 有什麼差別？為什麼不直接用除法？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — width_bucket 的定義</summary>

`width_bucket(value, low, high, count)` 把 `[low, high)` 等分成 `count` 個桶，回傳 `value` 落在第幾桶（**從 1 開始**）。

超出範圍時：
- `value < low` → 回傳 **0**
- `value >= high` → 回傳 **count + 1**

**注意 `>=`。** 上界是**開區間**，所以 `width_bucket(500, 0, 500, 10)` 回傳 **11**，不是 10。

第 k 桶的範圍是 `[low + (k-1)*w, low + k*w)`，其中 `w = (high-low)/count`。全部都是**左閉右開** —— 和 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 的區間語意一致。

</details>

<details>
<summary>Hint 2 — 骨架要涵蓋 0 和 11</summary>

```sql
WITH buckets AS (
    SELECT generate_series(0, 11) AS bucket      -- ← 0 到 11，不是 1 到 10
),
labelled AS (
    SELECT b.bucket,
           CASE WHEN b.bucket = 0  THEN '< 0ms'
                WHEN b.bucket = 11 THEN '>= 500ms'
                ELSE ((b.bucket-1)*50)::TEXT || ' - ' || (b.bucket*50)::TEXT || 'ms'
           END AS range_label
    FROM buckets b
)
SELECT l.bucket, l.range_label, COUNT(r.id) AS n
FROM labelled l
LEFT JOIN api_requests r ON width_bucket(r.response_ms, 0, 500, 10) = l.bucket
GROUP BY l.bucket, l.range_label
ORDER BY l.bucket;
```

自我檢查：

```sql
-- 這兩個數字必須相等，否則你的直方圖在說謊
SELECT (SELECT SUM(n) FROM <上面的查詢>) AS histogram_total,
       (SELECT COUNT(*) FROM api_requests) AS actual_total;
```

</details>

<details>
<summary>Hint 3 — width_bucket vs NTILE</summary>

| | `width_bucket` | `NTILE` |
|---|---|---|
| 每桶固定的是 | **寬度**（值的範圍） | **數量**（行數） |
| 桶會不會是空的 | **會**（所以要補骨架） | **不會**（每桶都塞得滿滿的） |
| 適合回答 | 「回應時間**分布**長什麼樣？」 | 「把使用者**分成四等分**，各組表現如何？」 |

一句話：**`width_bucket` 切的是 x 軸，`NTILE` 切的是資料本身。**

畫直方圖用前者。做分位數分群（前 25% 的高價值客戶）用後者。

</details>

<details>
<summary>Hint 4 — 為什麼不用除法</summary>

`GROUP BY (response_ms / 50)` 看起來等價，但：

- **整數除法會截斷**：`response_ms` 是 INT 時 `-5 / 50 = 0`，和 `12 / 50 = 0` 撞在同一桶 —— 負值和小正值無法區分。
- **沒有溢位桶**：640 / 50 = 12，你的骨架要多大才夠？範圍不固定。
- **改桶數要重算所有算式**，`width_bucket` 只要改一個參數。
- **浮點數會出事**：`NUMERIC` 除法的邊界捨入可能讓 `49.999999` 掉錯桶。

`width_bucket` 把這些邊界都定義清楚了。**能用內建函數就別自己造輪子** —— 尤其是邊界邏輯。

</details>
