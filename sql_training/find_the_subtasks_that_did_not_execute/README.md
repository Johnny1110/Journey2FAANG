# LC 1767. Find the Subtasks That Did Not Execute

<br>

---

<br>

## Desc

Table: `Tasks`

```
+----------------+---------+
| Column Name    | Type    |
+----------------+---------+
| task_id        | int     |
| subtasks_count | int     |
+----------------+---------+

task_id is the primary key for this table.
Each row in this table indicates that task_id was divided into subtasks_count subtasks labelled from 1 to subtasks_count.
It is guaranteed that 2 <= subtasks_count <= 20.
```


 
<br>

Table: `Executed`

```
+---------------+---------+
| Column Name   | Type    |
+---------------+---------+
| task_id       | int     |
| subtask_id    | int     |
+---------------+---------+

(task_id, subtask_id) is the primary key for this table.
Each row in this table indicates that for the task task_id, the subtask with ID subtask_id was executed successfully.
It is guaranteed that subtask_id <= subtasks_count for each task_id.
Write an SQL query to report the IDs of the missing subtasks for each task_id.
```

<br>

Return the result table in any order.

The query result format is in the following example:

```
Tasks table:
+---------+----------------+
| task_id | subtasks_count |
+---------+----------------+
| 1       | 3              |
| 2       | 2              |
| 3       | 4              |
+---------+----------------+

Executed table:
+---------+------------+
| task_id | subtask_id |
+---------+------------+
| 1       | 2          |
| 3       | 1          |
| 3       | 2          |
| 3       | 3          |
| 3       | 4          |
+---------+------------+

Result table:
+---------+------------+
| task_id | subtask_id |
+---------+------------+
| 1       | 1          |
| 1       | 3          |
| 2       | 1          |
| 2       | 2          |
+---------+------------+
Task 1 was divided into 3 subtasks (1, 2, 3). Only subtask 2 was executed successfully, so we include (1, 1) and (1, 3) in the answer.
Task 2 was divided into 2 subtasks (1, 2). No subtask was executed successfully, so we include (2, 1) and (2, 2) in the answer.
Task 3 was divided into 4 subtasks (1, 2, 3, 4). All of the subtasks were executed successfully.
```

<br>
<br>

## Table Schema + Testing Data

```sql
-- schema
CREATE TABLE Tasks (
    task_id        INT PRIMARY KEY,
    subtasks_count INT NOT NULL
);

CREATE TABLE Executed (
    task_id    INT NOT NULL,
    subtask_id INT NOT NULL,
    PRIMARY KEY (task_id, subtask_id)
);

-- testing data
INSERT INTO Tasks (task_id, subtasks_count) VALUES
(1, 3),
(2, 2),
(3, 4);

INSERT INTO Executed (task_id, subtask_id) VALUES
(1, 1),
(1, 2),
(2, 1),
(3, 1),
(3, 2),
(3, 4);
```