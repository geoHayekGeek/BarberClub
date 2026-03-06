-- AlterEnum: add pending_scan to OfferActivationStatus
ALTER TYPE "OfferActivationStatus" ADD VALUE 'pending_scan';

-- AlterTable: add qr_token_hash and qr_used_at to offer_activations
ALTER TABLE "offer_activations" ADD COLUMN "qr_token_hash" TEXT;
ALTER TABLE "offer_activations" ADD COLUMN "qr_used_at" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "offer_activations_qr_token_hash_idx" ON "offer_activations"("qr_token_hash");

-- Set default status to pending_scan for new rows (existing rows keep their status)
-- No data migration needed; new activations will use pending_scan via application.
