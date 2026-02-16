-- CreateTable
CREATE TABLE "loyalty_coupons" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "redeemed_at" TIMESTAMP(3),
    "qr_token_hash" TEXT,
    "qr_expires_at" TIMESTAMP(3),
    "qr_used_at" TIMESTAMP(3),

    CONSTRAINT "loyalty_coupons_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "loyalty_coupons_user_id_idx" ON "loyalty_coupons"("user_id");

-- CreateIndex
CREATE INDEX "loyalty_coupons_qr_token_hash_idx" ON "loyalty_coupons"("qr_token_hash");

-- CreateIndex
CREATE INDEX "loyalty_coupons_redeemed_at_idx" ON "loyalty_coupons"("redeemed_at");

-- AddForeignKey
ALTER TABLE "loyalty_coupons" ADD CONSTRAINT "loyalty_coupons_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
