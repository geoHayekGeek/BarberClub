-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');

-- AlterTable
ALTER TABLE "users" ADD COLUMN "role" "UserRole" NOT NULL DEFAULT 'USER';
ALTER TABLE "users" ADD COLUMN "loyalty_points" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "loyalty_qr_tokens" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "loyalty_qr_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "loyalty_qr_tokens_user_id_idx" ON "loyalty_qr_tokens"("user_id");
CREATE INDEX "loyalty_qr_tokens_token_hash_idx" ON "loyalty_qr_tokens"("token_hash");
CREATE INDEX "loyalty_qr_tokens_expires_at_used_at_idx" ON "loyalty_qr_tokens"("expires_at", "used_at");

-- AddForeignKey
ALTER TABLE "loyalty_qr_tokens" ADD CONSTRAINT "loyalty_qr_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
