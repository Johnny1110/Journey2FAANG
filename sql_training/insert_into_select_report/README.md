# 練習題：INSERT INTO ... SELECT — 把統計結果寫入報表表

## Desc

你正在維護一個電商平台的數據報表系統。每天凌晨需要從交易表中計算前一天的營運統計，並將結果寫入 `daily_sales_report` 報表表，供 BI 儀表板使用。

請撰寫一句 `INSERT INTO ... SELECT` 語句，從 `orders` + `order_items` 兩張表中計算指定日期的統計指標，並寫入報表表。

### 需求規格

給定一個日期（例如 `2026-05-27`），計算以下指標並 INSERT 到 `daily_sales_report`：

| 欄位 | 說明 | 計算方式 |
|------|------|---------|
| `report_date` | 報表日期 | 給定的日期 |
| `total_orders` | 總訂單數 | 該日期的訂單總數 |
| `total_revenue` | 總營收 | 該日期所有訂單的 `quantity * unit_price` 加總 |
| `total_items_sold` | 總商品銷售數 | 該日期所有訂單的 `quantity` 加總 |
| `avg_order_value` | 平均客單價 | `total_revenue / total_orders`，若無訂單則為 0 |

> 提示：你需要 JOIN `orders` 和 `order_items`，用 `GROUP BY` 聚合，再將結果 `INSERT INTO` 報表表。注意處理當天無訂單的邊界情況。

## Table Schema + Testing Data

```sql
-- 訂單主表
CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date  DATE NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'completed'
);

-- 訂單明細表
CREATE TABLE order_items (
    item_id    SERIAL PRIMARY KEY,
    order_id   INT NOT NULL REFERENCES orders(order_id),
    product_id INT NOT NULL,
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL
);

-- 日營收報表表（目標寫入表）
CREATE TABLE daily_sales_report (
    report_date      DATE PRIMARY KEY,
    total_orders     INT NOT NULL DEFAULT 0,
    total_revenue    NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_items_sold INT NOT NULL DEFAULT 0,
    avg_order_value  NUMERIC(10, 2) NOT NULL DEFAULT 0
);

-- 初始化測試資料
INSERT INTO orders (order_id, customer_id, order_date, status) VALUES
    (1, 101, '2026-05-27', 'completed'),
    (2, 102, '2026-05-27', 'completed'),
    (3, 103, '2026-05-27', 'completed'),
    (4, 101, '2026-05-28', 'completed'),   -- 另一天的訂單，不應被計入
    (5, 104, '2026-05-27', 'cancelled');    -- 已取消訂單

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1, 201, 2, 150.00),   -- order#1: 2*150 = 300
    (1, 202, 1, 200.00),   -- order#1: 1*200 = 200  → order#1 總計 500
    (2, 201, 3, 150.00),   -- order#2: 3*150 = 450  → order#2 總計 450
    (3, 203, 1, 800.00),   -- order#3: 1*800 = 800  → order#3 總計 800
    (3, 204, 2, 100.00),   -- order#3: 2*100 = 200  → order#3 總計 1000
    (4, 201, 1, 150.00),   -- order#4: 1*150 = 150（5/28，不計入）
    (5, 205, 1, 500.00);   -- order#5: cancelled，視需求決定是否計入
```

> **關於 cancelled 訂單**：請根據你的商業邏輯決定是否納入統計。若你選擇排除 cancelled 訂單，記得在 WHERE 條件中過濾。兩種做法都可以，但在面試中要講清楚你的假設。

<br>

## 預期結果

針對 `2026-05-27`，假設**只統計 completed 訂單**（排除 cancelled）：

| report_date | total_orders | total_revenue | total_items_sold | avg_order_value |
|-------------|-------------|---------------|-----------------|-----------------|
| 2026-05-27  | 3           | 1950.00       | 9               | 650.00          |

計算過程：
- total_orders = 3（order_id 1, 2, 3）
- order#1: 2×150 + 1×200 = 500，共 3 件商品
- order#2: 3×150 = 450，共 3 件商品
- order#3: 1×800 + 2×100 = 1000，共 3 件商品
- total_revenue = 500 + 450 + 1000 = 1950.00
- total_items_sold = 3 + 3 + 3 = 9
- avg_order_value = 1950.00 / 3 = 650.00

<br>

## 測試 SQL

執行你的 INSERT 語句後，用以下查詢驗證：

```sql
SELECT * FROM daily_sales_report WHERE report_date = '2026-05-27';
```

<br>

## 進階挑戰

1. **處理無訂單的日期**：若某天完全沒有訂單，你的 SQL 還能正確插入一筆 `total_orders = 0` 的記錄嗎？如果不能，該怎麼改？
2. **避免重複插入**：如果排程腳本不小心執行了兩次，如何避免報表表中出現重複資料？（提示：`ON CONFLICT`）
3. **一次插入多天**：如果要一次生成整個月的報表，你的 SQL 需要怎麼調整？
