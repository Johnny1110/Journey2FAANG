-- Phase 4-06 — Split a String Into Rows
DROP TABLE IF EXISTS article_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS articles;
CREATE TABLE articles (
    id    INT PRIMARY KEY,
    title VARCHAR(60) NOT NULL,
    tags  TEXT
);
INSERT INTO articles (id, title, tags) VALUES
(1,'Indexing Deep Dive','sql,postgres,performance'),
(2,'Window Functions',  'sql'),
(3,'Draft Post',        ''),            -- 空字串
(4,'Untagged Post',     NULL),          -- NULL
(5,'Trailing Comma',    'sql,nosql,'),  -- 結尾逗號
(6,'Double Comma',      'a,,b');        -- 連續逗號
-- 6 篇文章。string_to_table + CROSS JOIN LATERAL 只會回傳 4 篇。
