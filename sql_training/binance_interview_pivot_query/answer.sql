-- 7/10
with cte as (select d.department_name,
                    row_number() over (order by count(distinct ep.project_id) desc) as rank
             from department as d
                      left join employee as e on e.department_id = d.department_id
                      left join employee_project as ep on ep.employee_id = e.employee_id
             group by d.department_name limit 3)
select max(case when cte.rank = 1 then cte.department_name end) as one,
       max(case when cte.rank = 2 then cte.department_name end) as two,
       max(case when cte.rank = 3 then cte.department_name end) as three
from cte;

-- 10/10
with cte as (select d.department_name,
                    row_number() over (order by count(distinct ep.project_id) desc) as rank
             from department as d
                      left join employee as e on e.department_id = d.department_id
                      left join employee_project as ep on ep.employee_id = e.employee_id
             group by d.department_name order by rank limit 3) -- add order by
select max(case when cte.rank = 1 then cte.department_name end) as "1st", -- fix column name
       max(case when cte.rank = 2 then cte.department_name end) as "2st",
       max(case when cte.rank = 3 then cte.department_name end) as "3st"
from cte;