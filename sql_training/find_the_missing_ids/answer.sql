-- 1. recursive CTE 
with recursive cte1 as (select (customer_id + 1) as customer_id
                        from customers
                        where (customer_id + 1) not in (select customer_id from customers)
                          and (customer_id + 1) < (select max(customer_id) from customers)

                        union all

                        select (cte.customer_id + 1) as customer_id
                        from cte1 as cte
                        where (cte.customer_id + 1) not in (select customer_id from customers)
                          and (cte.customer_id + 1) < (select max(customer_id) from customers))
select customer_id
from cte1;

-- 2. using recursive cte list all id from 1 to max, then exclude existing ids in customers.
with recursive ids as (select 1 as customer_id
                       union all
                       select customer_id + 1
                       from ids
                       where customer_id < (select max(customer_id) from customers))
select customer_id
from ids
where customer_id not in (select customer_id from customers)

-- 3. without cte
select id as customer_id
from generate_series(1, (select max(customer_id) from customers)) as g(id)
where id not in (select customer_id from customers);