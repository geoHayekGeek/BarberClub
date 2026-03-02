-- AlterTable: add is_super_admin to users
ALTER TABLE "users" ADD COLUMN "is_super_admin" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable: implicit many-to-many User <-> Salon (AdminSalons)
CREATE TABLE "_AdminSalons" (
    "A" TEXT NOT NULL,
    "B" TEXT NOT NULL
);

ALTER TABLE "_AdminSalons" ADD CONSTRAINT "_AdminSalons_A_fkey" FOREIGN KEY ("A") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "_AdminSalons" ADD CONSTRAINT "_AdminSalons_B_fkey" FOREIGN KEY ("B") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE UNIQUE INDEX "_AdminSalons_AB_unique" ON "_AdminSalons"("A", "B");
CREATE INDEX "_AdminSalons_B_index" ON "_AdminSalons"("B");

-- AlterTable: add admin_id to loyalty_transactions
ALTER TABLE "loyalty_transactions" ADD COLUMN "admin_id" TEXT;

ALTER TABLE "loyalty_transactions" ADD CONSTRAINT "loyalty_transactions_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "loyalty_transactions_admin_id_idx" ON "loyalty_transactions"("admin_id");
