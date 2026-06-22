# 模擬幣安原題：Top-3 專案最多的部門（橫向輸出）

## Desc

給定四張表：部門（department）、員工（employee）、專案（project）、員工專案關聯（employee_project）。每位員工屬於一個部門，員工可以參與多個專案，一個專案也可以被多個員工參與。

**任務**：找出參與「不同專案數量」最多的前 3 名部門，並以**橫向格式**輸出。

- 同一個部門的不同員工參與同一個專案，只算一次。
- 不考慮並列情況（假設專案數量都不相同）。
- 輸出格式為三個欄位：`1st`、`2nd`、`3rd`，分別放第一、第二、第三名的部門名稱。

## Table Schema + Testing Data

```sql
drop table if exists employee_project;
drop table if exists employee;
drop table if exists project;
drop table if exists department;

create table department
(
    department_id   int primary key,
    department_name varchar(50) not null
);

create table employee
(
    employee_id   int primary key,
    employee_name varchar(50) not null,
    department_id int not null references department (department_id)
);

create table project
(
    project_id   int primary key,
    project_name varchar(50) not null
);

create table employee_project
(
    employee_id int not null references employee (employee_id),
    project_id  int not null references project (project_id),
    primary key (employee_id, project_id)
);

-- ========== Testing Data ==========

insert into department (department_id, department_name)
values (1, 'ADMIN'),
       (2, 'PAYMENT'),
       (3, 'CORE'),
       (4, 'INFRA'),
       (5, 'DATA');

insert into employee (employee_id, employee_name, department_id)
values (1, 'Alice', 1),
       (2, 'Bob', 2),
       (3, 'Charlie', 3),
       (4, 'Diana', 4),
       (5, 'Eve', 5);

insert into project (project_id, project_name)
values (1, 'Project-Alpha'),
       (2, 'Project-Beta'),
       (3, 'Project-Gamma'),
       (4, 'Project-Delta'),
       (5, 'Project-Epsilon'),
       (6, 'Project-Zeta'),
       (7, 'Project-Eta'),
       (8, 'Project-Theta'),
       (9, 'Project-Iota'),
       (10, 'Project-Kappa');

-- Alice (ADMIN): P1~P7 → 7 distinct projects
insert into employee_project (employee_id, project_id)
values (1, 1),
       (1, 2),
       (1, 3),
       (1, 4),
       (1, 5),
       (1, 6),
       (1, 7);

-- Bob (PAYMENT): P1~P10 → 10 distinct projects
insert into employee_project (employee_id, project_id)
values (2, 1),
       (2, 2),
       (2, 3),
       (2, 4),
       (2, 5),
       (2, 6),
       (2, 7),
       (2, 8),
       (2, 9),
       (2, 10);

-- Charlie (CORE): P3~P7 → 5 distinct projects
insert into employee_project (employee_id, project_id)
values (3, 3),
       (3, 4),
       (3, 5),
       (3, 6),
       (3, 7);

-- Diana (INFRA): P6~P9 → 4 distinct projects
insert into employee_project (employee_id, project_id)
values (4, 6),
       (4, 7),
       (4, 8),
       (4, 9);

-- Eve (DATA): P1, P3 → 2 distinct projects
insert into employee_project (employee_id, project_id)
values (5, 1),
       (5, 3);
```

## Expected Output

```
+---------+-------+------+
| 1st     | 2nd   | 3rd  |
+---------+-------+------+
| PAYMENT | ADMIN | CORE |
+---------+-------+------+
```

## Hint

這題分兩步：

1. **找出每個部門參與了多少不同的專案**：`count(distinct project_id)`，透過 JOIN employee 取得部門資訊。
2. **將前三名轉成橫向格式**：可以使用 `ROW_NUMBER()` 排名後，搭配 `MAX(CASE WHEN ... THEN ... END)` 做 Pivot；或者用子查詢 + `LIMIT OFFSET` 分別取出第 1、2、3 名後再拼成一行。
