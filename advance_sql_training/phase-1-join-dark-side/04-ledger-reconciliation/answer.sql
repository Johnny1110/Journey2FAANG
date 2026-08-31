-- ============================================================
-- Phase 1-04 — Ledger Reconciliation
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- Q1: 為什麼要 FULL OUTER JOIN（附 UNION 替代寫法）
-- ------------------------------------------------------------

-- FULL OUTER JOIN version:
select coalesce(bs.txn_ref, il.txn_ref) as txn_ref,
       il.amount as internal_amount,
       bs.amount as bank_amount,
       il.amount - bs.amount as diff,
       case when il.amount = bs.amount then 'MATCHED'
            when il.amount is null then 'MISSING_IN_LEDGER'
            when bs.amount is null then 'MISSING_IN_BANK'
            else 'AMOUNT_MISMATCH' end as status
from bank_statement as bs
         full outer join internal_ledger as il on il.txn_ref = bs.txn_ref
order by txn_ref;

-- with left join, if main table is internal_ledger, it will missing '銀行有紀錄、我們沒記帳' records.
-- Union can replace full outer join, using union select from internal_ledger and bank_statement.

-- union version:
with cte as (select il.txn_ref, il.amount internal_amount, bs.amount bank_amount
             from internal_ledger as il
                      left join bank_statement as bs on il.txn_ref = bs.txn_ref
             union all
             select bs.txn_ref, null, bs.amount bank_amount
             from bank_statement as bs
             where not exists(select 1 from internal_ledger as il where il.txn_ref = bs.txn_ref))
select cte.txn_ref, cte.internal_amount, cte.bank_amount, cte.internal_amount - cte.bank_amount as diff,
    case when cte.internal_amount = cte.bank_amount then 'MATCHED'
            when  cte.internal_amount is null then 'MISSING_IN_LEDGER'
            when cte.bank_amount is null then 'MISSING_IN_BANK'
            else 'AMOUNT_MISMATCH' end as status
            from cte order by txn_ref;

-- Why FULL OUTER JOIN is better? Answer:
-- Scan Count: FULL OUTER JOIN only need 1 hash join, scan 2 table, with union all, we need scan 4 times (2 join, 2 anti-join).
-- Clearly Semantic: FULL OUTER JOIN is born for this kind of situation. which is mean "get me UNION from both table."

-- ------------------------------------------------------------
-- Q2: 對帳查詢（注意 CASE WHEN 分支順序）
-- ------------------------------------------------------------

select coalesce(bs.txn_ref, il.txn_ref) as txn_ref,
       il.amount as internal_amount,
       bs.amount as bank_amount,
       il.amount - bs.amount as diff,
       case
            when il.txn_ref is null then 'MISSING_IN_LEDGER'
            when bs.txn_ref is null then 'MISSING_IN_BANK'
            when il.amount = bs.amount then 'MATCHED'
            else 'AMOUNT_MISMATCH'
       end as status
from bank_statement as bs
         full outer join internal_ledger as il on il.txn_ref = bs.txn_ref
order by txn_ref;

-- ------------------------------------------------------------
-- Q3: 天真的 <> 把 TXN-007 判成什麼 + IS DISTINCT FROM 修正
-- ------------------------------------------------------------

-- naive (Wrong) version
select coalesce(bs.txn_ref, il.txn_ref) as txn_ref,
       il.amount as internal_amount,
       bs.amount as bank_amount,
       il.amount - bs.amount as diff,
       case
           when il.amount <> bs.amount then 'AMOUNT_MISMATCH'
           when il.txn_ref is null then 'MISSING_IN_LEDGER'
           when bs.txn_ref is null then 'MISSING_IN_BANK'
           else 'MATCHED'
           end as status
from bank_statement as bs
         full outer join internal_ledger as il on il.txn_ref = bs.txn_ref
order by txn_ref;

--  TXN-007 turn to MATCHED
-- What's Wrong?
-- int <> NULL is UNKNOWN
-- So the conds is UNKNOWN, only true result can enter the branch, false and unknown will be ignored.
--  else 'MATCHED' will be the final answer, since no case branch can be entered.
-- `IS DISTINCT FROM` is binary operator, it's only have true or false values. and <> could return UNKNOWN if null exists.

-- ------------------------------------------------------------
-- Q4: IS DISTINCT FROM 完整真值表
-- ------------------------------------------------------------

-- | a | b | `a = b` | `a <> b` | `a IS NOT DISTINCT FROM b` | `a IS DISTINCT FROM b` |
-- |---|---|---------|----------|---------------------------|------------------------|
-- | 1 | 1 | T | F | T | F |
-- | 1 | 2 | F | T | F | T |
-- | 1 | NULL | UNKNOWN | UNKNOWN | F | T |
-- | NULL | NULL | UNKNOWN | UNKNOWN | T | F |

-- ------------------------------------------------------------
-- Q5: 商業判斷 — 結算日延遲 / 浮點容差
-- ------------------------------------------------------------

select coalesce(bs.txn_ref, il.txn_ref) as txn_ref,
       il.amount as internal_amount,
       bs.amount as bank_amount,
       il.amount - bs.amount as diff,
       case
           when il.txn_ref is null then 'MISSING_IN_LEDGER'
           when bs.txn_ref is null then 'MISSING_IN_BANK'
           when il.amount is distinct from bs.amount
               and (il.amount is null or bs.amount is null
                   or abs(il.amount - bs.amount) > 0.01)
               then 'AMOUNT_MISMATCH'
           when abs(bs.settled_on - il.booked_on) > 2 then 'SETTLEMENT_DELAY'
           when abs(il.amount - bs.amount) <= 0.01 then 'WITHIN_TOLERANCE'
           when il.amount is not distinct from bs.amount then 'MATCHED'
           else 'WITHIN_TOLERANCE'
           end as status
from bank_statement as bs
         full outer join internal_ledger as il on il.txn_ref = bs.txn_ref
order by txn_ref;

-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


