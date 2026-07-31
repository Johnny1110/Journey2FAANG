# Phase 6-07 — MERGE vs ON CONFLICT

> **難度**：★★★☆☆（但結論很重要）
> **核心技巧**：PostgreSQL 15 的 `MERGE`、**它的併發陷阱**
> **前置題**：[6-01. The Idempotent Upsert](../01-the-idempotent-upsert)

<br>

---

<br>

## Interview Context

> *面試官：*「PostgreSQL 15 加了 `MERGE`，是 SQL 標準語法，Oracle 和 SQL Server 用很久了。
>
> 我們團隊有人提議把所有的 `INSERT ... ON CONFLICT` 都改成 `MERGE`，理由是『標準語法比較好移植』。
>
> **你同意嗎？**」

<br>

這一題只有一個核心結論，但它會讓你在面試中脫穎而出：**`MERGE` 和 `ON CONFLICT` 的併發保證不一樣。**

<br>

---

<br>

## Table Schema

```sql
DROP TABLE IF EXISTS inventory;

CREATE TABLE inventory (
    sku TEXT PRIMARY KEY,
    qty INT NOT NULL
);
```

<br>

---

<br>

## Part A — 語法對照

### A1

同一個需求「SKU1 進貨 5 個，已存在就累加」，用兩種語法各寫一次：

```sql
-- ON CONFLICT
INSERT INTO inventory (sku, qty) VALUES ('SKU1', 5)
ON CONFLICT (sku) DO UPDATE SET qty = inventory.qty + EXCLUDED.qty;

-- MERGE
MERGE INTO inventory t
USING (SELECT 'SKU1'::text AS sku, 5 AS qty) s ON t.sku = s.sku
WHEN MATCHED THEN UPDATE SET qty = t.qty + s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty);
```

單執行緒各跑兩次，確認結果都是 `qty = 10`。

### A2 — 語法能力對照

填完這張表：

| 能力 | `ON CONFLICT` | `MERGE` |
|------|--------------|---------|
| 需要唯一約束嗎 | ? | ? |
| 可以 `DELETE` 嗎 | ? | ? |
| 可以有多個條件分支 | ? | ? |
| 可以用複雜的 `ON` 條件（非等值） | ? | ? |
| 來源可以是另一張表/查詢 | ? | ? |
| SQL 標準語法 | ? | ? |

### A3 — `MERGE` 能做而 `ON CONFLICT` 做不到的事

寫出一個 `MERGE` 範例，包含三種分支：

```sql
WHEN MATCHED AND s.qty = 0 THEN DELETE
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...
```

回答：用 `ON CONFLICT` 要怎麼達成同樣效果？（要幾個語句？）

<br>

---

<br>

## Part B — 併發（重點）

### B1 — 兩個 session 同時 `MERGE`

```sql
-- Session A 和 Session B 同時跑（表是空的）
BEGIN;
SELECT pg_sleep(0.3);
MERGE INTO inventory t
USING (SELECT 'SKU1'::text AS sku, 5 AS qty) s ON t.sku = s.sku
WHEN MATCHED THEN UPDATE SET qty = t.qty + s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty);
COMMIT;
```

**實測結果**：

```
B merge done
ERROR:  duplicate key value violates unique constraint "inventory_pkey"
最終 qty = 5
```

**其中一個 session 直接失敗了，它的 5 個庫存完全遺失。**

### B2 — 同樣場景用 `ON CONFLICT`

```sql
-- Session A 和 Session B 同時跑（表是空的）
BEGIN;
SELECT pg_sleep(0.3);
INSERT INTO inventory (sku, qty) VALUES ('SKU1', 5)
ON CONFLICT (sku) DO UPDATE SET qty = inventory.qty + EXCLUDED.qty;
COMMIT;
```

**實測結果**：

```
B upsert done
A upsert done
最終 qty = 10          ← 兩邊都正確累加了
```

### B3 — 為什麼

回答：
- `MERGE` 的執行邏輯是什麼？它什麼時候決定走 `MATCHED` 還是 `NOT MATCHED`？
- 兩個 session 同時執行時，為什麼**兩邊都決定走 `NOT MATCHED`**？
- `ON CONFLICT` 為什麼不會有這個問題？（提示：speculative insertion）
- **`MERGE` 是「有 bug」還是「行為就是這樣定義的」？** 查 PostgreSQL 文件確認。

### B4 — 結論

回答面試官最初的問題：**要不要把 `ON CONFLICT` 全部改成 `MERGE`？**

寫出你完整的回答（30 秒內講完），要包含：
- 兩者的併發保證差異
- 什麼場景該用哪一個
- 「可移植性」這個理由站不站得住腳

<br>

---

<br>

## Part C — 正確使用 `MERGE`

### C1 — 讓 `MERGE` 併發安全

如果一定要用 `MERGE`，有兩種方式讓它安全：

1. 把交易隔離級別提到 `SERIALIZABLE`
2. 應用層捕捉唯一鍵違反並重試

各實作一次，回答：
- `SERIALIZABLE` 下重跑 B1，結果是什麼？錯誤訊息有變嗎？
- 重試邏輯要重試幾次？會不會無限重試？

### C2 — `MERGE` 真正適合的場景

`MERGE` 最大的價值是**批次資料同步**（ETL / 資料倉儲），例如「把 staging 表的變更套用到目標表」：

```sql
MERGE INTO inventory t
USING staging_inventory s ON t.sku = s.sku
WHEN MATCHED AND s.qty = 0 THEN DELETE
WHEN MATCHED THEN UPDATE SET qty = s.qty
WHEN NOT MATCHED THEN INSERT (sku, qty) VALUES (s.sku, s.qty);
```

回答：
- 這個場景通常有併發問題嗎？為什麼？
- 用 `ON CONFLICT` 要寫幾個語句才能達成同樣效果？
- **這是不是就是 `MERGE` 該用的地方？**

### C3 — 判準

**寫出這句結論**：

> `MERGE` 適合 `______` 的場景；`ON CONFLICT` 適合 `______` 的場景。
> 判準是 `______`。

<br>

---

<br>

## Part D — 跨資料庫

### D1

回答：
- MySQL 的 `INSERT ... ON DUPLICATE KEY UPDATE` 和 PostgreSQL 的 `ON CONFLICT` 差在哪？
- MySQL 8 支援 `MERGE` 嗎？
- Oracle 和 SQL Server 的 `MERGE` 有同樣的併發問題嗎？（SQL Server 的 `MERGE` 有一系列著名的 bug）
- **「用標準語法比較好移植」這個論點，在真實世界成立嗎？**

### D2

回答：如果你的團隊要制定一條 coding guideline，你會怎麼寫關於 upsert 的規範？

<br>

---

<br>

## 面試官的追問

> 1. 「`MERGE` 的 `WHEN NOT MATCHED BY SOURCE` 是什麼？PostgreSQL 支援嗎？」
>
> 2. 「`ON CONFLICT` 的 speculative insertion 具體是怎麼運作的？」
>
> 3. 「兩個 session 同時對**同一個鍵**做 `ON CONFLICT DO UPDATE`，第二個會等待嗎？」
>
> 4. 「如果 `MERGE` 的 `USING` 來源有重複鍵會怎樣？和 `ON CONFLICT` 的行為一樣嗎？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — 為什麼 MERGE 在併發下會失敗</summary>

`MERGE` 的執行流程：

1. 對 `USING` 的每一列，用 `ON` 條件去目標表**查找**
2. 找到 → 走 `WHEN MATCHED`；找不到 → 走 `WHEN NOT MATCHED`
3. 執行對應的動作

**問題在第 1 步和第 3 步之間**：

```
A: 查找 SKU1 → 不存在 → 決定走 NOT MATCHED → INSERT
B:    查找 SKU1 → 不存在 → 決定走 NOT MATCHED → INSERT → 💥 唯一鍵違反
```

這就是 [6-01](../01-the-idempotent-upsert) Part A 的「**先查再寫**」競態 —— **`MERGE` 本質上就是資料庫幫你做的「先查再寫」，它繼承了同樣的競態。**

**`ON CONFLICT` 不一樣**：它用 **speculative insertion（推測性插入）**——

1. 直接嘗試插入，在索引裡放一個「推測中」的標記
2. 如果撞到別人的標記，**等對方提交或回滾**
3. 對方提交了 → 轉為執行 `DO UPDATE`（此時能看到對方的資料）
4. 對方回滾了 → 自己的插入成功

**關鍵差異：`ON CONFLICT` 的「衝突判定」發生在索引層、有鎖保護；`MERGE` 的「MATCHED 判定」發生在查詢層、沒有保護。**

這**不是 bug** —— PostgreSQL 文件明確寫了 `MERGE` 在併發下可能因唯一鍵違反而失敗，建議用 `ON CONFLICT` 或 `SERIALIZABLE` + 重試。

</details>

<details>
<summary>Hint 2 — 能力對照</summary>

| 能力 | `ON CONFLICT` | `MERGE` |
|------|--------------|---------|
| 需要唯一約束 | **要**（否則無法推斷衝突） | **不用**（用 `ON` 條件） |
| 可以 `DELETE` | ✗ | **✓** |
| 多個條件分支 | ✗（只有一個 `DO UPDATE`，可加 `WHERE`） | **✓**（多個 `WHEN ... AND ...`） |
| 非等值 `ON` 條件 | ✗ | **✓** |
| 來源是另一張表 | ✓（`INSERT ... SELECT`） | ✓ |
| SQL 標準 | ✗（PostgreSQL 專屬） | **✓** |
| **併發安全** | **✓** | **✗** |

**`MERGE` 在語法能力上全面勝出，唯獨輸在併發安全** —— 而這一項通常是最重要的。

</details>

<details>
<summary>Hint 3 — B4 的完整回答</summary>

> 「我不同意全部改掉。
>
> **`MERGE` 和 `ON CONFLICT` 的併發保證不一樣。** `ON CONFLICT` 用 speculative insertion，在索引層處理衝突，兩個 session 同時 upsert 同一個鍵時會正確序列化。`MERGE` 是先查再決定分支，兩個 session 可能同時判定為 NOT MATCHED，然後其中一個撞唯一鍵失敗 —— 我實測過，同時跑兩個 MERGE 會有一個直接報 duplicate key。
>
> 所以我的建議是：**線上交易路徑（OLTP，會有併發）用 `ON CONFLICT`；批次 ETL（單一 job、不會併發）用 `MERGE`** —— 那裡 `MERGE` 的多分支和 `DELETE` 能力才真正有價值。
>
> 至於可移植性，我覺得站不住腳：我們不會換資料庫；而且 SQL Server 的 `MERGE` 有一長串已知 bug，Aaron Bertrand 有整理過，實務上大家也是避開的。**『標準語法』不等於『各家行為一致』。**」

</details>

<details>
<summary>Hint 4 — C3 的判準</summary>

> **`MERGE` 適合「批次、單一寫入者、需要多分支邏輯（含 DELETE）」的場景；**
> **`ON CONFLICT` 適合「線上、多併發寫入者、單純的存在即更新」的場景。**
>
> **判準是：這個語句會不會有兩個 session 同時針對同一個鍵執行？**
> 會 → `ON CONFLICT`。不會 → 兩個都行，看你需不需要 `MERGE` 的多分支能力。

**C2 的答案**：ETL 場景通常是**單一排程 job** 在跑，不會有第二個 process 同時 merge 同一批資料 —— 所以 `MERGE` 的併發弱點在這裡不構成風險，而它的多分支能力（一個語句同時處理新增/更新/刪除）反而讓程式碼簡潔很多。

用 `ON CONFLICT` 要達成同樣效果需要 **兩到三個語句**（一個 upsert、一個 delete），而且要小心它們之間的順序與交易邊界。

</details>
