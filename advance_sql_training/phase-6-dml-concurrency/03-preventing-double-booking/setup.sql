-- Phase 6-03 — Preventing Double Booking
CREATE EXTENSION IF NOT EXISTS btree_gist;
SET lock_timeout = '5s';
DROP TABLE IF EXISTS bookings;
CREATE TABLE bookings (
    id        SERIAL PRIMARY KEY,
    room_id   INT NOT NULL,
    booked_by TEXT NOT NULL,
    during    tstzrange NOT NULL
);
-- Part B 要加：
-- ALTER TABLE bookings ADD CONSTRAINT no_double_booking
--   EXCLUDE USING gist (room_id WITH =, during WITH &&);
