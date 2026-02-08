-- Drop timify_reservations table
DROP TABLE IF EXISTS "timify_reservations";

-- Remove timify_appointment_id from bookings
ALTER TABLE "bookings" DROP COLUMN IF EXISTS "timify_appointment_id";
