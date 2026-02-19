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

const GEO_EMAIL = 'georgiohayek2002@gmail.com';
const GEO_PASSWORD = 'barberclub123';
const GEO_FULL_NAME = 'Georgio Hayek';

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

async function seedGeorgioUser() {
  const existing = await prisma.user.findUnique({
    where: { email: GEO_EMAIL },
  });
  if (existing) return;

  const passwordHash = await hashPassword(GEO_PASSWORD);

  // Need a unique phoneNumber; try deterministic first, then fallback.
  const candidatePhones = [
    '+33600000001',
    '+33600000002',
    `+336${Math.floor(10000000 + Math.random() * 89999999)}`,
  ];

  for (const phoneNumber of candidatePhones) {
    try {
      await prisma.user.create({
        data: {
          email: GEO_EMAIL,
          phoneNumber,
          passwordHash,
          fullName: GEO_FULL_NAME,
          role: 'USER',
        },
      });
      console.log('Seed user created:', GEO_EMAIL);
      return;
    } catch (e) {
      // try next phone number
    }
  }

  console.warn('Seed user not created (phone uniqueness conflict):', GEO_EMAIL);
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

// Use relative paths so the client can resolve them with its API base URL.
// Express serves static files at /images -> public/images
const IMAGES_BASE = '/images';
const getImg = (path: string) => `${IMAGES_BASE}/${path}`;

// --- REAL DATA MAPPING ---
// Matches the filenames seen in your public/images directory
const IMAGES = {
  salons: {
    grenoble: {
      main: getImg('salons/grenoble/salon-grenoble.jpg'),
      gallery: [
        getImg('salons/grenoble/chaise-grenoble.jpg'),
        getImg('salons/grenoble/comptoir-grenoble.jpg'),
        getImg('salons/grenoble/miroir-grenoble.jpg'),
      ]
    },
    meylan: {
      main: getImg('salons/meylan/salon-meylan.jpg'),
      gallery: [
        getImg('salons/meylan/cologne-meylan.jpg'),
        getImg('salons/meylan/comptoir-meylan.jpg'),
        getImg('salons/meylan/devanture-meylan.jpg'),
        getImg('salons/meylan/parfums-meylan.jpg'),
        getImg('salons/meylan/salon-meylan-interieur.jpg'),
      ]
    },
  },
  barbers: {
    // Mapping filenames from your public/images/barbers folder
    alan: getImg('barbers/alan.png'),
    clement: getImg('barbers/clement.png'),
    julien: getImg('barbers/julien.jpg'),
    lucas: getImg('barbers/lucas.png'),
    nathan: getImg('barbers/nathan.png'),
    tom: getImg('barbers/tom.png'),
  },
  videos: {
    alan: getImg('barbers/alan.mp4'),
    tom: getImg('barbers/tom.mp4'),
    nathan: getImg('barbers/nathan.mp4'),
    clement: getImg('barbers/clement.mp4'),
    julien: getImg('barbers/julien.mp4'),
    lucas: getImg('barbers/lucas.mp4'),
  },
};

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
  await seedGeorgioUser();

  const barberCountBefore = await prisma.barber.count();
  console.log(`Barbers in DB before seed: ${barberCountBefore}`);

  // 1. Ensure salons exist (find or create by name)
  let salonGrenoble = await prisma.salon.findFirst({
    where: { name: 'Barber Club Grenoble' },
  });

  const grenobleData = {
    name: 'Barber Club Grenoble',
    city: 'Grenoble',
    address: '12 rue de la République, 38000 Grenoble',
    description:
      'Barber Club Grenoble est notre premier salon, ouvert au cœur de la ville. Un espace dédié à l\'art de la barberie.',
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    isActive: true,
    timifyUrl: 'https://book.timify.com/?accountId=662ab032662b882b9529faca&hideCloseButton=true',
    phone: '04 76 12 34 56',
    imageUrl: IMAGES.salons.grenoble.main,
    images: [IMAGES.salons.grenoble.main],
    gallery: IMAGES.salons.grenoble.gallery,
    openingHoursStructured: OPENING_HOURS_STRUCTURED,
    latitude: 45.1885,
    longitude: 5.7245,
  };

  if (salonGrenoble) {
    salonGrenoble = await prisma.salon.update({
      where: { id: salonGrenoble.id },
      data: grenobleData,
    });
  } else {
    salonGrenoble = await prisma.salon.create({ data: grenobleData });
  }

  // --- 3. SALON MEYLAN ---
  let salonMeylan = await prisma.salon.findFirst({
    where: { name: 'Barber Club Meylan' },
  });

  const meylanData = {
    name: 'Barber Club Meylan',
    city: 'Meylan',
    address: '8 avenue Jean Jaurès, 38240 Meylan',
    description:
      'Le Barber Club Meylan vous propose les mêmes prestations que nos autres salons, dans un cadre moderne.',
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    isActive: true,
    timifyUrl: 'https://book.timify.com/?accountId=68e13d325845e16b4feb0d4c&hideCloseButton=true',
    phone: '09 56 30 93 86',
    imageUrl: IMAGES.salons.meylan.main,
    images: [IMAGES.salons.meylan.main],
    gallery: IMAGES.salons.meylan.gallery,
    openingHoursStructured: OPENING_HOURS_STRUCTURED,
    latitude: 45.2092,
    longitude: 5.7814,
  };

  if (salonMeylan) {
    salonMeylan = await prisma.salon.update({
      where: { id: salonMeylan.id },
      data: meylanData,
    });
  } else {
    salonMeylan = await prisma.salon.create({ data: meylanData });
  }

  // If Voiron exists from previous seeds, deactivate it (no destructive delete).
  await prisma.salon.updateMany({
    where: { name: 'Barber Club Voiron' },
    data: { isActive: false },
  });

  // 2. Create barbers (coiffeurs) with age, origin, bio, videoUrl, gallery, salonId
  const barbersData = [
    {
      firstName: 'Tom',
      lastName: 'Martin',
      displayName: 'Tom',
      bio: "Tom vit à Chirens et a commencé à couper chez lui avant de se lancer professionnellement. Avec 2 ans d'expérience en salon, il a rejoint l'équipe BarberClub en 2025. Passionné et talentueux, Tom apporte sa créativité et son expertise pour transformer votre look.",
      experienceYears: 2,
      level: 'Expert',
      interests: ['Coupe classique', 'Rasage', 'Barbe'],
      images: [IMAGES.barbers.tom],
      salonIds: [salonGrenoble.id],
      age: 17,
      origin: 'Chirens',
      videoUrl: IMAGES.videos.tom,
      imageUrl: IMAGES.barbers.tom,
      gallery: GALLERY_IMAGES.slice(0, 2),
    },
    {
      firstName: 'Nathan',
      lastName: 'Dupont',
      displayName: 'Nathan',
      bio: "Nathan vit à Milan et a récemment rejoint l'équipe BarberClub après 1 an d'expérience à l'étranger. Il se distingue par son sens du détail et sa maîtrise des techniques classiques et modernes. Toujours à l'écoute, il prend le temps de comprendre vos attentes pour un résultat sur-mesure.",
      experienceYears: 1,
      level: 'Junior',
      interests: ['Détail', 'Technique classique', 'Modernité'],
      images: [IMAGES.barbers.nathan],
      salonIds: [salonGrenoble.id],
      age: 18,
      origin: 'Milan',
      videoUrl: IMAGES.videos.nathan,
      imageUrl: IMAGES.barbers.nathan,
      gallery: GALLERY_IMAGES.slice(0, 2),
    },
    {
      firstName: 'Clément',
      lastName: 'Leroi',
      displayName: 'Clément',
      bio: "Clément vit à Voiron et a débuté la coiffure il y a 3 ans, dont 1 an et demi en demi salon. Premier coiffeur à avoir rejoint le premier salon qui a ouvert à Grenoble, il combine technique impeccable et créativité pour des résultats qui font la différence.",
      experienceYears: 3,
      level: 'Senior',
      interests: ['Créativité', 'Technique'],
      images: [IMAGES.barbers.clement],
      salonIds: [salonGrenoble.id],
      age: 19,
      origin: 'Voiron',
      videoUrl: IMAGES.videos.clement,
      imageUrl: IMAGES.barbers.clement,
      gallery: GALLERY_IMAGES.slice(0, 2),
    },
    {
      firstName: 'Lucas',
      lastName: 'Bernard',
      displayName: 'Lucas',
      bio: "Lucas vit à Villard-Bonnot et est Co-fondateur de BarberClub Meylan en 2025. Avec 2 ans d'expérience, il est passionné par son métier et met un point d'honneur à offrir un service personnalisé. Spécialiste des coupes tendance et des finitions impeccables, il vous accueille au salon de Meylan.",
      experienceYears: 2,
      level: 'Co-fondateur',
      interests: ['Coupe tendance', 'Finitions', 'Service client'],
      images: [IMAGES.barbers.lucas],
      salonIds: [salonMeylan.id],
      age: 25,
      origin: 'Villard-Bonnot',
      videoUrl: IMAGES.videos.lucas,
      imageUrl: IMAGES.barbers.lucas,
      gallery: GALLERY_IMAGES.slice(0, 2),
    },
    {
      firstName: 'Julien',
      lastName: 'Morel',
      displayName: 'Julien',
      bio: "Julien est originaire de Voiron et est arrivé à Grenoble en 2018. La coiffure est son premier métier, où il a travaillé en tant qu'employé jusqu'en 2023. Fondateur de BarberClub Grenoble en 2024 et Co-Fondateur de BarberClub Meylan en 2025, il a créé un lieu où passion, expertise et convivialité se rencontrent.",
      experienceYears: 7,
      level: 'Fondateur',
      interests: ['Expertise', 'Convivialité'],
      images: [IMAGES.barbers.julien],
      salonIds: [salonMeylan.id],
      age: 26,
      origin: 'Voiron',
      videoUrl: IMAGES.videos.julien,
      imageUrl: IMAGES.barbers.julien,
      gallery: GALLERY_IMAGES.slice(0, 2),
    },
    {
      firstName: 'Alan',
      lastName: 'Smith',
      displayName: 'Alan',
      bio: "Expert polyvalent, Alan vous accueille au salon pour une expérience barber authentique.",
      experienceYears: 4,
      level: 'Senior',
      interests: ['Barbe', 'Coupe'],
      images: [IMAGES.barbers.alan],
      salonIds: [salonGrenoble.id],
      age: 22,
      origin: 'Lyon',
      videoUrl: IMAGES.videos.alan,
      imageUrl: IMAGES.barbers.alan,
      gallery: GALLERY_IMAGES.slice(0, 2),
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

  // Deactivate any barbers not in the current seed list (keeps DB clean without deletes).
  const seedKeys = new Set(barbersData.map((b) => `${b.firstName} ${b.lastName}`));
  const existingBarbers = await prisma.barber.findMany({
    select: { id: true, firstName: true, lastName: true },
  });
  for (const b of existingBarbers) {
    const key = `${b.firstName} ${b.lastName}`;
    if (!seedKeys.has(key)) {
      await prisma.barber.update({ where: { id: b.id }, data: { isActive: false } });
    }
  }

  // 3. OFFERS (matches provided list)
  const offersData = [
    // GRENOBLE
    { title: 'Coupe + Barbe', price: 30, isActive: true, salonId: salonGrenoble.id },
    { title: 'Coupe + Traçage Barbe', price: 25, isActive: true, salonId: salonGrenoble.id },
    { title: 'Coupe Homme', price: 20, isActive: true, salonId: salonGrenoble.id },
    { title: 'Barbe Uniquement', price: 15, isActive: true, salonId: salonGrenoble.id },
    { title: 'Tarif Étudiant', price: 15, isActive: true, salonId: salonGrenoble.id },

    // MEYLAN
    { title: 'Coupe + Barbe + Soin Complet', price: 48, isActive: true, salonId: salonMeylan.id },
    { title: 'Coupe + Barbe', price: 38, isActive: true, salonId: salonMeylan.id },
    { title: 'Coupe + Traçage Barbe', price: 33, isActive: true, salonId: salonMeylan.id },
    { title: 'Coupe Homme', price: 27, isActive: true, salonId: salonMeylan.id },
    { title: 'Barbe Uniquement', price: 20, isActive: true, salonId: salonMeylan.id },
    { title: 'Soin Visage + Barbe', price: 20, isActive: true, salonId: salonMeylan.id },
    { title: 'Coupe Étudiante', price: 24, isActive: true, salonId: salonMeylan.id },
    { title: 'Coupe Partenaire', price: 24, isActive: true, salonId: salonMeylan.id },
    { title: 'Coupe + Traçage Partenaire', price: 29, isActive: true, salonId: salonMeylan.id },
    { title: 'Coupe + Barbe Partenaire', price: 33, isActive: true, salonId: salonMeylan.id },
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

  // Deactivate offers not in seed list for these salons (no deletes).
  const offerTitlesGrenoble = new Set(
    offersData.filter((o) => o.salonId === salonGrenoble.id).map((o) => o.title),
  );
  const offerTitlesMeylan = new Set(
    offersData.filter((o) => o.salonId === salonMeylan.id).map((o) => o.title),
  );
  const existingOffers = await prisma.offer.findMany({
    where: { salonId: { in: [salonGrenoble.id, salonMeylan.id] } },
    select: { id: true, title: true, salonId: true },
  });
  for (const o of existingOffers) {
    const keep = o.salonId === salonGrenoble.id ? offerTitlesGrenoble.has(o.title) : offerTitlesMeylan.has(o.title);
    if (!keep) {
      await prisma.offer.update({ where: { id: o.id }, data: { isActive: false } });
    }
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