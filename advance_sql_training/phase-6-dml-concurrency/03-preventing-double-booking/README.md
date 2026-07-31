# Phase 6-03 — Preventing Double Booking

> **難度**：★★★★★
> **核心技巧**：`EXCLUDE` 約束、`tstzrange`、GiST 索引、`btree_gist`
> **對應基礎題**：[Phase 1-03. The Double-Booked Meeting Room](../../phase-1-join-dark-side/03-the-double-booked-meeting-room)（那題**偵測**已發生的衝突，這題**阻止**它發生）

<br>

---

<br>

## Interview Context

> *面試官：*「[Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 你寫的那個查詢，找出了所有重複訂位。很好。
>
> 但我當時就問過你：『更好的做法是一開始就不讓它發生』。
>
> 現在告訴我怎麼做。**而且不准在應用層寫 if 判斷。**」

<br>

**這一題是 Phase 1-03 的閉環。** 那時你學會了怎麼用 SQL 找出區間重疊；現在你要讓資料庫在**寫入的瞬間**就拒絕重疊。

<br>

---

<br>

## Table Schema

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;      -- ← 必要，見 Part B

DROP TABLE IF EXISTS bookings;

CREATE TABLE bookings (
    id        SERIAL PRIMARY KEY,
    room_id   INT NOT NULL,
    booked_by TEXT NOT NULL,
    during    tstzrange NOT NULL
);
```

<br>

---

<br>

## Part A — 應用層檢查為什麼不夠

### A1

寫出「應用層檢查」的邏輯：先 `SELECT` 有沒有衝突，沒有才 `INSERT`。

（重疊條件用 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room) 推導過的那個。）

### A2 — 重現競態

兩個 session 同時訂**同一間會議室、重疊的時段**，在檢查和插入之間放 `pg_sleep(0.4)`。

回答：
- 兩邊的檢查各查到幾筆衝突？
- 最後表裡有幾筆訂位？
- **這和 [6-01](../01-the-idempotent-upsert) 的「先查再寫」是同一個競態嗎？**

### A3

回答：能不能用 `SERIALIZABLE` 隔離級別解決？

- 試一次。它會擋下來嗎？
- 如果會，代價是什麼？（提示：序列化失敗率、重試邏輯）
- **為什麼「靠約束」比「靠隔離級別」好？**

<br>

---

<br>

## Part B — `EXCLUDE` 約束

### B1 — 加上約束

```sql
ALTER TABLE bookings
ADD CONSTRAINT no_double_booking
EXCLUDE USING gist (room_id WITH =, during WITH &&);
```

**先讀懂這行語法**，逐項回答：

- `USING gist` —— 為什麼是 GiST 而不是 B-tree？
- `room_id WITH =` —— 這是什麼意思？
- `during WITH &&` —— `&&` 是什麼運算子？
- **整條約束用白話講是什麼？**

### B2 — `btree_gist` 為什麼必要

把 `CREATE EXTENSION btree_gist` 拿掉，重建約束試試看。

錯誤訊息是什麼？為什麼？

（提示：GiST 原生支援範圍型別的 `&&`，但不支援整數的 `=`。`btree_gist` 補上這個能力。）

### B3 — 測試

依序測試以下四種插入，記錄結果：

| # | 插入 | 預期 |
|---|------|------|
| 1 | room 101, `[09:00, 10:00)` | 成功 |
| 2 | room 101, `[09:30, 10:30)` | **失敗** |
| 3 | room 101, `[10:00, 11:00)` | 成功（相接不算重疊） |
| 4 | room 102, `[09:30, 10:30)` | 成功（不同房間） |

第 2 筆的完整錯誤訊息是什麼？

### B4 — 半開區間又出現了

第 3 筆 `[10:00, 11:00)` 能成功，是因為用了 `'[)'` 邊界。

- 把它改成 `'[]'`（閉區間）再插入一次，會怎樣？
- 為什麼會議室訂位一定要用半開區間？
- **這是 [Phase 1-03](../../phase-1-join-dark-side/03-the-double-booked-meeting-room)、[Phase 2-06](../../phase-2-aggregation-limits/06-histogram-with-empty-buckets)、[Phase 5-05](../../phase-5-time-series/05-scd-type-2-point-query) 之後，半開區間第四次出現。** 用一句話總結這個原則。

<br>

---

<br>

## Part C — 併發驗證

### C1

兩個 session **同時**插入 room 999 的相同時段（各自加 `pg_sleep(0.2)` 對齊）。

回答：
- 最後表裡有幾筆？（**應該只有 1 筆**）
- 失敗的那個 session 拿到什麼錯誤？
- **實測時你可能會看到兩種錯誤**：`conflicting key value violates exclusion constraint` 或 `deadlock detected`。為什麼會有兩種？
- 應用層要怎麼處理？兩種都要處理嗎？

### C2 — 錯誤處理

回答：
- 使用者按下「訂位」看到 `ERROR: conflicting key value violates exclusion constraint "no_double_booking"` —— 這樣可以嗎？
- 應用層要怎麼把它轉成人話？
- 要不要自動重試？（**訂位衝突該重試嗎？和 [6-04](../04-the-lost-update) 的序列化失敗該重試嗎？差在哪？**）

### C3 — 約束 vs 檢查，最終結論

填完這張表：

| | 應用層檢查 | `SERIALIZABLE` | `EXCLUDE` 約束 |
|---|---|---|---|
| 併發下正確嗎 | ? | ? | ? |
| 效能成本 | ? | ? | ? |
| 需要重試邏輯嗎 | ? | ? | ? |
| 繞得過嗎（有人直接下 SQL） | ? | ? | ? |
| 錯誤訊息友善度 | ? | ? | ? |

<br>

---

<br>

## Part D — 進階

### D1 — 加上取消狀態

真實系統的訂位可以**取消**，取消後那個時段應該可以重訂。

```sql
ALTER TABLE bookings ADD COLUMN status TEXT NOT NULL DEFAULT 'confirmed';
```

- 現在的 `EXCLUDE` 約束會把已取消的訂位也算進去嗎？
- 怎麼讓約束**只對 `confirmed` 的訂位生效**？
  （提示：`EXCLUDE ... WHERE (...)` —— 和 [6-01](../01-the-idempotent-upsert) 的部分唯一索引同一個概念）
- 寫出正確的 DDL 並測試。

### D2 — 效能

`bookings` 有 1000 萬筆。

- GiST 索引的大小和 B-tree 比如何？
- 每次 `INSERT` 要付出什麼成本？
- 查詢「room 101 在某時段有沒有空」能用上這個索引嗎？寫出查詢並看 `EXPLAIN`。

### D3 — 其他適用場景

`EXCLUDE` 約束不只能防訂位衝突。舉出**三個**其他場景，並各寫出 DDL：

- 提示 1：[Phase 5-05](../../phase-5-time-series/05-scd-type-2-point-query) 的 SCD Type 2 表 —— 同一個 `product_id` 的有效區間不能重疊
- 提示 2：員工的排班不能重疊
- 提示 3：想一個你自己工作中遇過的

> **D3 提示 1 特別重要**：[Phase 5-05](../../phase-5-time-series/05-scd-type-2-point-query) Part B4 問過「能不能做成約束讓壞資料寫不進去」。
> **答案就在這裡。** 把那題的 P3 重疊資料用這個約束擋掉。

<br>

---

<br>

## 面試官的追問

> 1. 「`EXCLUDE` 約束和 `UNIQUE` 約束的關係是什麼？`UNIQUE` 能用 `EXCLUDE` 表達嗎？」
>
> 2. 「如果我要『同一個房間同一天最多只能有 3 筆訂位』，`EXCLUDE` 做得到嗎？做不到的話用什麼？」
>
> 3. 「GiST、GIN、SP-GiST、BRIN 分別適合什麼？為什麼區間重疊要用 GiST？」
>
> 4. 「MySQL 有 `EXCLUDE` 約束嗎？沒有的話怎麼實作這個需求？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 讀懂 EXCLUDE 語法</summary>

```sql
EXCLUDE USING gist (room_id WITH =, during WITH &&)
```

**白話**：「不允許存在兩列，它們的 `room_id` **相等**（`=`）**而且** `during` **重疊**（`&&`）。」

`EXCLUDE` 是 `UNIQUE` 的一般化：
- `UNIQUE (a, b)` 等價於 `EXCLUDE (a WITH =, b WITH =)`
- `EXCLUDE` 讓你把 `=` 換成任何**可交換**的運算子（`&&`、`~`、`<>` 等）

**為什麼是 GiST**：B-tree 只能做「大小比較」（`<`、`=`、`>`），它沒辦法回答「這兩個區間重疊嗎」。
GiST 是一種**通用的樹狀索引框架**，範圍型別在它上面實作了 `&&`。

</details>

<details>
<summary>Hint 2 — btree_gist 的角色</summary>

沒有 `btree_gist` 時：

```
ERROR:  data type integer has no default operator class for access method "gist"
HINT:  You must specify an operator class for the index or define a default operator class for the data type.
```

GiST 原生支援 `tstzrange` 的 `&&`，但**不支援 `integer` 的 `=`** —— 那本來是 B-tree 的工作。

`btree_gist` extension 為 GiST 加上「B-tree 型別的等值比較」能力，讓你可以在同一個 GiST 索引裡混用純量欄位和範圍欄位。

**只用範圍欄位的話不需要這個 extension**：

```sql
EXCLUDE USING gist (during WITH &&)      -- 全公司只有一間會議室時 :)
```

</details>

<details>
<summary>Hint 3 — C1 為什麼會有兩種錯誤</summary>

兩個 session 同時插入衝突的區間時：

1. A 先寫入（尚未提交），在索引裡留下一個「推測中」的項目
2. B 嘗試寫入，偵測到可能衝突 → **B 必須等 A 提交或回滾才知道結果** → B 阻塞
3. A 提交 → B 收到 `conflicting key value violates exclusion constraint`

但如果**兩邊幾乎完全同時**開始，可能變成互相等待 → PostgreSQL 的死鎖偵測器介入 → `deadlock detected`。

**兩種錯誤都代表「你的寫入被拒絕了」**，應用層都要處理。

**關鍵是不變式有沒有被破壞** —— 實測結果：**永遠只有 1 筆成功**。這才是約束的價值：不管併發長什麼樣，資料庫層面的不變式永遠成立。

**C2 的答案**：訂位衝突**不該自動重試** —— 重試還是會衝突（那個時段真的被佔了）。要回報給使用者請他選別的時段。

對比 [6-04](../04-the-lost-update) 的序列化失敗：那個**該重試**，因為重試通常會成功（只是時序不巧）。

**判準：重試有機會成功嗎？** 業務衝突 → 不重試；時序衝突 → 重試。

</details>

<details>
<summary>Hint 4 — D1 部分 EXCLUDE 與 D3 的 SCD2 應用</summary>

**D1**：

```sql
ALTER TABLE bookings DROP CONSTRAINT no_double_booking;
ALTER TABLE bookings
ADD CONSTRAINT no_double_booking
EXCLUDE USING gist (room_id WITH =, during WITH &&)
WHERE (status = 'confirmed');                          -- ← 只對已確認的訂位生效
```

和 [6-01](../01-the-idempotent-upsert) 的部分唯一索引完全同一個概念 —— **約束也可以有 predicate**。

**D3 提示 1（SCD Type 2）**：

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE product_price_scd
ADD CONSTRAINT no_overlapping_price
EXCLUDE USING gist (
    product_id WITH =,
    daterange(valid_from, valid_to, '[)') WITH &&
);
```

有了這條約束，[Phase 5-05](../../phase-5-time-series/05-scd-type-2-point-query) 的 P3 重疊資料**根本寫不進去**，那題的 B1 稽核查詢就永遠回傳 0 列。

**這回答了 Phase 5-05 Part B4 的問題**：重疊**可以**做成約束擋掉；缺口**不行**（缺口是「少了東西」，宣告式約束只能擋「多了東西」）。

**這個「能擋多、不能擋少」的界線**，和 [Phase 4-01](../../phase-4-recursive-cte/01-the-org-chart-that-loops) C2 的「`CHECK` 能擋自環、擋不了多層環」是同一類的認識 —— **知道約束的能力邊界在哪，比會寫約束更重要。**

</details>
