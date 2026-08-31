-- ============================================================
-- Phase 1-04 — Ledger Reconciliation
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- Q1: 為什麼要 FULL OUTER JOIN（附 UNION 替代寫法）
-- ------------------------------------------------------------

-- with left join, if main table is internal_ledger, it will missing '銀行有紀錄、我們沒記帳' records.
-- Union can replace full outer join, using union select from internal_ledger and bank_statement.

select il.txn_ref, il.amount internal_amount, bs.amount bank_amount from internal_ledger il
    left join bank_statement bs on il.txn_ref = bs.txn_ref
union all
select bs.txn_ref,  null, bs.amount from bank_statement bs
where not exists (select 1 from internal_ledger il where il.txn_ref = bs.txn_ref)
order by txn_ref;

-- Why FULL OUTER JOIN is better? Answer:
-- Scan Count: FULL OUTER JOIN only need 1 hash join, scan 2 table, with union all, we need scan 4 times (2 join, 2 anti-join).
-- Clearly Semantic: FULL OUTER JOIN is born for this kind of situation. which is mean "get me UNION from both table."

-- ------------------------------------------------------------
-- Q2: 對帳查詢（注意 CASE WHEN 分支順序）
-- ------------------------------------------------------------


select *,
       case
           when bs_key is null then 'MISSING_IN_BANK'
           when il_key is null then 'MISSING_IN_LEDGER'
           when diff = 0 then 'MATCHED'
           else 'AMOUNT_MISMATCH' end as status
from (select coalesce(il.txn_ref, bs.txn_ref) as txn_ref,
             il.txn_ref                       as il_key,
             bs.txn_ref                       as bs_key,
             il.amount                        as internal_amount,
             bs.amount                        as bank_amount,
             il.amount - bs.amount            as diff
      from internal_ledger il
               full outer join bank_statement bs on il.txn_ref = bs.txn_ref) as t
order by txn_ref;

-- ------------------------------------------------------------
-- Q3: 天真的 <> 把 TXN-007 判成什麼 + IS DISTINCT FROM 修正
-- ------------------------------------------------------------

select *
from internal_ledger il
         full outer join bank_statement bs on bs.txn_ref = il.txn_ref
where il.amount <> bs.amount;



-- ------------------------------------------------------------
-- Q4: IS DISTINCT FROM 完整真值表
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Q5: 商業判斷 — 結算日延遲 / 浮點容差
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


