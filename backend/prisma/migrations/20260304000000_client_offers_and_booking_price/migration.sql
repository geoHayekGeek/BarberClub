-- CreateEnum
CREATE TYPE "ClientOfferType" AS ENUM ('event', 'flash', 'pack', 'permanent', 'welcome');

-- CreateEnum
CREATE TYPE "DiscountType" AS ENUM ('percentage', 'fixed', 'free_service');

-- CreateEnum
CREATE TYPE "OfferActivationStatus" AS ENUM ('activated', 'used', 'expired', 'cancelled');

-- CreateEnum
CREATE TYPE "ReferralStatus" AS ENUM ('pending', 'completed', 'rewarded');

-- CreateTable
CREATE TABLE "client_offers" (
    "id" TEXT NOT NULL,
    "type" "ClientOfferType" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "discount_type" "DiscountType" NOT NULL,
    "discount_value" INTEGER NOT NULL,
    "applicable_services" TEXT[],
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3),
    "max_spots" INTEGER,
    "spots_taken" INTEGER NOT NULL DEFAULT 0,
    "image_url" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "template_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "client_offers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "offer_activations" (
    "id" TEXT NOT NULL,
    "offer_id" TEXT NOT NULL,
    "client_id" TEXT NOT NULL,
    "status" "OfferActivationStatus" NOT NULL DEFAULT 'activated',
    "activated_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "booking_id" TEXT,
    "expires_at" TIMESTAMP(3),

    CONSTRAINT "offer_activations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "referrals" (
    "id" TEXT NOT NULL,
    "referrer_id" TEXT NOT NULL,
    "referee_id" TEXT NOT NULL,
    "referral_code" TEXT NOT NULL,
    "status" "ReferralStatus" NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),

    CONSTRAINT "referrals_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "users" ADD COLUMN "date_of_birth" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "bookings" ADD COLUMN "price" INTEGER,
ADD COLUMN "original_price" INTEGER,
ADD COLUMN "offer_activation_id" TEXT;

-- CreateIndex
CREATE INDEX "client_offers_is_active_starts_at_idx" ON "client_offers"("is_active", "starts_at");

-- CreateIndex
CREATE INDEX "client_offers_type_idx" ON "client_offers"("type");

-- CreateIndex
CREATE INDEX "offer_activations_offer_id_idx" ON "offer_activations"("offer_id");

-- CreateIndex
CREATE INDEX "offer_activations_client_id_idx" ON "offer_activations"("client_id");

-- CreateIndex
CREATE INDEX "offer_activations_status_idx" ON "offer_activations"("status");

-- CreateIndex
CREATE INDEX "offer_activations_expires_at_idx" ON "offer_activations"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "referrals_referral_code_key" ON "referrals"("referral_code");

-- CreateIndex
CREATE INDEX "referrals_referrer_id_idx" ON "referrals"("referrer_id");

-- CreateIndex
CREATE INDEX "referrals_referee_id_idx" ON "referrals"("referee_id");

-- CreateIndex
CREATE UNIQUE INDEX "bookings_offer_activation_id_key" ON "bookings"("offer_activation_id");

-- CreateIndex
CREATE INDEX "bookings_offer_activation_id_idx" ON "bookings"("offer_activation_id");

-- AddForeignKey
ALTER TABLE "offer_activations" ADD CONSTRAINT "offer_activations_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "client_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "offer_activations" ADD CONSTRAINT "offer_activations_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_referrer_id_fkey" FOREIGN KEY ("referrer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_referee_id_fkey" FOREIGN KEY ("referee_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_offer_activation_id_fkey" FOREIGN KEY ("offer_activation_id") REFERENCES "offer_activations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
