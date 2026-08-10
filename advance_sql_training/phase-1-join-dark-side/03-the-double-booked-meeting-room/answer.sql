-- ============================================================
-- Phase 1-03 — The Double-Booked Meeting Room
-- ============================================================
-- 作答規則：每一個 Q 都要回答。文字答案寫在註解裡，SQL 直接寫。
-- 面試現場講不出來 = 0 分，所以文字部分和 SQL 一樣重要。

-- ------------------------------------------------------------
-- Q1: 從「不重疊的兩種情況」反推重疊條件（先寫文字推導，不要寫 SQL）
-- ------------------------------------------------------------

-- De Morgan 定律：
-- NOT (P OR Q) = NOT (P) AND NOT (Q)

-- non-overlapping situations:

-- 1.
-- A:[-----)
-- B:       [------)
-- cond: a_end <= b_start

-- 2.
-- A:        [-----)
-- B:[------)
-- b_end >= a_start

-- not overlap = NOT ( (a_end <= b_start) OR (b_end <= a_start) )
-- De Morgan (reverse):
-- a_end > b_start AND b_end > a_start

-- ------------------------------------------------------------
-- Q2: 衝突配對查詢（含 overlap_minutes）
-- ------------------------------------------------------------


select a.id id_a, b.id id_b,
       a.room_id room_id,
       a.booked_by book_by_a, b.booked_by book_by_b,
       EXTRACT(EPOCH from least(a.ends_at, b.ends_at) - greatest(a.starts_at, b.starts_at)) / 60  as overlap_minutes
from bookings a
         inner join bookings b on a.id < b.id AND a.room_id = b.room_id AND (a.ends_at > b.starts_at AND b.ends_at > a.starts_at);

-- ------------------------------------------------------------
-- Q3: 半開 vs 閉區間 — 改成 <= 會多哪一筆 + 商業情境判斷
-- ------------------------------------------------------------

-- In this case, question is not asking certain cond to change, so I decicde to change like that:
select a.id id_a, b.id id_b,
       a.room_id room_id,
       a.booked_by book_by_a, b.booked_by book_by_b,
       EXTRACT(EPOCH from least(a.ends_at, b.ends_at) - greatest(a.starts_at, b.starts_at)) / 60  as overlap_minutes
from bookings a
         inner join bookings b on a.id < b.id AND a.room_id = b.room_id AND (a.ends_at >= b.starts_at AND b.ends_at >= a.starts_at);


-- 1. there will be 1 row id_a = 1 id_b = 3 and room_id is 101.
-- 2. 真正該用 <= 的情境，共同特徵是 端點是一個「不可分割的單位」，而不是一個瞬間：
--     情境：員工職位任期 (hired, left) -> 離職日當天仍在職，同一天入職新職位 = 重複佔缺
-- 3. I will use tsrange to replace starts_at and ends_at.

-- tsrange(starts_at, ends_at, '[)') -- 半開，相接不算衝突
-- tsrange(starts_at, ends_at, '[]') -- 閉合，相接算衝突

-- add period column.
alter table bookings add column period tsrange generated always as (tsrange(starts_at, ends_at, '[)')) STORED;
-- add constraint.
alter table bookings add constraint no_double_booking exclude using gist (room_id with =, period with &&);

-- Better to know - 3 range operator:
r1 && r2    -- 重疊 (overlap)
r1 -|- r2   -- 相接 (adjacent)  ← 就是 (1,3) 這個 case
r1 @> r2    -- 包含 (contains)  ← 就是 (5,6) 這個 case

-- ------------------------------------------------------------
-- Q4: OVERLAPS 版本 / tsrange && 版本 + 邊界語意（查文件確認）
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Q5: 500 萬筆的規模問題 — 複雜度 / 索引 / 降到 O(n log n)
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


