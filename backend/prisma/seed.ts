/**
 * Seed script: admin user + salons + barbers (coiffeurs) with links.
 *
 * Run AFTER migrations: npx prisma migrate dev
 * Then: npx prisma db seed
 */
// @ts-nocheck
/// <reference types="node" />

import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/utils/password';

const prisma = new PrismaClient();

const ADMIN_EMAIL = 'admin@barber-club.com';
const ADMIN_PASSWORD = 'admin123';

async function seedAdmin() {
  const existing = await prisma.user.findUnique({
    where: { email: ADMIN_EMAIL },
  });
  if (existing) {
    if (existing.role === 'ADMIN') {
      console.log('Admin user already exists.');
      return;
    }
    await prisma.user.update({
      where: { id: existing.id },
      data: { role: 'ADMIN' },
    });
    console.log('Existing user updated to ADMIN.');
    return;
  }
  const passwordHash = await hashPassword(ADMIN_PASSWORD);
  await prisma.user.create({
    data: {
      email: ADMIN_EMAIL,
      phoneNumber: '+33000000000',
      passwordHash,
      fullName: 'Admin',
      role: 'ADMIN',
    },
  });
  console.log('Admin user created:', ADMIN_EMAIL);
}

const PLACEHOLDER_IMAGE = 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400';
const PLACEHOLDER_VIDEO = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
const GALLERY_IMAGES = [
  'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400',
  'https://images.unsplash.com/photo-1622287162716-f311baa1a2b8?w=400',
  'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=400',
  'https://images.unsplash.com/photo-1605499466077-3385ab955905?w=400',
  'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=400',
];

const OPENING_HOURS_STRUCTURED = {
  monday: { open: '09:00', close: '19:00', closed: false },
  tuesday: { open: '09:00', close: '19:00', closed: false },
  wednesday: { open: '09:00', close: '19:00', closed: false },
  thursday: { open: '09:00', close: '19:00', closed: false },
  friday: { open: '09:00', close: '19:00', closed: false },
  saturday: { open: '09:00', close: '19:00', closed: false },
  sunday: { closed: true },
};

async function main() {
  await seedAdmin();

  const barberCountBefore = await prisma.barber.count();
  console.log(`Barbers in DB before seed: ${barberCountBefore}`);

  // 1. Ensure salons exist (find or create by name)
let salonGrenoble = await prisma.salon.findFirst({
    where: { name: 'Barber Club Grenoble' },
  });

  if (salonGrenoble) {
    salonGrenoble = await prisma.salon.update({
      where: { id: salonGrenoble.id },
      data: {
        timifyUrl: 'https://book.timify.com/?accountId=662ab032662b882b9529faca&hideCloseButton=true',
        phone: '04 76 12 34 56',
        imageUrl: PLACEHOLDER_IMAGE,
        gallery: GALLERY_IMAGES.slice(0, 4),
        openingHoursStructured: OPENING_HOURS_STRUCTURED,
        latitude: 45.1885,
        longitude: 5.7245,
      },
    });
  } else {
    salonGrenoble = await prisma.salon.create({
      data: {
        name: 'Barber Club Grenoble',
        city: 'Grenoble',
        address: '12 rue de la République, 38000 Grenoble',
        description:
          'Barber Club Grenoble est notre premier salon, ouvert au cœur de la ville. Un espace dédié à l\'art de la barberie : coupes classiques et modernes, rasages à l\'ancienne, soins de la barbe.',
        openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
        images: [PLACEHOLDER_IMAGE],
        isActive: true,
        timifyUrl: 'https://book.timify.com/?accountId=662ab032662b882b9529faca&hideCloseButton=true',
        phone: '04 76 12 34 56',
        imageUrl: PLACEHOLDER_IMAGE,
        gallery: GALLERY_IMAGES.slice(0, 4),
        openingHoursStructured: OPENING_HOURS_STRUCTURED,
        latitude: 45.1885,
        longitude: 5.7245,
      },
    });
  }

  // --- 2. SALON VOIRON ---
  let salonVoiron = await prisma.salon.findFirst({
    where: { name: 'Barber Club Voiron' },
  });

  if (salonVoiron) {
    salonVoiron = await prisma.salon.update({
      where: { id: salonVoiron.id },
      data: {
        timifyUrl: 'https://www.timify.com/fr-fr/profile/barber-club-voiron/',
        phone: '04 76 05 12 34',
        imageUrl: PLACEHOLDER_IMAGE,
        gallery: GALLERY_IMAGES.slice(0, 3),
        openingHoursStructured: OPENING_HOURS_STRUCTURED,
      },
    });
  } else {
    salonVoiron = await prisma.salon.create({
      data: {
        name: 'Barber Club Voiron',
        city: 'Voiron',
        address: '5 place du Marché, 38500 Voiron',
        description:
          'Notre salon de Voiron reprend l\'ADN Barber Club : un cadre soigné, des prestations premium et une équipe formée aux dernières tendances.',
        openingHours: 'Mar–Ven 9h30–19h, Sam 9h–18h, Dim–Lun fermé',
        images: [PLACEHOLDER_IMAGE],
        isActive: true,
        timifyUrl: 'https://www.timify.com/fr-fr/profile/barber-club-voiron/',
        phone: '04 76 05 12 34',
        imageUrl: PLACEHOLDER_IMAGE,
        gallery: GALLERY_IMAGES.slice(0, 3),
        openingHoursStructured: OPENING_HOURS_STRUCTURED,
      },
    });
  }

  // --- 3. SALON MEYLAN ---
  let salonMeylan = await prisma.salon.findFirst({
    where: { name: 'Barber Club Meylan' },
  });

  if (salonMeylan) {
    salonMeylan = await prisma.salon.update({
      where: { id: salonMeylan.id },
      data: {
        timifyUrl: 'https://book.timify.com/?accountId=68e13d325845e16b4feb0d4c&hideCloseButton=true',
        phone: '09 56 30 93 86',
        imageUrl: PLACEHOLDER_IMAGE,
        gallery: GALLERY_IMAGES.slice(0, 5),
        openingHoursStructured: OPENING_HOURS_STRUCTURED,
        latitude: 45.2092,
        longitude: 5.7814,
      },
    });
  } else {
    salonMeylan = await prisma.salon.create({
      data: {
        name: 'Barber Club Meylan',
        city: 'Meylan',
        address: '8 avenue Jean Jaurès, 38240 Meylan',
        description:
          'Le Barber Club Meylan vous propose les mêmes prestations que nos autres salons, dans un cadre moderne et confortable.',
        openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
        images: [PLACEHOLDER_IMAGE],
        isActive: true,
        timifyUrl: 'https://book.timify.com/?accountId=68e13d325845e16b4feb0d4c&hideCloseButton=true',
        phone: '09 56 30 93 86',
        imageUrl: PLACEHOLDER_IMAGE,
        gallery: GALLERY_IMAGES.slice(0, 5),
        openingHoursStructured: OPENING_HOURS_STRUCTURED,
        latitude: 45.2092,
        longitude: 5.7814,
      },
    });
  }

  // 2. Create barbers (coiffeurs) with age, origin, bio, videoUrl, gallery, salonId
  const barbersData = [
    {
      firstName: 'Alexandre',
      lastName: 'Martin',
      displayName: 'Alex',
      bio: 'Coiffeur barbier depuis 8 ans, Alexandre privilégie la précision et le dialogue avec le client. Spécialiste des coupes classiques et du rasage à la lame.',
      experienceYears: 8,
      level: 'expert',
      interests: ['Coupe classique', 'Rasage à la lame', 'Barbe'],
      images: [PLACEHOLDER_IMAGE],
      salonIds: [salonGrenoble.id],
      age: 32,
      origin: 'Lyon',
      videoUrl: PLACEHOLDER_VIDEO,
      imageUrl: PLACEHOLDER_IMAGE,
      gallery: GALLERY_IMAGES.slice(0, 4),
    },
    {
      firstName: 'Lucas',
      lastName: 'Bernard',
      displayName: 'Lucas',
      bio: 'Passionné par la barberie moderne, Lucas allie tradition et tendances. Formé en France et à l\'étranger, il propose des coupes sur-mesure et des soins de la barbe.',
      experienceYears: 5,
      level: 'senior',
      interests: ['Coupe dégradé', 'Barbe', 'Soins'],
      images: [PLACEHOLDER_IMAGE],
      salonIds: [salonGrenoble.id, salonMeylan.id],
      age: 28,
      origin: 'Grenoble',
      videoUrl: PLACEHOLDER_VIDEO,
      imageUrl: PLACEHOLDER_IMAGE,
      gallery: GALLERY_IMAGES.slice(0, 5),
    },
    {
      firstName: 'Thomas',
      lastName: 'Petit',
      displayName: 'Thomas',
      bio: 'Thomas a rejoint Barber Club pour développer son expertise en coupe homme et barbes. Attentif et à l\'écoute, il accompagne chaque client vers un look soigné.',
      experienceYears: 3,
      level: 'junior',
      interests: ['Coupe homme', 'Barbe'],
      images: [PLACEHOLDER_IMAGE],
      salonIds: [salonGrenoble.id],
      age: 24,
      origin: 'Saint-Martin-d\'Hères',
      videoUrl: PLACEHOLDER_VIDEO,
      imageUrl: PLACEHOLDER_IMAGE,
      gallery: GALLERY_IMAGES.slice(0, 3),
    },
    {
      firstName: 'Hugo',
      lastName: 'Durand',
      displayName: 'Hugo',
      bio: 'Hugo est notre référent au salon de Voiron. Plus de 6 ans d\'expérience en barberie, il maîtrise le rasage traditionnel et les coupes structurées.',
      experienceYears: 6,
      level: 'senior',
      interests: ['Rasage traditionnel', 'Coupe structurée', 'Coloration barbe'],
      images: [PLACEHOLDER_IMAGE],
      salonIds: [salonVoiron.id],
      age: 30,
      origin: 'Voiron',
      videoUrl: PLACEHOLDER_VIDEO,
      imageUrl: PLACEHOLDER_IMAGE,
      gallery: GALLERY_IMAGES.slice(0, 5),
    },
    {
      firstName: 'Enzo',
      lastName: 'Moreau',
      displayName: 'Enzo',
      bio: 'Enzo apporte une touche jeune et créative au Barber Club Meylan. Spécialisé dans les dégradés et les coupes tendance, il suit les dernières modes tout en restant fidèle à l\'esprit barber.',
      experienceYears: 4,
      level: 'senior',
      interests: ['Dégradé', 'Coupe tendance', 'Soins'],
      images: [PLACEHOLDER_IMAGE],
      salonIds: [salonMeylan.id],
      age: 26,
      origin: 'Meylan',
      videoUrl: PLACEHOLDER_VIDEO,
      imageUrl: PLACEHOLDER_IMAGE,
      gallery: GALLERY_IMAGES.slice(0, 6),
    },
    {
      firstName: 'Jules',
      lastName: 'Lefebvre',
      displayName: 'Jules',
      bio: 'Jules est un expert du rasage à l\'ancienne et des coupes vintage. Il accueille les clients dans une ambiance authentique et soignée.',
      experienceYears: 10,
      level: 'expert',
      interests: ['Rasage à l\'ancienne', 'Coupe vintage', 'Barbe'],
      images: [PLACEHOLDER_IMAGE],
      salonIds: [salonGrenoble.id, salonVoiron.id],
      age: 38,
      origin: 'Chambéry',
      videoUrl: PLACEHOLDER_VIDEO,
      imageUrl: PLACEHOLDER_IMAGE,
      gallery: GALLERY_IMAGES.slice(0, 4),
    },
  ];

  let created = 0;
  for (const data of barbersData) {
    const { salonIds, ...barberData } = data;
    const existing = await prisma.barber.findFirst({
      where: {
        firstName: barberData.firstName,
        lastName: barberData.lastName,
      },
    });
    const firstSalonId = salonIds[0];
    if (existing) {
      await prisma.barber.update({
        where: { id: existing.id },
        data: {
          displayName: existing.displayName ?? barberData.displayName,
          level: existing.level || barberData.level,
          isActive: true,
          age: barberData.age,
          origin: barberData.origin,
          bio: barberData.bio,
          videoUrl: barberData.videoUrl,
          imageUrl: barberData.imageUrl,
          gallery: barberData.gallery,
          salonId: firstSalonId,
        },
      });
      const existingLinks = await prisma.barberSalon.findMany({
        where: { barberId: existing.id },
      });
      const existingSalonIds = new Set(existingLinks.map((l) => l.salonId));
      for (const salonId of salonIds) {
        if (!existingSalonIds.has(salonId)) {
          await prisma.barberSalon.create({
            data: { barberId: existing.id, salonId },
          });
        }
      }
      continue;
    }

    await prisma.barber.create({
      data: {
        firstName: barberData.firstName,
        lastName: barberData.lastName,
        displayName: barberData.displayName,
        bio: barberData.bio,
        experienceYears: barberData.experienceYears,
        level: barberData.level,
        interests: barberData.interests,
        images: barberData.images,
        isActive: true,
        age: barberData.age,
        origin: barberData.origin,
        videoUrl: barberData.videoUrl,
        imageUrl: barberData.imageUrl,
        gallery: barberData.gallery,
        salonId: firstSalonId,
        salons: {
          create: salonIds.map((salonId) => ({ salonId })),
        },
      },
    });
    created++;
  }

  const barberCountAfter = await prisma.barber.count();
  console.log(`Seed completed: ${created} barber(s) created. Total barbers in DB: ${barberCountAfter}.`);

  // 3. Create Simplified Offers (Duration and Images removed as requested)
  const offersData = [
    {
      title: 'Coupe classique',
      price: 25,
      isActive: true,
      salonId: salonGrenoble.id,
    },
    {
      title: 'Rasage à l’ancienne',
      price: 20,
      isActive: true,
      salonId: salonGrenoble.id,
    },
    {
      title: 'Taille de barbe',
      price: 15,
      isActive: true,
      salonId: salonVoiron.id,
    },
    {
      title: 'Coupe tendance',
      price: 28,
      isActive: true,
      salonId: salonMeylan.id,
    },
    {
      title: 'Soin complet',
      price: 40,
      isActive: true,
      salonId: salonMeylan.id,
    },
  ];

  // Idempotent offer seeding (safe to run multiple times)
  // Note: we do NOT delete existing offers in production.
  let offersCreated = 0;
  let offersUpdated = 0;
  for (const offer of offersData) {
    const existing = await prisma.offer.findFirst({
      where: { title: offer.title, salonId: offer.salonId },
    });
    if (existing) {
      await prisma.offer.update({
        where: { id: existing.id },
        data: { price: offer.price, isActive: offer.isActive },
      });
      offersUpdated++;
      continue;
    }
    await prisma.offer.create({ data: offer });
    offersCreated++;
  }

  console.log(
    `Seed completed: ${offersCreated} offer(s) created, ${offersUpdated} offer(s) updated (simplified structure).`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });