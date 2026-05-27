-- 1. Using CASE WHEN (standard, works on all databases)
update salary set sex = (select case sex when 'm' then 'f' else 'm' end as s) where True;