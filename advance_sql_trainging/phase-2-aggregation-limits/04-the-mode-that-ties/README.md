# Phase 2-04 — The Mode That Ties

> **難度**：★★★☆☆
> **核心技巧**：`MODE()` ordered-set aggregate、並列全取、`RANK` vs `ROW_NUMBER` 的關鍵選擇
> **對應基礎題**：[LC 586. Customer Placing the Largest Number of Orders](../../../sql_training/customer_placing_the_largest_number_of_orders)（你當初用 `ORDER BY ... LIMIT 1`）

<br>

---

<br>

## Interview Context

> *面試官：*「推薦系統要一個特徵：**每個客戶最常買的商品**。
>
> 我看你基礎題寫過類似的，用 `ORDER BY count DESC LIMIT 1`。這次不行 —— 上線後我們發現有些客戶的推薦每天都在變，同一個客戶今天推薦滑鼠、明天推薦鍵盤，資料完全沒變。
>
> 為什麼？怎麼修？」

<br>

「資料沒變但結果會變」= **非決定性查詢**。這是正式環境最難查的一種 bug。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS purchases;

CREATE TABLE purchases (
    id          INT PRIMARY KEY,
    customer_id INT NOT NULL,
    product     VARCHAR(30) NOT NULL,
    bought_on   DATE NOT NULL
);

INSERT INTO purchases (id, customer_id, product, bought_on) VALUES
-- 客戶 1：laptop 買 3 次，mouse 1 次 → 有明確眾數
(1, 1, 'laptop',   '2026-01-01'),
(2, 1, 'laptop',   '2026-01-02'),
(3, 1, 'laptop',   '2026-01-03'),
(4, 1, 'mouse',    '2026-01-04'),
-- 客戶 2：keyboard 2 次、monitor 2 次 → 真正的平手
(5, 2, 'keyboard', '2026-02-01'),
(6, 2, 'keyboard', '2026-02-02'),
(7, 2, 'monitor',  '2026-02-03'),
(8, 2, 'monitor',  '2026-02-04'),
-- 客戶 3：三樣各買 1 次 → 全部平手
(9,  3, 'cable',   '2026-03-01'),
(10, 3, 'dock',    '2026-03-02'),
(11, 3, 'hub',     '2026-03-03'),
-- 客戶 4：只買過 1 樣
(12, 4, 'webcam',  '2026-03-05');
```

<br>

### `MODE()` 給你的答案

```
 customer_id | mode_product
-------------+--------------
           1 | laptop
           2 | keyboard      ← 但 monitor 也是 2 次！
           3 | cable         ← 但 dock、hub 也都是 1 次！
           4 | webcam
```

### 正確答案應該是

```
 customer_id |       modes       | times
-------------+-------------------+-------
           1 | laptop            |     3
           2 | keyboard, monitor |     2
           3 | cable, dock, hub  |     1
           4 | webcam            |     1
```

<br>

---

<br>

## Part A — 內建 `MODE()` 的侷限

### A1

用 `MODE() WITHIN GROUP (ORDER BY product)` 寫出眾數查詢，確認你得到上面那個「錯誤」結果。

### A2

查 PostgreSQL 文件，回答：

- `MODE()` 遇到並列時**怎麼選**？（不要用猜的，查文件）
- 它是**決定性**的嗎？（同樣的資料跑兩次會得到一樣的結果嗎？）
- `WITHIN GROUP (ORDER BY product)` 裡的 `ORDER BY` 在這裡起什麼作用？把它改成 `ORDER BY product DESC` 試試看，客戶 2 的結果變了嗎？

### A3

客戶 3 三樣商品各買一次。`MODE()` 回傳 `cable`。

**這個答案在商業上有意義嗎？** 如果推薦系統拿這個結果去推薦，會發生什麼事？

寫出一個判斷條件：什麼情況下「眾數」這個指標**根本不該被使用**？

<br>

---

<br>

## Part B — 並列全取

### B1

寫出正確版本，輸出每個客戶的**所有**眾數（用 `string_agg` 合併成一欄）以及次數。

核心是選對 window function。回答：

- 用 `ROW_NUMBER()` 會怎樣？
- 用 `RANK()` 會怎樣？
- 用 `DENSE_RANK()` 會怎樣？
- **這一題三者的結果一樣嗎？如果一樣，是巧合還是必然？**

### B2 — 不用 window function

用 `HAVING` + 相關子查詢再寫一版：

```sql
HAVING COUNT(*) = (SELECT MAX(...) FROM ...)
```

比較兩種寫法的可讀性和效能。

### B3 — 輸出格式

`string_agg(product, ', ')` 沒有指定順序時是**非決定性**的。

- 怎麼讓它穩定？
- 這和 A2 的「`MODE()` 非決定性」是同一類問題嗎？
- **寫出這句結論**：任何會出現在報表上的聚合，只要涉及順序，就必須 `______`。

<br>

---

<br>

## Part C — 回頭修基礎題

### C1

打開你基礎訓練的答案：[LC 586. Customer Placing the Largest Number of Orders](../../../sql_training/customer_placing_the_largest_number_of_orders)。

當時你大概是這樣寫的：

```sql
SELECT customer_number
FROM orders
GROUP BY customer_number
ORDER BY COUNT(*) DESC
LIMIT 1;
```

回答：
- 如果兩個客戶訂單數並列第一，這個查詢回傳誰？
- 它是決定性的嗎？
- LeetCode 為什麼會判你通過？（提示：測資）
- **這算不算 bug？** 面試時你會怎麼跟面試官說明？

### C2

把那題重寫成並列安全的版本。

> **這一題的真正價值在這裡**：你在基礎訓練寫過的、被判「通過」的答案，在真實資料上是錯的。
> FAANG 面試官不會給你乾淨測資 —— 他們會問「如果平手呢？」

<br>

---

<br>

## 面試官的追問

> 1. 「`ORDER BY COUNT(*) DESC LIMIT 1` 和 `RANK() = 1` 在有並列時的差異，用一句話講清楚。」
>
> 2. 「什麼時候 `ROW_NUMBER()` 才是對的？舉一個並列時**故意**只要一筆的場景。」
>
> 3. 「如果要『每個客戶最常買的前 3 種商品，含並列』，`RANK` 和 `DENSE_RANK` 會給你不同的答案。差在哪？你選哪個？」
>
> 4. 「這個特徵要每天算一次，`purchases` 有 5 億行。你會怎麼設計？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — MODE() 怎麼挑並列</summary>

PostgreSQL 文件：`mode()` 回傳**出現頻率最高的值；若有多個並列，回傳其中第一個**（依 `WITHIN GROUP` 的 `ORDER BY` 排序）。

所以它**是**決定性的 —— 只要 `ORDER BY` 明確。客戶 2 的 `keyboard` 和 `monitor` 都是 2 次，依 `ORDER BY product` 升冪，`keyboard` 排前面所以被選中。

改成 `ORDER BY product DESC` 就會變成 `monitor`。

**但「決定性」不等於「正確」。** 它只回傳一個值，資訊被丟掉了 —— 呼叫端根本不知道有平手這回事。

</details>

<details>
<summary>Hint 2 — RANK vs ROW_NUMBER vs DENSE_RANK</summary>

對客戶 2（keyboard=2, monitor=2）：

| 商品 | 次數 | ROW_NUMBER | RANK | DENSE_RANK |
|------|------|-----------|------|-----------|
| keyboard | 2 | 1 | **1** | **1** |
| monitor | 2 | **2** | **1** | **1** |

`WHERE rk = 1` 時：
- `ROW_NUMBER` → 只拿到 keyboard（**弄丟了 monitor**）
- `RANK` → 兩個都拿到 ✓
- `DENSE_RANK` → 兩個都拿到 ✓

**本題只取「第 1 名」，所以 `RANK` 和 `DENSE_RANK` 結果相同。**
兩者的差異要到「取前 N 名」時才會顯現（`RANK` 會跳號 1,1,3；`DENSE_RANK` 不跳 1,1,2）—— 那是面試官追問 3。

</details>

<details>
<summary>Hint 3 — 骨架</summary>

```sql
WITH counted AS (
    SELECT customer_id, product, COUNT(*) AS n
    FROM purchases
    GROUP BY customer_id, product
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY customer_id ORDER BY n DESC) AS rk
    FROM counted
)
SELECT customer_id,
       string_agg(product, ', ' ORDER BY product) AS modes,   -- ← ORDER BY 不能省
       MAX(n) AS times
FROM ranked
WHERE rk = 1
GROUP BY customer_id
ORDER BY customer_id;
```

兩層聚合：先數每個 (客戶, 商品) 的次數，再對次數排名。

`string_agg(... ORDER BY product)` 裡的 `ORDER BY` 是**聚合內部排序**，不加的話輸出順序取決於執行計畫 —— 換個計畫報表就變了。

</details>

<details>
<summary>Hint 4 — C1 的答案</summary>

`ORDER BY COUNT(*) DESC LIMIT 1` 在並列時回傳**哪一筆是未定義的** —— 取決於執行計畫、資料實體順序、平行度。同一個 DB 換個版本就可能變。

LeetCode 判你通過是因為它的測資**刻意避開了平手**。這不代表你的答案對，只代表測資弱。

正確版本：

```sql
SELECT customer_number
FROM orders
GROUP BY customer_number
HAVING COUNT(*) = (
    SELECT MAX(cnt) FROM (SELECT COUNT(*) AS cnt FROM orders GROUP BY customer_number) t
);
```

面試時的講法：**「題目沒說平手怎麼辦，我先假設要全部回傳；如果只要一筆，我需要一個明確的 tie-breaker，例如取 customer_number 最小的。」** —— 主動點出歧義並提出處理方式，這就是 [Phase 8](../../README.md) 要練的東西。

</details>
