/*
  Warnings:

  - You are about to drop the column `reward_available` on the `loyalty_states` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "loyalty_states" DROP COLUMN "reward_available";

-- CreateTable
CREATE TABLE "loyalty_redemption_tokens" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "loyalty_redemption_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "loyalty_redemptions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "redeemed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "previous_stamps" INTEGER NOT NULL,

    CONSTRAINT "loyalty_redemptions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "loyalty_redemption_tokens_user_id_idx" ON "loyalty_redemption_tokens"("user_id");

-- CreateIndex
CREATE INDEX "loyalty_redemption_tokens_token_hash_idx" ON "loyalty_redemption_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "loyalty_redemption_tokens_expires_at_used_at_idx" ON "loyalty_redemption_tokens"("expires_at", "used_at");

-- CreateIndex
CREATE INDEX "loyalty_redemptions_user_id_idx" ON "loyalty_redemptions"("user_id");

-- CreateIndex
CREATE INDEX "loyalty_redemptions_redeemed_at_idx" ON "loyalty_redemptions"("redeemed_at");

-- AddForeignKey
ALTER TABLE "loyalty_redemption_tokens" ADD CONSTRAINT "loyalty_redemption_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "loyalty_redemptions" ADD CONSTRAINT "loyalty_redemptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
