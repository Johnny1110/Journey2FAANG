# LC 1179. Reformat Department Table

## Desc

Table: `Department`

```
+-------------+---------+
| Column Name | Type    |
+-------------+---------+
| id          | int     |
| revenue     | int     |
| month       | varchar |
+-------------+---------+
```

(id, month) 是複合主鍵。

表格記錄每個部門每個月的收入（month 的值為 Jan, Feb, ..., Dec 共 12 種縮寫）。

請將表格重新格式化，使得 **每個 id 只佔一行**，並將 12 個月的收入分別展開為 12 個欄位：

```
+------+-------------+-------------+-------------+-----+-------------+
| id   | Jan_Revenue | Feb_Revenue | Mar_Revenue | ... | Dec_Revenue |
+------+-------------+-------------+-------------+-----+-------------+
```

若某個 id 在某個月沒有收入記錄，則該欄位顯示 `null`。

## Table Schema + Testing Data

```sql
drop table if exists department;
create table department
(
    id      int,
    revenue int,
    month   varchar(3),
    primary key (id, month)
);

insert into department (id, revenue, month)
values (1, 8000, 'Jan'),
       (2, 9000, 'Jan'),
       (3, 10000, 'Feb'),
       (1, 7000, 'Feb'),
       (1, 6000, 'Mar');
```

## Expected Output

```
+------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+
| id   | Jan_Revenue | Feb_Revenue | Mar_Revenue | Apr_Revenue | May_Revenue | Jun_Revenue | Jul_Revenue | Aug_Revenue | Sep_Revenue | Oct_Revenue | Nov_Revenue | Dec_Revenue |
+------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+
| 1    | 8000        | 7000        | 6000        | null        | null        | null        | null        | null        | null        | null        | null        | null        |
| 2    | 9000        | null        | null        | null        | null        | null        | null        | null        | null        | null        | null        | null        |
| 3    | null        | 10000       | null        | null        | null        | null        | null        | null        | null        | null        | null        | null        |
+------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+-------------+
```

### Hint

和 LC 618 一樣是 Pivot 題型（`CASE WHEN` + 聚合函數 + `GROUP BY`），但這次 pivot key 不是 ROW_NUMBER，而是 id 本身。
