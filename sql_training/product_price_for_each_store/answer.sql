-- answer:
select product_id,
       max(case store when 'store1' then price end) as store1,
       max(case store when 'store2' then price end) as store2,
       max(case store when 'store3' then price end) as store3
       from products
group by product_id
order by product_id;