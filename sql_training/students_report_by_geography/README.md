# LC 618. Students Report By Geography

<br>

---

<br>

## Desc

A U.S. graduate school has students from Asia, Europe and America. Write a query to pivot the continent column so that each student name is sorted alphabetically and displayed under its corresponding continent. The output headers should be `America`, `Asia`, `Europe`. Students with the same row number (based on alphabetical order within their continent) appear in the same row.

**Input:**

Table: `student`

| Column Name | Type    |
|-------------|---------|
| name        | varchar |
| continent   | varchar |

**Output:**

| America | Asia | Europe |
|---------|------|--------|
| ...     | ...  | ...    |

- The rows should be ordered so that the students from each continent are listed in alphabetical order, with the first row containing the first student from each continent, the second row containing the second student from each continent, and so on.
- If one continent has fewer students, output `NULL` for the missing positions.

<br>

## Table Schema + Testing Data

```sql
create table student (
    name      varchar(50) not null,
    continent varchar(10) not null
);

insert into student (name, continent)
values ('Jack', 'America'),
       ('Pascal', 'Europe'),
       ('Xi', 'Asia'),
       ('Jane', 'America'),
       ('Max', 'America'),
       ('Anna', 'Europe'),
       ('Mei', 'Asia'),
       ('Wei', 'Asia'),
       ('Luis', 'America'),
       ('Sofia', 'Europe'),
       ('Carlos', 'America'),
       ('Lucia', 'Europe'),
       ('Jin', 'Asia'),
       ('Yuki', 'Asia'),
       ('Emma', 'Europe'),
       ('Olivia', 'America'),
       ('Noah', 'Europe'),
       ('Leo', 'Asia'),
       ('Mia', 'America'),
       ('Hans', 'Europe');
```
