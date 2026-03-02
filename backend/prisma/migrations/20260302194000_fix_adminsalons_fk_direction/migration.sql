-- Fix implicit many-to-many FK direction for relation "AdminSalons".
-- Prisma expects _AdminSalons.A -> salons.id and _AdminSalons.B -> users.id.

ALTER TABLE "_AdminSalons" DROP CONSTRAINT IF EXISTS "_AdminSalons_A_fkey";
ALTER TABLE "_AdminSalons" DROP CONSTRAINT IF EXISTS "_AdminSalons_B_fkey";

-- Reset links created with incorrect FK direction (safe to rebuild from seed)
TRUNCATE TABLE "_AdminSalons";

ALTER TABLE "_AdminSalons"
  ADD CONSTRAINT "_AdminSalons_A_fkey"
  FOREIGN KEY ("A") REFERENCES "salons"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "_AdminSalons"
  ADD CONSTRAINT "_AdminSalons_B_fkey"
  FOREIGN KEY ("B") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
