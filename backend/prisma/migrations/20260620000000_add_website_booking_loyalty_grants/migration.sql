-- CreateTable
CREATE TABLE "website_booking_loyalty_grants" (
    "id" TEXT NOT NULL,
    "website_booking_id" TEXT NOT NULL,
    "website_client_id" TEXT NOT NULL,
    "app_user_id" TEXT,
    "loyalty_account_id" TEXT,
    "service_name" TEXT NOT NULL,
    "booking_price" INTEGER NOT NULL,
    "points_awarded" INTEGER NOT NULL,
    "awarded_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "website_booking_loyalty_grants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "website_booking_loyalty_grants_website_booking_id_key" ON "website_booking_loyalty_grants"("website_booking_id");

-- CreateIndex
CREATE INDEX "website_booking_loyalty_grants_website_client_id_idx" ON "website_booking_loyalty_grants"("website_client_id");

-- CreateIndex
CREATE INDEX "website_booking_loyalty_grants_app_user_id_idx" ON "website_booking_loyalty_grants"("app_user_id");

-- CreateIndex
CREATE INDEX "website_booking_loyalty_grants_loyalty_account_id_idx" ON "website_booking_loyalty_grants"("loyalty_account_id");

-- AddForeignKey
ALTER TABLE "website_booking_loyalty_grants" ADD CONSTRAINT "website_booking_loyalty_grants_app_user_id_fkey" FOREIGN KEY ("app_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "website_booking_loyalty_grants" ADD CONSTRAINT "website_booking_loyalty_grants_loyalty_account_id_fkey" FOREIGN KEY ("loyalty_account_id") REFERENCES "loyalty_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
