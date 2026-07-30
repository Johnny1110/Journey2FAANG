-- Phase 1-06 — The Self-Join That Counted Twice
DROP TABLE IF EXISTS follows;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id       INT PRIMARY KEY,
    username VARCHAR(50) NOT NULL
);

CREATE TABLE follows (
    follower_id INT NOT NULL,
    followee_id INT NOT NULL,
    followed_at DATE NOT NULL,
    PRIMARY KEY (follower_id, followee_id)
);

INSERT INTO users (id, username) VALUES
(1, 'alice'), (2, 'bob'),   (3, 'carol'), (4, 'dave'),
(5, 'eve'),   (6, 'frank'), (7, 'grace'), (8, 'heidi');

INSERT INTO follows (follower_id, followee_id, followed_at) VALUES
(1, 2, '2026-01-10'),   -- alice -> bob
(2, 1, '2026-01-11'),   -- bob -> alice        互相追蹤
(1, 3, '2026-01-12'),   -- alice -> carol
(3, 1, '2026-01-12'),   -- carol -> alice      互相追蹤
(2, 3, '2026-01-15'),   -- bob -> carol        單向
(4, 5, '2026-02-01'),   -- dave -> eve
(5, 4, '2026-02-03'),   -- eve -> dave         互相追蹤
(5, 6, '2026-02-05'),   -- eve -> frank        單向
(6, 6, '2026-02-06'),   -- frank -> frank      自我追蹤（髒資料）
(7, 8, '2026-03-01');   -- grace -> heidi      單向
