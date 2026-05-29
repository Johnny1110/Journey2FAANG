-- first try (7/10)
insert into daily_sales_report (report_date, total_orders, total_revenue, total_items_sold, avg_order_value)
select o.order_date,
       count(distinct o.order_id),
       sum(oi.quantity * oi.unit_price),
       sum(oi.quantity),
       sum(oi.quantity * oi.unit_price) / count(distinct o.order_id)

from orders o
         inner join order_items as oi on oi.order_id = o.order_id
where o.order_date = '2026-05-27'
  and o.status = 'completed'
group by o.order_date;

-- enhancement: fix issue - data not insert if report date have no order (10 out 10)
insert into daily_sales_report (report_date, total_orders, total_revenue, total_items_sold, avg_order_value)
select '2026-05-27' as report_date,
       count(distinct o.order_id), -- count never return NULL
       coalesce(sum(oi.quantity * oi.unit_price), 0), -- sum returns NULL if no rows, so use coalesce to convert to 0
       coalesce(sum(oi.quantity),0),
       case when count(distinct o.order_id) = 0 then 0 else sum(oi.quantity * oi.unit_price) / count(distinct o.order_id) end

from (select 1) as dummy
         left join orders o on o.order_date = '2026-05-27' and o.status = 'completed'
         left join order_items as oi on oi.order_id = o.order_id
group by o.order_date

on conflict (report_date) DO NOTHING;

-- generate whole month report (10/10)
insert into daily_sales_report (report_date, total_orders, total_revenue, total_items_sold, avg_order_value)
select dummy.report_date,
       count(distinct o.order_id), -- count never return NULL
       coalesce(sum(oi.quantity * oi.unit_price), 0), -- sum returns NULL if no rows, so use coalesce to convert to 0
       coalesce(sum(oi.quantity),0),
       case when count(distinct o.order_id) = 0 then 0 else sum(oi.quantity * oi.unit_price) / count(distinct o.order_id) end

from (
select generate_series('2026-05-01'::date, '2026-05-01'::date + interval '1 month' - interval '1 day', '1 day'::interval) as report_date
) as dummy
         left join orders o on o.order_date = dummy.report_date and o.status = 'completed'
         left join order_items as oi on oi.order_id = o.order_id
group by dummy.report_date

on conflict (report_date) DO NOTHING;