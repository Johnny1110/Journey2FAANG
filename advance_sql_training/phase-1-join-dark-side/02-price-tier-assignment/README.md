# Phase 1-02 — Price Tier Assignment

> **難度**：★★★☆☆
> **核心技巧**：Non-Equi Join（Band Join）、無上限邊界、區間重疊偵測
> **對應基礎題**：[LC 1068. Product Sales Analysis I](../../../sql_training/product_sales_analysis_i)（基礎等值 JOIN）

<br>

---

<br>

## Interview Context

> *面試官：*「我們有一張訂單表，還有一張『折扣等級』設定表 — 依訂單金額落在哪個區間，決定客戶拿到哪一級的折扣。這張設定表是**營運同事在後台自己維護的**。
>
> 幫我算出每一筆訂單屬於哪一級。
>
> 喔對了 — 最高級 Platinum 是**沒有上限**的。」

<br>

這題的關鍵字是「**營運同事自己維護的**」。真實世界的設定表會被改壞。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS discount_tiers;

CREATE TABLE orders (
    id     INT PRIMARY KEY,
    amount NUMERIC(10,3) NOT NULL       -- ← 注意精度是 3 位小數
);

CREATE TABLE discount_tiers (
    tier_name  VARCHAR(20) PRIMARY KEY,
    min_amount NUMERIC(10,3) NOT NULL,
    max_amount NUMERIC(10,3),            -- ← NULL 代表「無上限」
    discount   NUMERIC(4,3) NOT NULL
);

INSERT INTO discount_tiers (tier_name, min_amount, max_amount, discount) VALUES
('Bronze',      0.00,   99.99, 0.000),
('Silver',    100.00,  499.99, 0.050),
('Gold',      500.00, 1999.99, 0.100),
('Platinum', 2000.00,    NULL, 0.150);   -- ← 無上限

INSERT INTO orders (id, amount) VALUES
(1,     45.000),
(2,     99.990),   -- Bronze 的上界
(3,    100.000),   -- Silver 的下界
(4,    250.000),
(5,    499.990),   -- Silver 的上界
(6,    500.000),   -- Gold 的下界
(7,   1999.990),   -- Gold 的上界
(8,   2000.000),   -- Platinum 的下界
(9,   5000.000),
(10,    99.995),   -- ← 落在 Bronze 上界與 Silver 下界的縫隙裡
(11,   750.000),
(12,   999.990);
```

> **為什麼是 `NUMERIC(10,3)` 而不是 `(10,2)`？**
> 因為 `NUMERIC(10,2)` 會把 `99.995` 四捨五入成 `100.00`，訂單 10 就悄悄變成 Silver、縫隙消失了。
> 這本身就是一堂課：**欄位精度會改變你的資料**。設計 schema 時想清楚精度，否則你的邊界測試根本沒測到你以為的東西。

<br>

---

<br>

## Part A — 基本的 Band Join

### A1

寫出一個查詢，輸出每筆訂單的 `id`、`amount`、`tier_name`、`discount`，以及套用折扣後的 `final_amount`。

先用最直覺的 `BETWEEN` 寫法試一次。**12 筆訂單只會回傳 9 筆。**

### A2

不見的是訂單 8、9（Platinum）和訂單 10。先處理 Platinum：請用三值邏輯解釋 `2000.000 BETWEEN 2000.000 AND NULL` 求值成什麼，為什麼 INNER JOIN 會把這兩筆丟掉。

### A3

修好它。寫出兩種修法：
- 一種用 `COALESCE`
- 一種用 `OR ... IS NULL`

兩種在**執行計畫**上有差別嗎？跑 `EXPLAIN` 看看。

修好之後應該有 **11 筆**匹配 —— 訂單 10 還是不見。

### A4

訂單 10（`99.995`）落在哪一級？

把 `JOIN` 改成 `LEFT JOIN` 確認它真的是 unmatched，而不是被你的條件寫錯濾掉的。

然後回答：
- 這是設計問題還是資料問題？
- **用 `INNER JOIN` 寫這種對照表查詢有什麼隱藏風險？**（提示：訂單 10 就這樣從報表上消失了，而且沒有任何錯誤訊息）
- 你會怎麼重新設計 `discount_tiers` 的 schema 來讓縫隙**結構上不可能存在**？

<br>

---

<br>

## Part B — 當設定表被改壞

營運同事覺得「Silver 應該涵蓋到一千才對」，於是改了設定：

```sql
UPDATE discount_tiers SET max_amount = 999.99 WHERE tier_name = 'Silver';
```

<br>

### B1

現在跑你 Part A 修好的查詢。原本 11 筆匹配，**現在變成 14 筆。**

- 為什麼訂單數會變多？（提示：JOIN 不保證一對一）
- 寫一個查詢找出**哪幾筆訂單被複製了**，以及各自匹配到哪些等級。
- 如果這個結果直接進了財報，會發生什麼事？

### B2

寫一個**稽核查詢**，找出 `discount_tiers` 表中所有**互相重疊**的等級配對。這個查詢應該在營運同事存檔前就跑，擋掉錯誤設定。

預期輸出（只有一組）：

```
+-----------+-----------+
| tier_a    | tier_b    |
+-----------+-----------+
| Silver    | Gold      |
+-----------+-----------+
```

> **注意**：去重條件要用 `a.min_amount < b.min_amount` 而不是 `a.tier_name < b.tier_name`。
> 用名字排序的話會得到 `Gold | Silver`（G < S），讀起來像「Gold 和 Silver 重疊」但順序反了 — 對 debug 的人不友善。
> **輸出的順序也是設計的一部分。**

### B3

再寫一個查詢，找出所有**縫隙**（gap）— 也就是沒有被任何等級覆蓋的金額區間。

### B4

如果不用稽核查詢，而是要**在資料庫層面根本擋掉**重疊，PostgreSQL 有什麼機制？（只要講出方向即可，實作是 Phase 6 的內容）

create table discount_tiers (
    tier_name varchar(20) primary key,
    amount_range numrange NOT NULL,
    discount numeric(4,3) NOT NULL,
    EXCLUDE USING gist (amount_range with &&) -- not allow overlapping ranges
);

<br>

---

<br>

## 面試官的追問

> 1. 「Band Join 的執行計畫長什麼樣？和等值 JOIN 的 Hash Join 有什麼不同？為什麼？」
>
> 2. 「如果 `orders` 有 1000 萬筆、`discount_tiers` 有 4 筆，這個 join 的成本是多少？如果 `discount_tiers` 有 10 萬筆呢？」
>
> 3. 「Band Join 可以用 index 加速嗎？加在哪個欄位？」
>
> 4. 「不用 JOIN，你能用 `CASE WHEN` 寫出同樣的結果嗎？兩種寫法各自的維護成本是什麼？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — BETWEEN 是什麼的簡寫</summary>

`x BETWEEN a AND b` 就是 `x >= a AND x <= b`。

所以 `2000 BETWEEN 2000 AND NULL` 是 `2000 >= 2000 AND 2000 <= NULL` → `TRUE AND UNKNOWN` → **UNKNOWN** → INNER JOIN 不匹配，該行消失。

和 Phase 1-01 是同一個病根：**NULL 不是一個值，是「未知」**。

</details>

<details>
<summary>Hint 2 — 無上限的兩種表達</summary>

```sql
-- 方法一：把 NULL 當成正無窮
o.amount <= COALESCE(t.max_amount, 'Infinity'::NUMERIC)

-- 方法二：顯式處理 NULL
(t.max_amount IS NULL OR o.amount <= t.max_amount)
```

PostgreSQL 的 `NUMERIC` 從 14 開始支援 `'Infinity'`。舊版可用一個夠大的數字，但那是 code smell — 想想為什麼。

</details>

<details>
<summary>Hint 3 — 重疊偵測的核心條件</summary>

兩個區間 `[a1, a2]` 和 `[b1, b2]` 重疊的條件是：

```
a1 <= b2 AND b1 <= a2
```

推導方式：先想「**不**重疊」只有兩種情況（A 完全在 B 左邊、A 完全在 B 右邊），然後取反。

別忘了加 `a.min_amount < b.min_amount` 避免每組配對出現兩次，也避免每一級和自己比對（這是 Phase 1-06 的主題）。

還有 — 別忘了 `max_amount` 可能是 NULL，重疊條件裡也要 `COALESCE`。Platinum 是無上限的，它和誰都可能重疊。

</details>

<details>
<summary>Hint 4 — 更好的 schema 設計</summary>

用**半開區間** `[min, max)` 取代閉區間，並且只存一個邊界：

```sql
CREATE TABLE discount_tiers (
    tier_name  VARCHAR(20) PRIMARY KEY,
    min_amount NUMERIC(10,2) NOT NULL UNIQUE,   -- 只存下界
    discount   NUMERIC(4,3) NOT NULL
);
```

上界由「下一級的下界」推導（用 `LEAD()`）。這樣**結構上不可能有縫隙或重疊**。

這是好的 schema 設計原則：**讓錯誤狀態無法被表達**。

</details>
