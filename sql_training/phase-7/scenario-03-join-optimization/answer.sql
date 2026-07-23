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