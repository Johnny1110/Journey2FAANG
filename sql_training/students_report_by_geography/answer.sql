-- 1. pivot 公式寫法

select MAX(CASE WHEN continent = 'America' THEN name END) AS America,
       MAX(CASE WHEN continent = 'Asia' THEN name END) AS Asia,
       MAX(CASE WHEN continent = 'Europe' THEN name END) AS Europe
FROM (
         select name, continent, row_number() over (partition by continent order by name) as rn from student
     ) as t
group by rn
order by rn;

