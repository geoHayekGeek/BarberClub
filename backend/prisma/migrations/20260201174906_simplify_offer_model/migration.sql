/*
  Warnings:

  - You are about to drop the column `image_url` on the `offers` table. All the data in the column will be lost.
  - You are about to drop the column `valid_from` on the `offers` table. All the data in the column will be lost.
  - You are about to drop the column `valid_to` on the `offers` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "offers" DROP COLUMN "image_url",
DROP COLUMN "valid_from",
DROP COLUMN "valid_to",
ALTER COLUMN "duration_minutes" DROP NOT NULL;
