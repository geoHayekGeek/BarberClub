-- CreateEnum
CREATE TYPE "LoyaltyTransactionType" AS ENUM ('EARN', 'REDEEM', 'ADJUST');

-- CreateEnum
CREATE TYPE "LoyaltyRedemptionStatus" AS ENUM ('PENDING', 'USED');

-- CreateTable
CREATE TABLE "loyalty_accounts" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "current_balance" INTEGER NOT NULL DEFAULT 0,
    "lifetime_earned" INTEGER NOT NULL DEFAULT 0,
    "enrolled_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "loyalty_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "loyalty_transactions" (
    "id" TEXT NOT NULL,
    "account_id" TEXT NOT NULL,
    "type" "LoyaltyTransactionType" NOT NULL,
    "points" INTEGER NOT NULL,
    "description" TEXT NOT NULL,
    "reference_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "loyalty_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "loyalty_rewards" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "cost_points" INTEGER NOT NULL,
    "description" TEXT,
    "image_url" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "loyalty_rewards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "loyalty_redemption_vouchers" (
    "id" TEXT NOT NULL,
    "account_id" TEXT NOT NULL,
    "reward_id" TEXT NOT NULL,
    "points_spent" INTEGER NOT NULL,
    "status" "LoyaltyRedemptionStatus" NOT NULL DEFAULT 'PENDING',
    "redeemed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "used_at" TIMESTAMP(3),
    "qr_token_hash" TEXT,
    "qr_expires_at" TIMESTAMP(3),
    "qr_used_at" TIMESTAMP(3),

    CONSTRAINT "loyalty_redemption_vouchers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "loyalty_account_qr_tokens" (
    "id" TEXT NOT NULL,
    "account_id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "loyalty_account_qr_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "loyalty_accounts_user_id_key" ON "loyalty_accounts"("user_id");

-- CreateIndex
CREATE INDEX "loyalty_transactions_account_id_idx" ON "loyalty_transactions"("account_id");

-- CreateIndex
CREATE INDEX "loyalty_redemption_vouchers_account_id_idx" ON "loyalty_redemption_vouchers"("account_id");

-- CreateIndex
CREATE INDEX "loyalty_redemption_vouchers_reward_id_idx" ON "loyalty_redemption_vouchers"("reward_id");

-- CreateIndex
CREATE INDEX "loyalty_redemption_vouchers_status_idx" ON "loyalty_redemption_vouchers"("status");

-- CreateIndex
CREATE UNIQUE INDEX "loyalty_account_qr_tokens_token_hash_key" ON "loyalty_account_qr_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "loyalty_account_qr_tokens_account_id_idx" ON "loyalty_account_qr_tokens"("account_id");

-- CreateIndex
CREATE INDEX "loyalty_account_qr_tokens_token_hash_idx" ON "loyalty_account_qr_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "loyalty_account_qr_tokens_expires_at_used_at_idx" ON "loyalty_account_qr_tokens"("expires_at", "used_at");

-- AddForeignKey
ALTER TABLE "loyalty_accounts" ADD CONSTRAINT "loyalty_accounts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "loyalty_transactions" ADD CONSTRAINT "loyalty_transactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "loyalty_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "loyalty_redemption_vouchers" ADD CONSTRAINT "loyalty_redemption_vouchers_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "loyalty_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "loyalty_redemption_vouchers" ADD CONSTRAINT "loyalty_redemption_vouchers_reward_id_fkey" FOREIGN KEY ("reward_id") REFERENCES "loyalty_rewards"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "loyalty_account_qr_tokens" ADD CONSTRAINT "loyalty_account_qr_tokens_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "loyalty_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
