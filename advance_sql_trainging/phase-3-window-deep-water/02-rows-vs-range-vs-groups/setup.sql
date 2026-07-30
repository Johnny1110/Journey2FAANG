-- Phase 3-02 — ROWS vs RANGE vs GROUPS
DROP TABLE IF EXISTS scores;
CREATE TABLE scores (
    id     INT PRIMARY KEY,
    player VARCHAR(20) NOT NULL,
    score  INT NOT NULL
);
INSERT INTO scores (id, player, score) VALUES
(1,'ann',10),(2,'ben',20),(3,'cid',20),(4,'dot',20),(5,'eli',30),(6,'fay',40);
