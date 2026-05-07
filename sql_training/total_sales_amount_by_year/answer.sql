-- 1. Recursive CTE
with recursive cte as (select product_id,
                              period_start,
                              period_end,
                              average_daily_sales,
                              extract(year from period_start)::int as report_year
                       from sales

                       union all

                       select product_id,
                              period_start,
                              period_end,
                              average_daily_sales,
                              report_year + 1
                       from cte
                       where report_year < extract(year from period_end)::int)
select p.product_id,
       p.product_name,
       c.report_year,
       (least(c.period_end, make_date(c.report_year, 12, 31)) -- end_date or end of the year
            - greatest(c.period_start, make_date(c.report_year, 1, 1))-- start_date or start of the year
           + 1) -- add one day to include both start and end date
           * c.average_daily_sales as total_amount
from cte c
         join product p on c.product_id = p.product_id
order by p.product_id;