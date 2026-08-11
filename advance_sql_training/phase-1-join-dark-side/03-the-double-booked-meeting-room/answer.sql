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

-- example
WHERE a.period && b.period                      -- 半開語意
WHERE a.period && b.period OR a.period -|- b.period  -- 閉合語意

-- ------------------------------------------------------------
-- Q4: OVERLAPS 版本 / tsrange && 版本 + 邊界語意（查文件確認）
-- ------------------------------------------------------------

-- rewrite query:
-- First of all, adjust table schema:

alter table bookings add column period tsrange generated always as (
    tsrange(starts_at, ends_at, '[)')
    ) STORED;

-- tsrange version:
select a.id id_a, b.id id_b,
       a.room_id room_id,
       a.booked_by book_by_a, b.booked_by book_by_b,
    extract(epoch from (least(a.ends_at, b.ends_at) - greatest(a.starts_at, b.starts_at)) ) / 60  as overlap_minutes
from bookings a inner join bookings b
    on a.room_id = b.room_id AND a.id < b.id
    AND a.period && b.period;

-- OVERLAPS version:
select a.id id_a, b.id id_b,
       a.room_id room_id,
       a.booked_by book_by_a, b.booked_by book_by_b,
       extract(epoch from (least(a.ends_at, b.ends_at) - greatest(a.starts_at, b.starts_at)) ) / 60  as overlap_minutes
from bookings a inner join bookings b
     on a.room_id = b.room_id AND a.id < b.id
     AND (a.starts_at, a.ends_at) OVERLAPS (b.starts_at, b.ends_at);

-- OVERLAPS is half-open interval (半開), '&&' is intersection
-- tsrange(a, b) 預設邊界是半開 '[)'

-- Tips:
-- 零長度區間會被當成「那一個瞬間」
SELECT (TIMESTAMP '10:00', TIMESTAMP '10:00')
           OVERLAPS (TIMESTAMP '09:00', TIMESTAMP '11:00');
-- true
SELECT tsrange('2026-03-02 10:00','2026-03-02 10:00','[)')
           && tsrange('2026-03-02 09:00','2026-03-02 11:00','[)');
-- false  ← 因為前者是 empty range，empty 不與任何東西重疊

-- ------------------------------------------------------------
-- Q5: 500 萬筆的規模問題 — 複雜度 / 索引 / 降到 O(n log n)
-- ------------------------------------------------------------


- 你的自連接的時間複雜度是什麼？

-- inner join time complexity O(N²) NESTED LOOP -> Seq Scan * Seq Scan

- 加什麼 index 有幫助？

-- add Gist with tsrange, it will lead Time complexity to O(N) -> Seq Scan * hash join ❌
-- Hash join 和 merge join 都只支援等值條件 —— hash 需要「相等的值 hash 到同一個 bucket」，range 重疊沒有這個性質（9:00–10:00 和 9:30–10:30 重疊，但它們沒有任何「相等」可言）。
-- && 的計畫只有一種形狀：
Nested Loop
  -> Seq Scan on bookings a
  -> Index Scan using idx_room_period on bookings b
       Index Cond: (a.period && b.period AND a.room_id = b.room_id)
-- 外層仍然是 Seq Scan 掃 N 筆，index 救的是內層 —— 把每次 O(N) 的掃描降成 O(log N) 的樹搜尋。

-- 所以是 O(N log N + K)，不是 O(N)。
-- K 是實際衝突配對數。這裡有個複雜度分析的硬下界你該知道：任何「列出所有配對」的演算法都不可能快於 O(K) —— 光是把答案印出來就要 K 個動作。

- 如果只需要檢查**今天**的衝突，查詢怎麼改？

select a.id id_a, b.id id_b,
       a.room_id room_id,
       a.booked_by book_by_a, b.booked_by book_by_b,
       extract(epoch from (least(a.ends_at, b.ends_at) - greatest(a.starts_at, b.starts_at)) ) / 60  as overlap_minutes
from bookings a inner join bookings b
                           on a.room_id = b.room_id AND a.id < b.id
                               AND a.period && b.period
where a.period && tsrange(CURRENT_DATE, CURRENT_DATE + 1, '[)');

-- 有沒有辦法讓這個查詢從 O(n²) 降到接近 O(n log n)？（提示：想想 Phase 3 的 window function）

with marked as (
select id, room_id, booked_by, starts_at, ends_at,
       max(ends_at) over (partition by room_id order by starts_at, ends_at rows between unbounded preceding and 1 preceding) as max_prev_end
from bookings
) select id , room_id, booked_by, starts_at, ends_at from marked
where starts_at < max_prev_end
order by room_id, starts_at;

-- ------------------------------------------------------------
-- 面試官追問 1~4
-- ------------------------------------------------------------


