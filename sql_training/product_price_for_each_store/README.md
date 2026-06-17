# LC 1777. Product's Price for Each Store

## Desc

Table: `Products`

```
+-------------+---------+
| Column Name | Type    |
+-------------+---------+
| product_id  | int     |
| store       | enum    |
| price       | int     |
+-------------+---------+
```

(product_id, store) is the composite primary key.
store is an ENUM of type ('store1', 'store2', 'store3') — each row records the price of a product at a specific store.

Write an SQL query to **reformat the table** so that each product_id occupies exactly one row, with three columns for the three stores:

```
+-------------+--------+--------+--------+
| product_id  | store1 | store2 | store3 |
+-------------+--------+--------+--------+
```

If a product is not sold in a particular store, show `null` for that column.

Return the result table in **any order**.

## Table Schema + Testing Data

```sql
drop table if exists products;
create table products
(
    product_id int,
    store      varchar(10),
    price      int,
    primary key (product_id, store)
);

insert into products (product_id, store, price)
values (0, 'store1', 95),
       (0, 'store3', 105),
       (0, 'store2', 100),
       (1, 'store1', 70),
       (1, 'store3', 80);
```

## Expected Output

```
+-------------+--------+--------+--------+
| product_id  | store1 | store2 | store3 |
+-------------+--------+--------+--------+
| 0           | 95     | 100    | 105    |
| 1           | 70     | null   | 80     |
+-------------+--------+--------+--------+
```

### Hint

This is the same Pivot pattern as LC 1179: `CASE WHEN` + aggregation + `GROUP BY`. The difference is only 3 pivot columns instead of 12.
