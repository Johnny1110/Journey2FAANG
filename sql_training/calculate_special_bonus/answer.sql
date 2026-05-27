select employee_id,
       (select case (employee_id%2=1 AND NOT starts_with(name, 'M')) when true then salary else 0 end) as bonus
from employees order by employee_id;