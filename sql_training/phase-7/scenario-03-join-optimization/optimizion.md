# 優化

```
-- Scenario 03: The Daily Report That Times Out
-- Your diagnosis, index DDL, and expected plan changes go here.
--
-- 1. Bottleneck identification from EXPLAIN output:
-- There are 2 Seq Scan on order_items and products both tables.
-- We don't have any index in those 3 tables for this reporting quert scenario, we should
-- We should design index for this query.

-- 2. Index DDL (at least 2 CREATE INDEX statements with justification):

CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_order_items_product_id＿order_id ON order_items(product_id, order_id);

-- 3. Expected plan change after indexing (what replaces the Nested Loop?):
-- Bitmap Heap Scan on orders
-- Bitmap Index Scan on idx_orders_created_at

-- 4. (Optional) Covering index suggestion:
-- I have no idea.
```

> score: 65/100

<br>

## 第一件事情：不要先想 index

很多人看到 SQL optimization 就開始寫

```
CREATE INDEX ...
```

但是真正的流程應該永遠都是

```
EXPLAIN ANALYZE
↓
找最花時間的 Node
↓
找為什麼 Planner 只能選這個 Plan
↓
最後才決定 index
```

<br>
<br>

## Step 1. 找最大的 Bottleneck

你的回答：

> There are 2 Seq Scan...

真正要看的是 actual time。

例如:

```
Nested Loop
(actual time=456..27801)
```

代表 __27.8 秒__ 都花在 Nested Loop。

<br>

然後往下一層看。

```
Seq Scan orders
127 ms

Seq Scan products
24 ms
```

這兩個都不算慢，真正慢的是這個：

```
Seq Scan order_items

27.891..30.812
loops=897
```

Seq Scan 總耗時為 897*30.812=27638.364 (27.6 秒)

這個意思是：

```
找到一個 order
↓
掃一次 order_items 全表 (30 ms)
↓
找到第二個 order
↓
再掃一次
↓
...

897 次
```

所以真正 bottleneck 不是 `Seq Scan` 而是 `Nested Loop + Seq Scan order_items`

<br>
<br>

## Step2. 為什麼 Planner 只能這樣？

看看 join `oi.order_id = o.id`, order_items 只有 `PRIMARY KEY(id)` 沒有 `order_id`

所以 PostgreSQL 沒辦法

```
order_id = ?
↓
Index Scan
```

只能

```
Seq Scan order_items
```

所以第一個 index 應該是

```
CREATE INDEX idx_order_items_order_id
ON order_items(order_id);
```

<br>
<br>

## Step3. products 要不要 index？

我回答建立了 idx_products_category，因為 query 根本沒有 `WHERE category='Books'` 所以 Planner 根本不會用。

Join 是 `p.id = oi.product_id` 而 `p.id` 已經是 PK 了，所以 index `products(category)` 沒用．

<br>
<br>

## Step4. orders index

index `created_at` 是對的，但是可以更好．

因為 query 是：

```
WHERE
created_at
status
```

所以比較好的做法是：

```
CREATE INDEX idx_orders_created_status
ON orders(created_at, status);
```

<br>
<br>

## Step5. order_items index

我寫 `(product_id, order_id)` 請參考 __Step2__

寫成 `(order_id, product_id)` 比較合理，因為至少會觸發到 order_id index scan.

<br>
<br>

＃# Step6. Expected Plan

我回答:

```
Bitmap Heap Scan
Bitmap Index Scan
```

只回答一半，真正最大的改變是:


```
Seq Scan orders
↓
Nested Loop
↓
Seq Scan order_items
```

優化成：

```
Bitmap Index Scan orders
↓
Bitmap Heap Scan orders
↓
Index Scan order_items(order_id)
↓
Hash Join products
```

<br>
<br>

## Step7. Covering Index

例如 order_items 最後需要：

```
order_id
product_id
quantity
unit_price
```

可以

```
CREATE INDEX idx_order_items_report
ON order_items(order_id)
INCLUDE (
    product_id,
    quantity,
    unit_price
);
```

這樣就不用回表查詢，直接在 B+ Tree 索引表上就能查到所需資料．直接 `Index Only Scan`

<br>
<br>

## Step8. 還可以再優化嗎？

* 做一個 Summary Table 每天跑 ETL，這樣就不用 join 大量資料查詢．針對該 summary 表做 report 就行了．
* Partition: orders 表依照 `created_at` 做 partition，昨天報表只 select 昨天的 partion．
