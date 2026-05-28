# 練習題：UPSERT — user_id 存在則更新，不存在則插入

## Desc

給定 `user_logins` 表，記錄每個用戶的最後登入時間。請寫出一個 SQL 語句來處理以下登入事件：如果 `user_id` 已經在表中，就將其 `last_login` 更新為當下時間；如果 `user_id` 不存在，就插入一筆新的記錄。

此操作即 **UPSERT**（INSERT or UPDATE）。

> 提示：PostgreSQL 使用 `ON CONFLICT ... DO UPDATE`，MySQL 使用 `ON DUPLICATE KEY UPDATE`。本練習環境為 PostgreSQL，請使用對應語法。

## Table Schema + Testing Data

```sql
-- 建立 user_logins 表
CREATE TABLE user_logins (
    user_id   INT PRIMARY KEY,
    last_login TIMESTAMP NOT NULL
);

-- 初始化測試資料（假設已有 3 位用戶的登入記錄）
INSERT INTO user_logins (user_id, last_login) VALUES
    (1, '2026-05-20 10:00:00'),
    (2, '2026-05-21 14:30:00'),
    (3, '2026-05-22 09:15:00');

-- 現在模擬一個新的登入事件：
-- user_id = 2 再次登入 → 應更新其 last_login 為 NOW()
-- user_id = 4 首次登入 → 應插入新行 (4, NOW())
--
-- 請寫出一句 SQL 同時處理這兩種情況。
-- 預期最終表中應有 4 行：user_id 1, 2, 3, 4
-- 其中 user_id=2 的 last_login 被更新為執行當下的時間
-- user_id=4 被插入為新行
```

<br>

## 測試 SQL

執行你的 UPSERT 語句後，用以下查詢驗證結果：

```sql
SELECT * FROM user_logins ORDER BY user_id;
```

預期結果（時間為執行當下）：

```
 user_id |      last_login
---------+---------------------
       1 | 2026-05-20 10:00:00
       2 | <NOW()>
       3 | 2026-05-22 09:15:00
       4 | <NOW()>
```
