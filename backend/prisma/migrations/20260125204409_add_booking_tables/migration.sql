-- CreateTable
CREATE TABLE "timify_reservations" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "branch_id" TEXT NOT NULL,
    "service_id" TEXT NOT NULL,
    "reserved_date" TEXT NOT NULL,
    "reserved_time" TEXT NOT NULL,
    "timify_reservation_id" TEXT NOT NULL,
    "timify_secret" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "timify_reservations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bookings" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "branch_id" TEXT NOT NULL,
    "service_id" TEXT NOT NULL,
    "start_date_time" TIMESTAMP(3) NOT NULL,
    "timify_appointment_id" TEXT,
    "status" TEXT NOT NULL DEFAULT 'CONFIRMED',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bookings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "timify_reservations_user_id_idx" ON "timify_reservations"("user_id");

-- CreateIndex
CREATE INDEX "timify_reservations_timify_reservation_id_idx" ON "timify_reservations"("timify_reservation_id");

-- CreateIndex
CREATE INDEX "bookings_user_id_idx" ON "bookings"("user_id");

-- CreateIndex
CREATE INDEX "bookings_branch_id_idx" ON "bookings"("branch_id");

-- CreateIndex
CREATE INDEX "bookings_start_date_time_idx" ON "bookings"("start_date_time");

-- AddForeignKey
ALTER TABLE "timify_reservations" ADD CONSTRAINT "timify_reservations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
