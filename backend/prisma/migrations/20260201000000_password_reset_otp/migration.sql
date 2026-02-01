-- Create password_reset_codes table for OTP-based password reset
-- Replaces token-based flow; old password_reset_tokens retained for reference during migration
CREATE TABLE "password_reset_codes" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "code_hash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_codes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "password_reset_codes_user_id_idx" ON "password_reset_codes"("user_id");
CREATE INDEX "password_reset_codes_code_hash_idx" ON "password_reset_codes"("code_hash");
CREATE INDEX "password_reset_codes_expires_used_idx" ON "password_reset_codes"("expires_at", "used_at");

ALTER TABLE "password_reset_codes" ADD CONSTRAINT "password_reset_codes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
