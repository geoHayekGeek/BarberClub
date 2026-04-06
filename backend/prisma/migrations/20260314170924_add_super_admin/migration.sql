-- AlterTable
ALTER TABLE "offer_activations" ALTER COLUMN "status" SET DEFAULT 'pending_scan';

-- CreateIndex
CREATE INDEX "referrals_referral_code_idx" ON "referrals"("referral_code");
