# 模擬幣安原題：Top-3 專案最多的部門 — Feedback

## Score: 7 / 10

## What's Good

- 正確使用 CTE + `ROW_NUMBER()` 做排名，思路清晰。
- `COUNT(DISTINCT ep.project_id)` 正確計算每個部門參與的**不同**專案數（同部門多員工參與同一專案只算一次）。
- `MAX(CASE WHEN rank = N THEN ... END)` 的 Pivot 寫法正確，成功將三行轉成一行橫向輸出。
- 使用 `LEFT JOIN` 而非 `INNER JOIN`，防禦性處理部門無員工或員工無專案的情況。

## What Can Be Improved

### 1. `LIMIT 3` 缺少 `ORDER BY`（主要問題）

```sql
group by d.department_name limit 3   -- ← 沒有 ORDER BY！
```

Window function 的 `ORDER BY` 控制的是排名邏輯，**不控制結果集的輸出順序**。`LIMIT 3` 在沒有顯式 `ORDER BY` 的情況下是非確定性的 — 某些查詢計劃下可能返回錯誤的三行（例如 rank 4, 2, 5 而非 rank 1, 2, 3）。

在這個測試案例中恰好正確，但這是巧合。修正方式任選其一：

- **加 ORDER BY**：`GROUP BY ... ORDER BY count(distinct ep.project_id) DESC LIMIT 3`
- **更乾淨的做法 — 直接拿掉 LIMIT**：外層的 `MAX(CASE WHEN rank = 1/2/3 ...)` 本身就只會匹配前三名，rank > 3 的行在 CASE 中返回 NULL，被 MAX 忽略。多餘的 `LIMIT 3` 反而引入風險。如果擔心可讀性，可在外層加 `WHERE cte.rank <= 3`。

### 2. 輸出欄位名稱與題目不符

題目預期輸出欄位為 `1st`、`2nd`、`3rd`，答案使用 `one`、`two`、`three`。PostgreSQL 中數字開頭的欄位名需要雙引號 `"1st"`，面試時兩種寫法都可以但要能說明。

### 3. 格式化細節

CTE 中混用了中文命名風格（`one/two/three`）與英文關鍵字，建議保持一致。另外 `left join` 使用了兩個關鍵字但沒有對齊，格式化可以更整齊。

## 建議重寫版本

```sql
with ranked as (
    select d.department_name,
           row_number() over (order by count(distinct ep.project_id) desc) as rk
    from department d
    left join employee e on e.department_id = d.department_id
    left join employee_project ep on ep.employee_id = e.employee_id
    group by d.department_name
)
select max(case when rk = 1 then department_name end) as "1st",
       max(case when rk = 2 then department_name end) as "2nd",
       max(case when rk = 3 then department_name end) as "3rd"
from ranked
where rk <= 3;
```

關鍵改動：去掉 CTE 裡的 `LIMIT 3`，改用外層 `WHERE rk <= 3` — 既安全又語意明確。

想再試一版嗎？
