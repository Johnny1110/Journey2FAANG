-- Phase 1-03 — The Double-Booked Meeting Room
DROP TABLE IF EXISTS bookings;

CREATE TABLE bookings (
    id        INT PRIMARY KEY,
    room_id   INT NOT NULL,
    booked_by VARCHAR(50) NOT NULL,
    starts_at TIMESTAMP NOT NULL,
    ends_at   TIMESTAMP NOT NULL
);

INSERT INTO bookings (id, room_id, booked_by, starts_at, ends_at) VALUES
(1, 101, 'Alice', '2026-03-02 09:00', '2026-03-02 10:00'),
(2, 101, 'Bob',   '2026-03-02 09:30', '2026-03-02 10:30'),   -- 和 1 重疊
(3, 101, 'Carol', '2026-03-02 10:00', '2026-03-02 11:00'),   -- 和 1 相接、和 2 重疊
(4, 101, 'Dave',  '2026-03-02 14:00', '2026-03-02 15:00'),
(5, 102, 'Eve',   '2026-03-02 09:00', '2026-03-02 17:00'),   -- 包場
(6, 102, 'Frank', '2026-03-02 12:00', '2026-03-02 13:00'),   -- 被 5 包住
(7, 102, 'Grace', '2026-03-03 09:00', '2026-03-03 10:00'),
(8, 103, 'Heidi', '2026-03-02 09:00', '2026-03-02 10:00');
