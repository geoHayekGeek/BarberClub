-- CreateTable
CREATE TABLE "branch_cache" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT,
    "city" TEXT,
    "country" TEXT,
    "timezone" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "branch_cache_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "bookings_user_id_start_date_time_idx" ON "bookings"("user_id", "start_date_time");

-- CreateIndex
CREATE INDEX "bookings_status_idx" ON "bookings"("status");
