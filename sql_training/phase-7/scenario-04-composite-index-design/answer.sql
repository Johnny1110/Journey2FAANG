-- Scenario 04: The Index That Doesn't Work
-- Your leftmost-prefix explanation, corrected index, and design decisions go here.
--
-- 1. Why query A (WHERE user_id=? AND created_at>?) cannot use idx_events_status_created_user (status, created_at, user_id):
-- Because idx_events_status_created_user is Composite Index, which is means if you want to user this index, where condition must contains column from left to the right.
-- B+ Tree index is order by status, created_at, user_id. even though where contains created_at and user_id, without status this index not work.

-- 2. Corrected index DDL for the dashboard query:
-- for this query case, I will design index like this:
create index idx_events_user_created_at on events (user_id, created_at desc);

-- 3. Query-pattern support table for each index:
--    | Query pattern                           | idx_status_created_user | idx_user_created_at |
--    |-----------------------------------------|--------------------------|---------------------|
--    | WHERE status = ?                        |          O               |      X              |
--    | WHERE status = ? AND created_at > ?     |          O               |      X              |
--    | WHERE user_id = ?                       |          X               |      O              |
--    | WHERE user_id = ? AND created_at > ?    |          X               |      O              |
--
-- 4. Decision: keep or drop the original index? Why?

-- In my opinion, It depends on query case and actual dataset.
-- If most event row data's status is active, then I think it is unnecessary to put status into index.
-- In another case, if query where condition contains status, it is fine to keep that index.
