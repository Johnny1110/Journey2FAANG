# Feedback: UPSERT — user_id 存在則更新，不存在則插入

## Score: 9 / 10

---

## What's Good

- **`ON CONFLICT ... DO UPDATE`** 是 PostgreSQL 標準 UPSERT 語法，用 `user_id`（PRIMARY KEY）作為衝突判斷欄位，完全正確。
- **`?` 佔位符** 表示你考慮到了 parameterized query，這是實際開發中的好習慣，可以防止 SQL injection。
- **`now()`** 用 PostgreSQL 內建函數取得當前時間，語法簡潔。
- 整句 SQL 一行搞定，沒有多餘的東西，乾淨俐落。

## 小提醒（不扣分）

`now()` 在 `VALUES` 和 `DO UPDATE SET` 中各被呼叫一次，兩次執行的時間理論上有極微小的差距（毫秒級）。如果在意「插入和更新使用完全相同的時間戳」，可以用 `EXCLUDED.last_login` 在 UPDATE 中引用 VALUES 裡的值：

```sql
INSERT INTO user_logins (user_id, last_login)
VALUES (?, now())
ON CONFLICT (user_id) DO UPDATE SET last_login = EXCLUDED.last_login;
```

不過這屬於吹毛求疵的級別，面試中你當前的寫法完全過關。
