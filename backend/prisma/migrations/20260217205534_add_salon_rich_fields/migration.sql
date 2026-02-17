-- AlterTable
ALTER TABLE "salons" ADD COLUMN     "gallery" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "image_url" TEXT,
ADD COLUMN     "latitude" DOUBLE PRECISION,
ADD COLUMN     "longitude" DOUBLE PRECISION,
ADD COLUMN     "opening_hours_structured" JSONB,
ADD COLUMN     "phone" TEXT NOT NULL DEFAULT '',
ALTER COLUMN "description" DROP NOT NULL;

-- CreateIndex
CREATE INDEX "salons_name_idx" ON "salons"("name");

-- CreateIndex
CREATE INDEX "salons_address_idx" ON "salons"("address");
