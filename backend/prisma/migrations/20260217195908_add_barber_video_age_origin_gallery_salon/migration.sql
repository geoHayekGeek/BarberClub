-- AlterTable
ALTER TABLE "barbers" ADD COLUMN     "age" INTEGER,
ADD COLUMN     "gallery" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "image_url" TEXT,
ADD COLUMN     "origin" TEXT,
ADD COLUMN     "role" TEXT NOT NULL DEFAULT 'BARBER',
ADD COLUMN     "salon_id" TEXT,
ADD COLUMN     "video_url" TEXT,
ALTER COLUMN "bio" DROP NOT NULL;

-- CreateIndex
CREATE INDEX "barbers_salon_id_idx" ON "barbers"("salon_id");

-- AddForeignKey
ALTER TABLE "barbers" ADD CONSTRAINT "barbers_salon_id_fkey" FOREIGN KEY ("salon_id") REFERENCES "salons"("id") ON DELETE SET NULL ON UPDATE CASCADE;
