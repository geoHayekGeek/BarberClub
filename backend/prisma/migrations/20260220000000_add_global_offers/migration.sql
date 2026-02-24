-- CreateTable
CREATE TABLE "global_offers" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "image_url" TEXT,
    "discount" INTEGER,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "global_offers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "global_offers_is_active_idx" ON "global_offers"("is_active");
