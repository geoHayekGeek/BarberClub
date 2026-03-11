/**
 * One-off script to add more client offers to the database.
 * Run from backend: npx tsx scripts/add-offers.ts
 * (Ensure .env DATABASE_URL is set.)
 */

import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const now = new Date();
const inOneWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
const inTwoWeeks = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
const inOneMonth = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

async function main() {
  const offers = [
    // --- EVENT (3) ---
    {
      type: 'event' as const,
      title: 'Soirée Barbier -20%',
      description: 'Profitez de -20% sur toutes les prestations lors de notre soirée événement.',
      discountType: 'percentage' as const,
      discountValue: 20,
      applicableServices: ['Coupe', 'Barbe', 'Coupe + Barbe'],
      startsAt: now,
      endsAt: inOneWeek,
      maxSpots: 50,
      spotsTaken: 0,
    },
    {
      type: 'event' as const,
      title: 'Offre limitée -15%',
      description: 'Profitez de -15% sur toutes les prestations jusqu\'à la fin de la semaine.',
      discountType: 'percentage' as const,
      discountValue: 15,
      applicableServices: ['Coupe', 'Barbe', 'Coloration'],
      startsAt: now,
      endsAt: inOneWeek,
      maxSpots: null,
      spotsTaken: 0,
    },
    {
      type: 'event' as const,
      title: 'Événement spécial -10%',
      description: 'Réduction de 10% sur l\'ensemble des prestations pour notre événement.',
      discountType: 'percentage' as const,
      discountValue: 10,
      applicableServices: ['Coupe', 'Barbe'],
      startsAt: now,
      endsAt: inTwoWeeks,
      maxSpots: 100,
      spotsTaken: 0,
    },
    // --- FLASH (1) ---
    {
      type: 'flash' as const,
      title: 'Flash -25% (places limitées)',
      description: 'Offre flash : -25% pendant 2h après activation. Places limitées.',
      discountType: 'percentage' as const,
      discountValue: 25,
      applicableServices: ['Coupe', 'Barbe'],
      startsAt: now,
      endsAt: inOneWeek,
      maxSpots: 20,
      spotsTaken: 0,
    },
    // --- PACK (1) ---
    {
      type: 'pack' as const,
      title: 'Pack 5 coupes',
      description: 'Achetez 5 coupes au prix de 4. Valable 6 mois.',
      discountType: 'fixed' as const,
      discountValue: 15,
      applicableServices: ['Coupe'],
      startsAt: now,
      endsAt: inOneMonth,
      maxSpots: null,
      spotsTaken: 0,
    },
    // --- PERMANENT (1) ---
    {
      type: 'permanent' as const,
      title: 'Fidélité -5%',
      description: 'Réduction permanente de 5% pour les clients fidèles.',
      discountType: 'percentage' as const,
      discountValue: 5,
      applicableServices: ['Coupe', 'Barbe', 'Coloration'],
      startsAt: now,
      endsAt: null,
      maxSpots: null,
      spotsTaken: 0,
    },
    // --- WELCOME (1) ---
    {
      type: 'welcome' as const,
      title: 'Bienvenue -10%',
      description: 'Offre de bienvenue : -10% sur votre première prestation.',
      discountType: 'percentage' as const,
      discountValue: 10,
      applicableServices: ['Coupe', 'Barbe'],
      startsAt: now,
      endsAt: inOneMonth,
      maxSpots: null,
      spotsTaken: 0,
    },
  ];

  for (const o of offers) {
    const created = await prisma.clientOffer.create({
      data: {
        type: o.type,
        title: o.title,
        description: o.description,
        discountType: o.discountType,
        discountValue: o.discountValue,
        applicableServices: o.applicableServices,
        startsAt: o.startsAt,
        endsAt: o.endsAt,
        maxSpots: o.maxSpots,
        spotsTaken: o.spotsTaken,
      },
    });
    console.log(`Created ${o.type}: ${created.title} (${created.id})`);
  }

  console.log(`Done. Added ${offers.length} offers.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
