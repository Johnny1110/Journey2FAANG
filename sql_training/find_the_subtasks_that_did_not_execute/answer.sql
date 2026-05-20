--1. ans
with recursive cte as (select task_id, 1 as subtask_id
                       from tasks
                       union
                       select t2.task_id, t1.subtask_id + 1
                       from tasks as t2
                                join cte as t1 on t1.task_id = t2.task_id
                       where t1.subtask_id + 1 <= t2.subtasks_count)
select cte.task_id, cte.subtask_id
from cte
         left join executed as exe on cte.task_id = exe.task_id and cte.subtask_id = exe.subtask_id
where exe.subtask_id is null;