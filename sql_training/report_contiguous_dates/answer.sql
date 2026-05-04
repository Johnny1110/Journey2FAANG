-- 1. from 2019-01-01 to 2019-12-31.
with raw_data as (
select fail_date as date, 'failed' as state, fail_date - row_number() over (order by fail_date)::int as mark
from failed
where fail_date >= '2019-01-01'
  and fail_date <= '2019-12-31'
union all
select success_date as date, 'succeeded' as state, success_date - row_number() over (order by success_date)::int as mark
from succeeded
where success_date >= '2019-01-01'
  and success_date <= '2019-12-31')
select state as period_state,
       min(date) as start_date,
       max(date) as end_date
from raw_data
group by mark, period_state
order by start_date;

-- 2. using LAG() + SUM() -> 高難度秀操作打法
WITH all_logs AS (
    SELECT fail_date AS date, 'failed' AS state FROM failed
    WHERE fail_date BETWEEN '2019-01-01' AND '2019-12-31'
    UNION ALL
    SELECT success_date, 'succeeded' FROM succeeded
    WHERE success_date BETWEEN '2019-01-01' AND '2019-12-31'
),
marked AS (
    SELECT date, state,
           CASE 
               WHEN LAG(state) OVER (ORDER BY date) = state 
                AND date - LAG(date) OVER (ORDER BY date) = 1
               THEN 0 ELSE 1
           END AS is_new_group
    FROM all_logs
),
grouped AS (
    SELECT date, state,
           SUM(is_new_group) OVER (ORDER BY date) AS group_id
    FROM marked
)
SELECT state AS period_state,
       MIN(date) AS start_date,
       MAX(date) AS end_date
FROM grouped
GROUP BY group_id, state
ORDER BY start_date;