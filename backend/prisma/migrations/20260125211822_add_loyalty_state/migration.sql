-- CreateTable
CREATE TABLE "loyalty_states" (
    "user_id" TEXT NOT NULL,
    "stamps" INTEGER NOT NULL DEFAULT 0,
    "reward_available" BOOLEAN NOT NULL DEFAULT false,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "loyalty_states_pkey" PRIMARY KEY ("user_id")
);

-- AddForeignKey
ALTER TABLE "loyalty_states" ADD CONSTRAINT "loyalty_states_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
