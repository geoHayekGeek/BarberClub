/**
 * One-off script: set every user's password to password123 (hashed with argon2).
 * Run from backend: npm run reset-passwords
 * (Ensure .env DATABASE_URL is set.)
 */

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/utils/password';

const prisma = new PrismaClient();

async function main() {
  const newHash = await hashPassword('password123');
  const result = await prisma.user.updateMany({
    data: { passwordHash: newHash },
  });
  console.log(`Updated ${result.count} user(s). All passwords are now: password123`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
