-- Phase 4-02 — Bill of Materials Explosion
DROP TABLE IF EXISTS bom;
CREATE TABLE bom (
    parent_sku VARCHAR(20) NOT NULL,
    child_sku  VARCHAR(20) NOT NULL,
    qty        INT NOT NULL,
    PRIMARY KEY (parent_sku, child_sku)
);
INSERT INTO bom (parent_sku, child_sku, qty) VALUES
('BIKE', 'WHEEL',  2), ('BIKE', 'FRAME', 1), ('BIKE','SEAT',1),
('WHEEL','SPOKE', 36), ('WHEEL','RIM',   1), ('WHEEL','TIRE',1), ('WHEEL','BOLT',4),
('TIRE', 'RUBBER', 1), ('TIRE', 'VALVE', 1),
('FRAME','TUBE',   4), ('FRAME','WELD',  8), ('FRAME','BOLT',6);
-- BOLT 出現在兩條路徑：2x4 + 1x6 = 14
-- Part C1 的環（測完記得刪）： INSERT INTO bom VALUES ('SPOKE','WHEEL',1);
