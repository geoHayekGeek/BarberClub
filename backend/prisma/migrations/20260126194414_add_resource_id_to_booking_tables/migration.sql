-- AlterTable
-- Add resourceId column to timify_reservations table
ALTER TABLE "timify_reservations" ADD COLUMN "resource_id" TEXT;

-- AlterTable
-- Add resourceId column to bookings table
ALTER TABLE "bookings" ADD COLUMN "resource_id" TEXT;
