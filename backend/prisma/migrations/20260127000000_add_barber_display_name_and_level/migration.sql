-- AlterTable
ALTER TABLE "barbers" ADD COLUMN "display_name" TEXT,
ADD COLUMN "level" TEXT NOT NULL DEFAULT 'senior';
