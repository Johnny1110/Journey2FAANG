-- standard dense_rank()
select Department, Employee, Salary from (
    select d.name Department,
           e.name Employee,
           e.salary Salary,
               dense_rank() over(partition by departmentid order by salary desc) ranked
    from employee e
    inner join department d on e.departmentid = d.id
) as ed where ranked <= 3;

-- CTE
with cte as (select d.name                                                                    Department,
                    e.name                                                                    Employee,
                    e.salary                                                                  Salary,
                    dense_rank() over (partition by e.departmentid order by e.salary desc) as ranked
             from employee as e
                      inner join department d on d.id = e.departmentid)
select Department, Employee, Salary
from cte
where ranked <= 3
order by Department, Salary desc;