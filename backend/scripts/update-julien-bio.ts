/**
 * One-off script to update Julien's barber bio in the database.
 *
 * Run from the backend folder:
 *   npm run update-julien-bio
 *   npx tsx scripts/update-julien-bio.ts
 *
 * It reads DATABASE_URL from the local .env file, so you do not need Railway access.
 */

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const TARGET_FIRST_NAME = 'Julien';
const NEW_BIO =
  "Julien a débuté son expérience en tant que barber depuis 2018. Fort d'une expérience dans plusieurs salons où il a travaillé jusqu'en 2023. Fondateur de BarberClub Grenoble en 2024 et Co-Fondateur de BarberClub Meylan en 2025, il a créé un lieu où passion, expertise et convivialité se rencontrent.";

async function main() {
  const matchingBarbers = await prisma.barber.findMany({
    where: {
      OR: [
        {
          firstName: {
            equals: TARGET_FIRST_NAME,
            mode: 'insensitive',
          },
        },
        {
          displayName: {
            equals: TARGET_FIRST_NAME,
            mode: 'insensitive',
          },
        },
      ],
    },
    select: {
      id: true,
      firstName: true,
      lastName: true,
      displayName: true,
      bio: true,
    },
  });

  if (matchingBarbers.length === 0) {
    throw new Error(`No barber found with first name or display name "${TARGET_FIRST_NAME}".`);
  }

  const result = await prisma.barber.updateMany({
    where: {
      OR: [
        {
          firstName: {
            equals: TARGET_FIRST_NAME,
            mode: 'insensitive',
          },
        },
        {
          displayName: {
            equals: TARGET_FIRST_NAME,
            mode: 'insensitive',
          },
        },
      ],
    },
    data: {
      bio: NEW_BIO,
    },
  });

  console.log(`Updated ${result.count} barber(s):`);
  for (const barber of matchingBarbers) {
    const fullName = `${barber.firstName} ${barber.lastName}`.trim();
    console.log(`- ${fullName} (${barber.id})`);
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
