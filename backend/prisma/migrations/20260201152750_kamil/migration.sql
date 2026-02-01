/*
  Warnings:

  - Added the required column `duration_minutes` to the `offers` table without a default value. This is not possible if the table is not empty.
  - Added the required column `price` to the `offers` table without a default value. This is not possible if the table is not empty.
  - Added the required column `salon_id` to the `offers` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "offers_valid_from_idx";

-- DropIndex
DROP INDEX "offers_valid_to_idx";

-- AlterTable
ALTER TABLE "offers" ADD COLUMN     "duration_minutes" INTEGER NOT NULL,
ADD COLUMN     "price" INTEGER NOT NULL,
ADD COLUMN     "salon_id" TEXT NOT NULL;

-- CreateIndex
CREATE INDEX "offers_salon_id_idx" ON "offers"("salon_id");

-- AddForeignKey
ALTER TABLE "offers" ADD CONSTRAINT "offers_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
