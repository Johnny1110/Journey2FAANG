# Phase 6-06 — Deduplicate a 10M-Row Table

> **難度**：★★★★★
> **核心技巧**：`ctid`、分批刪除、鎖持有時間、線上 DDL
> **對應基礎題**：[LC 196. Delete Duplicate Emails](../../../sql_training/delete_duplicate_emails)（你當初的表只有 10 列）

<br>

---

<br>

## Interview Context

> *面試官：*「你在基礎訓練寫過『刪除重複的 email，保留 id 最小的那筆』。
>
> ```sql
> DELETE FROM person WHERE id NOT IN (SELECT MIN(id) FROM person GROUP BY email);
> ```
>
> 很好。現在這張表有 **1000 萬列**，其中 300 萬是重複的，而且**線上服務正在讀寫它**。
>
> 你把這一句貼進正式環境，會發生什麼事？」

<br>

**這一題的正確答案不是一句 SQL。** 它考的是：你知不知道一句「正確的 SQL」在正式環境會造成什麼傷害。

<br>

---

<br>

## Table Schema & Testing Data

```sql
DROP TABLE IF EXISTS contacts;

CREATE TABLE contacts (
    id         SERIAL PRIMARY KEY,
    email      TEXT NOT NULL,
    name       TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- 50 萬列，20 萬個不重複 email（每個 email 平均 2.5 筆）
INSERT INTO contacts (email, name)
SELECT 'user' || (g % 200000) || '@example.com', 'name_' || g
FROM generate_series(1, 500000) g;

ANALYZE contacts;
```

> 用 50 萬列而不是 1000 萬 —— 效果一樣，但你的筆電不會哭。
> 想加壓的話把 `500000` 改成 `5000000`。

<br>

驗證起始狀態：

```sql
SELECT count(*) AS rows, count(DISTINCT email) AS distinct_emails FROM contacts;
--  rows=500000  distinct_emails=200000
```

<br>

---

<br>

## Part A — 天真版的代價

### A1

跑一次基礎版：

```sql
EXPLAIN (ANALYZE, BUFFERS)
DELETE FROM contacts WHERE id NOT IN (SELECT MIN(id) FROM contacts GROUP BY email);
```

（先 `BEGIN;` 再跑，看完 `ROLLBACK;` —— 這樣可以重複測試。）

回答：
- 執行計畫長什麼樣？
- 花多久？讀了多少 buffer？
- `NOT IN` 在這裡安全嗎？（`id` 是主鍵不會是 NULL —— 但 [Phase 1-01](../../phase-1-join-dark-side/01-the-null-that-ate-your-results) 的習慣要保持）

### A2 — 鎖的問題

**這才是重點。** 回答：

- 這個 `DELETE` 會鎖住什麼？鎖多久？
- 在它跑的這段時間，其他 session 能不能：
  - `SELECT` 這張表？
  - `UPDATE` 其中一列？
  - `INSERT` 新資料？
- **300 萬列的刪除會產生多少 WAL？** 對複本延遲（replication lag）有什麼影響？
- 如果跑到一半失敗了會怎樣？

### A3 — 更好的刪除條件

用 `ctid` 自連接改寫：

```sql
EXPLAIN (ANALYZE, TIMING OFF)
DELETE FROM contacts a USING contacts b
WHERE a.email = b.email AND a.ctid > b.ctid;
```

回答：
- `ctid` 是什麼？它和 `id` 有什麼不同？
- 為什麼可以用 `ctid` 比大小？
- 這個寫法保留的是哪一筆？和「保留 id 最小」一樣嗎？**如果不一樣，重要嗎？**
- 執行計畫和 A1 比如何？（**注意估計的列數** —— 你會看到一個嚇人的數字）

<br>

---

<br>

## Part B — 分批刪除

### B1 — 為什麼要分批

回答：一次刪 300 萬列 vs 分 3000 批每批 1000 列，在以下面向各是什麼差別：

| | 一次刪完 | 分批刪 |
|---|---|---|
| 總執行時間 | ? | ? |
| 單次鎖持有時間 | ? | ? |
| 對線上服務的影響 | ? | ? |
| WAL 產生速度 | ? | ? |
| 失敗時的損失 | ? | ? |
| autovacuum 的壓力 | ? | ? |

### B2 — 寫出分批刪除

```sql
WITH doomed AS (
    SELECT ctid FROM (
        SELECT ctid, ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
        FROM contacts
    ) t
    WHERE rn > 1
    LIMIT 1000
)
DELETE FROM contacts c USING doomed d WHERE c.ctid = d.ctid;
```

跑一次，確認刪掉 1000 列。

回答：
- `ROW_NUMBER() OVER (PARTITION BY email ORDER BY id)` 決定了保留哪一筆？
- 為什麼用 `ctid` 當刪除的目標而不是 `id`？
- **這個查詢每一批都要重新掃描整張表算 `ROW_NUMBER`。** 這是問題嗎？怎麼改善？

### B3 — 迴圈

寫出完整的分批刪除流程（PL/pgSQL 或外部腳本），要求：

- 每批 1000 列
- 每批之間 `COMMIT`（**為什麼很重要？**）
- 每批之間 sleep 一小段時間（**為什麼？**）
- 回報進度
- 可以中斷後續跑

### B4 — 更快的做法：重建表

當重複比例很高時（本題 60% 是重複的），**建新表比刪舊資料快**：

```sql
CREATE TABLE contacts_new (LIKE contacts INCLUDING ALL);
INSERT INTO contacts_new SELECT DISTINCT ON (email) * FROM contacts ORDER BY email, id;
-- 然後 rename
```

回答：
- 為什麼這樣比較快？（提示：想想 `DELETE` 留下的死 tuple）
- `DISTINCT ON` 在這裡做什麼？（[Phase 2-04](../../phase-2-aggregation-limits/04-the-mode-that-ties) 說過它的定位）
- **rename 的那一瞬間，線上服務會發生什麼事？**
- 從 `INSERT INTO contacts_new` 開始到 rename 完成，這段期間寫入舊表的新資料怎麼辦？

<br>

---

<br>

## Part C — 善後

### C1 — 死 tuple 與 VACUUM

`DELETE` 之後，磁碟空間有變小嗎？跑跑看：

```sql
SELECT pg_size_pretty(pg_total_relation_size('contacts'));
```

回答：
- PostgreSQL 的 `DELETE` 實際上做了什麼？（提示：MVCC）
- `VACUUM` 和 `VACUUM FULL` 差在哪？
- **`VACUUM FULL` 會鎖住整張表** —— 那正式環境怎麼辦？
- `pg_repack` 是什麼？

### C2 — 防止再次發生

去重完之後，怎麼確保不會再出現重複？

```sql
CREATE UNIQUE INDEX CONCURRENTLY uniq_contacts_email ON contacts (email);
```

回答：
- `CONCURRENTLY` 做什麼？為什麼正式環境一定要加？
- 它的代價是什麼？（提示：要掃兩次、不能在交易裡跑、失敗會留下無效索引）
- 建索引期間如果有人插入重複資料會怎樣？
- **無效索引怎麼清理？**

### C3 — 完整的 runbook

把整個流程寫成一份**可以交給同事執行的操作手冊**：

1. 前置檢查（確認重複量、估計時間、確認離峰時段）
2. 備份 / 可回滾方案
3. 分批刪除
4. 驗證
5. `VACUUM`
6. 建唯一索引
7. 事後驗證

**每一步都要寫出「怎麼判斷這一步成功了」和「失敗了怎麼辦」。**

<br>

---

<br>

## Part D — 更根本的問題

### D1

回答：這些重複資料是**怎麼進來的**？

列出至少三種可能，並各自說明對應的預防方式：
- 應用層 bug
- 沒有唯一約束
- 重試 / webhook 重送（[6-01](../01-the-idempotent-upsert) 的場景）
- 資料匯入

### D2

回答：如果你是這個系統的架構師，你會在**哪一層**防止重複？為什麼？

**寫出這句結論**：資料清理是 `______`，唯一約束是 `______`。

<br>

---

<br>

## 面試官的追問

> 1. 「`ctid` 會變嗎？什麼情況下會變？用它當刪除目標安全嗎？」
>
> 2. 「刪除 300 萬列會產生多少 WAL？怎麼估？」
>
> 3. 「如果這張表有外鍵指向它，刪除會有什麼額外成本？」
>
> 4. 「`DELETE` vs `TRUNCATE` vs `DROP` 的鎖等級和可回滾性？」

<br>

---

<br>

## Hints

<details>
<summary>Hint 1 — ctid 是什麼</summary>

`ctid` 是每一列的**實體位置**：`(page_number, tuple_index)`。它是 PostgreSQL 的系統欄位，每張表都有。

```sql
SELECT ctid, id, email FROM contacts LIMIT 3;
--  (0,1) | 1 | user1@example.com
--  (0,2) | 2 | user2@example.com
```

**為什麼刪除時用 `ctid` 比 `id` 好**：`ctid` 直接指向實體位置，資料庫不需要走索引就能找到那一列 —— **是最快的定位方式**。

**⚠️ 但它會變**（追問 1 的答案）：`UPDATE` 會讓該列搬到新位置（MVCC 的 `UPDATE` = 舊版本標記刪除 + 寫入新版本），`VACUUM FULL` / `pg_repack` 會重整整張表。

**所以 `ctid` 只能在單一交易/短時間內使用**，絕對不能存起來當作長期識別碼。本題的用法（在同一個語句裡先查出 `ctid` 再刪）是安全的。

**A3 的保留規則**：`a.ctid > b.ctid` 保留的是**實體位置最前面**的那一筆，不一定是 `id` 最小的那一筆。多數情況下兩者相同（插入順序 = 實體順序），但被 `UPDATE` 過的列會搬家。**如果業務上一定要「保留最早建立的」，就得用 `ROW_NUMBER() ORDER BY id`（B2 的寫法）。**

</details>

<details>
<summary>Hint 2 — 鎖與 WAL</summary>

`DELETE` 取得的是 **`ROW EXCLUSIVE`** 表鎖 + 每一列的行鎖。

`ROW EXCLUSIVE` **不會**擋掉 `SELECT`（讀不阻塞寫、寫不阻塞讀，這是 MVCC 的核心優勢），也不會擋掉其他 `INSERT`/`UPDATE`/`DELETE`（除非碰到同一列）。

**所以問題不是「服務完全停擺」，而是**：

1. **長交易**：一個跑 20 分鐘的 `DELETE` 會讓 autovacuum 在這 20 分鐘內無法清理任何比它更新的死 tuple → 表膨脹
2. **WAL 洪水**：300 萬列的刪除產生大量 WAL → 複本延遲飆高 → 讀取複本的服務讀到過期資料
3. **失敗全滾**：跑了 19 分鐘後失敗 → 全部回滾 → 白做，而且回滾本身也要時間
4. **鎖累積**：交易持有 300 萬個行鎖，佔用共享記憶體

**分批的核心價值是把「一個巨大的長交易」變成「很多個短交易」** —— 每一批提交後鎖就釋放了，autovacuum 追得上，失敗只損失一批。

</details>

<details>
<summary>Hint 3 — 分批迴圈</summary>

```sql
DO $$
DECLARE
    deleted INT;
    total   INT := 0;
BEGIN
    LOOP
        WITH doomed AS (
            SELECT ctid FROM (
                SELECT ctid, ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) AS rn
                FROM contacts
            ) t WHERE rn > 1 LIMIT 1000
        )
        DELETE FROM contacts c USING doomed d WHERE c.ctid = d.ctid;

        GET DIAGNOSTICS deleted = ROW_COUNT;
        total := total + deleted;
        RAISE NOTICE 'deleted % (total %)', deleted, total;

        EXIT WHEN deleted = 0;
        COMMIT;                       -- ← DO 區塊裡的 COMMIT 需要 PG 11+
        PERFORM pg_sleep(0.1);        -- ← 讓出 I/O 給線上服務
    END LOOP;
END $$;
```

**為什麼每批要 `COMMIT`**：不提交的話所有批次還是在同一個交易裡，等於沒分批 —— 鎖一樣持有到最後、WAL 一樣不能回收、失敗一樣全滾。

**為什麼要 `pg_sleep`**：連續全速刪除會把 I/O 吃滿，線上查詢的延遲會飆高。停一下讓出資源，也讓 autovacuum 有機會跟上。這叫 **throttling**。

**B2 的效能問題**：每一批都要重新對整張表算 `ROW_NUMBER` —— 50 萬列還好，5000 萬列就會變成每批都要幾十秒。

**改善**：先把要刪的 `ctid` 一次算好存進暫存表，再分批從暫存表取：

```sql
CREATE TEMP TABLE doomed_ctids AS
SELECT ctid FROM (SELECT ctid, ROW_NUMBER() OVER (PARTITION BY email ORDER BY id) rn FROM contacts) t
WHERE rn > 1;
```

（但這樣 `ctid` 就有過期風險 —— 如果刪除期間有人 `UPDATE` 那些列。取捨。）

</details>

<details>
<summary>Hint 4 — CONCURRENTLY 與最終結論</summary>

**`CREATE INDEX CONCURRENTLY`**：

- 普通 `CREATE INDEX` 取得 `SHARE` 鎖 → **擋掉所有寫入**，大表可能鎖幾十分鐘
- `CONCURRENTLY` 不擋寫入，代價是：
  - **掃兩次表**（總時間更長）
  - **不能在交易區塊內執行**
  - **失敗會留下 `INVALID` 索引**，必須手動 `DROP INDEX` 清掉

找出無效索引：

```sql
SELECT indexrelid::regclass AS idx, indrelid::regclass AS tbl
FROM pg_index WHERE NOT indisvalid;
```

**建索引期間有人插入重複資料** → 索引建立會在第二次掃描時失敗 → 留下無效索引 → 所以**必須先確定去重乾淨、而且來源已經停止產生重複**，才建索引。

**D2 的結論**：

> **資料清理是「治標」，唯一約束是「治本」。**

清理只處理已經發生的問題，而且下一秒就可能再髒。約束讓「重複」這個狀態**在資料庫層面無法存在** —— 不管是應用層 bug、手動 SQL、還是資料匯入，全部擋掉。

**正確的順序永遠是：先清理 → 再加約束 → 然後才修應用層。**
反過來（先修應用層再慢慢清）的話，你永遠不知道還有沒有漏網之魚在寫入。

（這和 [Phase 1-02](../../phase-1-join-dark-side/02-price-tier-assignment)、[Phase 1-06](../../phase-1-join-dark-side/06-the-self-join-that-counted-twice)、[6-03](../03-preventing-double-booking) 的「讓錯誤狀態無法被表達」是同一條線。）

</details>
