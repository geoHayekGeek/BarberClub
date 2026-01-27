-- AlterTable
-- This migration adds a unique constraint to the phoneNumber column
-- WARNING: If there are existing duplicate phoneNumber values, this migration will fail.
-- Ensure all phoneNumber values are unique before applying this migration.

ALTER TABLE "users" ADD CONSTRAINT "users_phoneNumber_key" UNIQUE ("phoneNumber");
