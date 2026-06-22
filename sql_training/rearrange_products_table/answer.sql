-- 1. 7/10
select * from (
select product_id,
       'store1' as store,
       case when store1 is not null
            then store1
            else null
       end as price
from products

    union all
select product_id,
       'store2' as store,
       case when store2 is not null
                then store2
            else null
           end as price
from products
union all

select product_id,
       'store3' as store,
       case when store3 is not null
                then store3
            else null
           end as price
from products) as t
         where price is not null
         order by product_id, price;

-- 2. 10/10

select product_id,
       'store1' as store,
       store1   as price
from products
where store1 is not null

union all

select product_id,
       'store2' as store,
       store2      price
from products
where store2 is not null

union all

select product_id,
       'store3' as store,
       store3   as price
from products
where store3 is not null

order by product_id, price;