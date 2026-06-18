# LC 1795. Rearrange Products Table

## Desc

Table: `Products`

```
+-------------+---------+
| Column Name | Type    |
+-------------+---------+
| product_id  | int     |
| store1      | int     |
| store2      | int     |
| store3      | int     |
+-------------+---------+
```

product_id is the primary key.
Each row stores the product's price in 3 different stores (store1, store2, store3). If the product is not available in a store, the price will be `null`.

Write an SQL query to **rearrange** the table so that each row has `(product_id, store, price)`. If a product is not available in a store, **do not include** that row in the result.

Return the result table in **any order**.

## Table Schema + Testing Data

```sql
drop table if exists products;
create table products
(
    product_id int primary key,
    store1     int,
    store2     int,
    store3     int
);

insert into products (product_id, store1, store2, store3)
values (0, 95, 100, 105),
       (1, 70, null, 80);
```

## Expected Output

```
+-------------+--------+-------+
| product_id  | store  | price |
+-------------+--------+-------+
| 0           | store1 | 95    |
| 0           | store2 | 100   |
| 0           | store3 | 105   |
| 1           | store1 | 70    |
| 1           | store3 | 80    |
+-------------+--------+-------+
```

### Hint

This is the reverse of LC 1777 — an **Unpivot** using `UNION ALL`. Filter out `NULL` prices so missing stores don't appear.
