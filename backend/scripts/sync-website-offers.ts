/**
 * Synchronize the app offers table with the website offer.
 *
 * Run from backend:
 *   npx tsx scripts/sync-website-offers.ts
 */

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { syncWebsiteOffers } from '../src/modules/client_offers/website_offers';

const prisma = new PrismaClient();

async function main() {
  await syncWebsiteOffers(prisma);
  console.log('Website offers synchronized.');
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

