/**
 * Seed script: admin user + salons + barbers (coiffeurs) with links.
 *
 * Local (TypeScript, no build): npm run prisma:seed
 * After migrations: npx prisma migrate dev
 *
 * Prisma CLI (Docker/Railway/production): requires compiled output first.
 *   npm run build && npx prisma db seed
 * The prisma.seed command runs: node dist/prisma/seed.js (tsx is not installed in prod).
 */

// @ts-nocheck
/// <reference types="node" />

import path from 'path';
import fs from 'fs';
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/utils/password';
import { syncWebsiteOffers } from '../src/modules/client_offers/website_offers';

const prisma = new PrismaClient();

const ADMIN_PASSWORD = 'admin123';

async function seedAdminsPerSalon() {
  const salons = await prisma.salon.findMany({
    select: { id: true, name: true },
    orderBy: { name: 'asc' },
  });

  const passwordHash = await hashPassword(ADMIN_PASSWORD);

  for (let i = 0; i < salons.length; i++) {
    const salon = salons[i];
    const slug = salon.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');
    const email = `admin_${slug}@barberclub.com`;
    const phoneNumber = `+336${String(i + 1).padStart(8, '0')}`;

    const admin = await prisma.user.upsert({
      where: { email },
      update: {
        role: 'ADMIN',
        isSuperAdmin: false,
        phoneNumber,
      },
      create: {
        email,
        phoneNumber,
        passwordHash,
        fullName: `Admin ${salon.name}`,
        role: 'ADMIN',
        isSuperAdmin: false,
      },
    });

    await prisma.user.update({
      where: { id: admin.id },
      data: {
        adminSalons: {
          set: [{ id: salon.id }],
        },
      },
    });
  }

  const superAdminEmail = 'superadmin@barberclub.com';
  const superAdminPhone = '+33999999999';
  const superAdmin = await prisma.user.upsert({
    where: { email: superAdminEmail },
    update: {
      role: 'ADMIN',
      isSuperAdmin: true,
      phoneNumber: superAdminPhone,
    },
    create: {
      email: superAdminEmail,
      phoneNumber: superAdminPhone,
      passwordHash,
      fullName: 'Super Admin',
      role: 'ADMIN',
      isSuperAdmin: true,
    },
  });

  console.log('Seeded admins for salons and super admin', {
    salonAdmins: salons.length,
    superAdminId: superAdmin.id,
  });
}

// Keep placeholders just in case
const PLACEHOLDER_IMAGE = 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400';
const GALLERY_IMAGES = [
  'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400',
  'https://images.unsplash.com/photo-1622287162716-f311baa1a2b8?w=400',
  'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=400',
  'https://images.unsplash.com/photo-1605499466077-3385ab955905?w=400',
  'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=400',
];

// --- IMAGE PATHS: relative so the app can prepend its apiBaseUrl (emulator, device, or production) ---
const getImg = (relativePath: string) => `/images/${relativePath}`;

function getBarberGallery(folderName: string) {
  // 1. Path to the specific folder based on your screenshot
  const dirPath = path.join(process.cwd(), 'public/images/barbers', folderName);

  try {
    if (!fs.existsSync(dirPath)) {
      console.warn(`⚠️ Warning: Folder not found at ${dirPath}`);
      return []; 
    }

    // 2. Read all files
    const files = fs.readdirSync(dirPath);

    // 3. Filter for valid IMAGE extensions only (ignores .mp4, .DS_Store, etc.)
    const validImageExts = ['.jpg', '.jpeg', '.png', '.avif', '.webp'];
    const imageFiles = files.filter(file => {
      if (file.startsWith('.')) return false;
      const ext = path.extname(file).toLowerCase();
      return validImageExts.includes(ext);
    });
    
    // 4. Return the mapped paths
    return imageFiles.map(file => getImg(`barbers/${folderName}/${file}`));

  } catch (error) {
    console.error(`Error reading gallery for ${folderName}:`, error);
    return [];
  }
}                                         
// --- REAL DATA MAPPING ---
const IMAGES = {
  salons: {
    grenoble: {
      main: getImg('salons/grenoble/salon-grenoble.webp'),
      gallery: [
        getImg('salons/grenoble/chaise-grenoble.webp'),
        getImg('salons/grenoble/comptoir-grenoble.webp'),
        getImg('salons/grenoble/miroir-grenoble.webp'),
      ]
    },
    meylan: {
      main: getImg('salons/meylan/salon-meylan.webp'),
      gallery: [
        getImg('salons/meylan/cologne-meylan.webp'),
        getImg('salons/meylan/comptoir-meylan.webp'),
        getImg('salons/meylan/devanture-meylan.webp'),
        getImg('salons/meylan/parfums-meylan.webp'),
        getImg('salons/meylan/salon-meylan-interieur.webp'),
      ]
    }
  },
  barbers: {
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
  }
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
  await seedAdminsPerSalon();

  // --- 1. SALON GRENOBLE ---
  let salonGrenoble = await prisma.salon.findFirst({
    where: {
      OR: [
        { websiteId: 'grenoble' },
        { name: 'Barber Club Grenoble' },
      ],
    },
  });

  const grenobleData = {
    name: 'Barber Club Grenoble',
    websiteId: 'grenoble',
    city: 'Grenoble',
    address: '5 Rue Clôt Bey, 38000 Grenoble',
    location: 'Centre Ville',
    description: 'Barber Club Grenoble est notre premier salon, ouvert au cœur de la ville. Un espace dédié à l\'art de la barberie.',
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    isActive: true,
    timifyUrl: 'https://book.timify.com/?accountId=662ab032662b882b9529faca&hideCloseButton=true',
    phone: '09 56 30 93 86',

    // Updated Real Images
    imageUrl: IMAGES.salons.grenoble.main,
    images: [IMAGES.salons.grenoble.main],
    gallery: IMAGES.salons.grenoble.gallery,

    openingHoursStructured: OPENING_HOURS_STRUCTURED,
    latitude: 45.18955,
    longitude: 5.72355,
  };

  if (salonGrenoble) {
    salonGrenoble = await prisma.salon.update({ where: { id: salonGrenoble.id }, data: grenobleData });
  } else {
    salonGrenoble = await prisma.salon.create({ data: grenobleData });
  }

  // --- 2. SALON MEYLAN ---
  let salonMeylan = await prisma.salon.findFirst({
    where: {
      OR: [
        { websiteId: 'meylan' },
        { name: 'Barber Club Meylan' },
      ],
    },
  });

  const meylanData = {
    name: 'Barber Club Meylan',
    websiteId: 'meylan',
    city: 'Meylan',
    address: '26 Av. du Grésivaudan, 38700 Corenc',
    location: 'Près de corenc',
    description: 'Le Barber Club Meylan vous propose les mêmes prestations que nos autres salons, dans un cadre moderne.',
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    isActive: true,
    timifyUrl: 'https://book.timify.com/?accountId=68e13d325845e16b4feb0d4c&hideCloseButton=true',
    phone: '04 58 28 21 75',

    // Updated Real Images
    imageUrl: IMAGES.salons.meylan.main,
    images: [IMAGES.salons.meylan.main],
    gallery: IMAGES.salons.meylan.gallery,

    openingHoursStructured: OPENING_HOURS_STRUCTURED,
    latitude: 45.2105,
    longitude: 5.7625,
  };

  if (salonMeylan) {
    salonMeylan = await prisma.salon.update({ where: { id: salonMeylan.id }, data: meylanData });
  } else {
    salonMeylan = await prisma.salon.create({ data: meylanData });
  }
// --- 3. BARBERS ---
  const barbersData = [
    {
      firstName: 'Tom',
      lastName: 'Martin', 
      displayName: 'Tom',
      bio: "Tom vit à Chirens et a commencé à couper chez lui avant de se lancer professionnellement. Avec 2 ans d'expérience en salon, il a rejoint l'équipe BarberClub en 2025. Passionné et talentueux, Tom apporte sa créativité et son expertise pour transformer votre look.",
      experienceYears: 2,
      level: 'Expert',
      interests: ['Coupe classique', 'Rasage', 'Barbe'],
      salonIds: [salonGrenoble.id],
      age: 17,
      origin: 'Chirens',
      videoUrl: IMAGES.videos.tom,
      imageUrl: IMAGES.barbers.tom,
      // Uses the "Coupes TOM" folder
      gallery: [IMAGES.barbers.tom, ...getBarberGallery('Coupes TOM')],
    },
    {
      firstName: 'Nathan',
      lastName: 'Dupont', 
      displayName: 'Nathan',
      bio: "Nathan vit à Milan et a récemment rejoint l'équipe BarberClub après 1 an d'expérience à l'étranger. Il se distingue par son sens du détail et sa maîtrise des techniques classiques et modernes. Toujours à l'écoute, il prend le temps de comprendre vos attentes pour un résultat sur-mesure.",
      experienceYears: 1,
      level: 'Junior',
      interests: ['Détail', 'Technique classique', 'Modernité'],
      salonIds: [salonGrenoble.id],
      age: 18,
      origin: 'Milan',
      videoUrl: IMAGES.videos.nathan,
      imageUrl: IMAGES.barbers.nathan,
      // Uses the "Coupe Nathan" folder
      gallery: [IMAGES.barbers.nathan, ...getBarberGallery('Coupe Nathan')],
    },
    {
      firstName: 'Clément',
      lastName: 'Leroi', 
      displayName: 'Clément',
      bio: "Clément vit à Voiron et a débuté la coiffure il y a 3 ans, dont 1 an et demi en demi salon. Premier coiffeur à avoir rejoint le premier salon qui a ouvert à Grenoble, il combine technique impeccable et créativité pour des résultats qui font la différence.",
      experienceYears: 3,
      level: 'Senior',
      interests: ['Créativité', 'Technique'],
      salonIds: [salonGrenoble.id],
      age: 19,
      origin: 'Voiron',
      videoUrl: IMAGES.videos.clement,
      imageUrl: IMAGES.barbers.clement,
      // Uses the "coupes-clement" folder
      gallery: [IMAGES.barbers.clement, ...getBarberGallery('coupes-clement')],
    },
    {
      firstName: 'Lucas',
      lastName: 'Bernard',
      displayName: 'Lucas',
      bio: "Lucas vit à Villard-Bonnot et est Co-fondateur de BarberClub Meylan en 2025. Avec 2 ans d'expérience, il est passionné par son métier et met un point d'honneur à offrir un service personnalisé. Spécialiste des coupes tendance et des finitions impeccables, il vous accueille au salon de Meylan.",
      experienceYears: 2,
      level: 'Co-fondateur',
      interests: ['Coupe tendance', 'Finitions', 'Service client'],
      salonIds: [salonMeylan.id], 
      age: 25,
      origin: 'Villard-Bonnot',
      videoUrl: IMAGES.videos.lucas,
      imageUrl: IMAGES.barbers.lucas,
      // Uses the "Coupe Lucas" folder
      gallery: [IMAGES.barbers.lucas, ...getBarberGallery('Coupe Lucas')],
    },
    {
      firstName: 'Julien',
      lastName: 'Morel', 
      displayName: 'Julien',
      bio: "Julien a débuté son expérience en tant que barber depuis 2018. Fort d'une expérience dans plusieurs salons où il a travaillé jusqu'en 2023. Fondateur de BarberClub Grenoble en 2024 et Co-Fondateur de BarberClub Meylan en 2025, il a créé un lieu où passion, expertise et convivialité se rencontrent.",
      experienceYears: 7, 
      level: 'Fondateur',
      interests: ['Expertise', 'Convivialité'],
      salonIds: [salonMeylan.id],
      age: 26,
      origin: 'Voiron',
      videoUrl: IMAGES.videos.julien,
      imageUrl: IMAGES.barbers.julien, 
      // Uses the "Coupe Ju" folder
      gallery: [IMAGES.barbers.julien, ...getBarberGallery('Coupe Ju')],
    },
    {
      firstName: 'Alan',
      lastName: 'Smith',
      displayName: 'Alan',
      bio: "Expert polyvalent, Alan vous accueille au salon pour une expérience barber authentique.",
      experienceYears: 4,
      level: 'Senior',
      interests: ['Barbe', 'Coupe'],
      salonIds: [salonGrenoble.id], 
      age: 22,
      origin: 'Lyon',
      videoUrl: IMAGES.videos.alan,
      imageUrl: IMAGES.barbers.alan,
      // Uses the "Coupe Alan" folder
      gallery: [IMAGES.barbers.alan, ...getBarberGallery('Coupe Alan')],
    },
  ];

  let created = 0;
  for (const data of barbersData) {
    const { salonIds, ...barberData } = data; 
    
    // Check if barber exists by First Name + Last Name
    const existing = await prisma.barber.findFirst({
      where: { firstName: barberData.firstName, lastName: barberData.lastName },
    });
    
    const firstSalonId = salonIds[0];

    const updateData = {
      displayName: barberData.displayName,
      bio: barberData.bio,
      experienceYears: barberData.experienceYears,
      level: barberData.level,
      interests: barberData.interests,
      isActive: true,
      age: barberData.age,
      origin: barberData.origin,
      videoUrl: barberData.videoUrl,
      imageUrl: barberData.imageUrl,
      // IMPORTANT: Update both image fields
      images: [barberData.imageUrl], 
      gallery: barberData.gallery,
      salonId: firstSalonId,
    };

    if (existing) {
      await prisma.barber.update({
        where: { id: existing.id },
        data: updateData,
      });
      
      // Update relations
      const existingLinks = await prisma.barberSalon.findMany({ where: { barberId: existing.id } });
      const existingSalonIds = new Set(existingLinks.map((l) => l.salonId));
      for (const salonId of salonIds) {
        if (!existingSalonIds.has(salonId)) {
          await prisma.barberSalon.create({ data: { barberId: existing.id, salonId } });
        }
      }
      continue;
    }

    await prisma.barber.create({
      data: {
        firstName: barberData.firstName,
        lastName: barberData.lastName,
        ...updateData,
        salons: {
          create: salonIds.map((salonId) => ({ salonId })),
        },
      },
    });
    created++;
  }

  console.log(`Seed completed: ${created} new/updated barbers processed.`);
  
// --- OFFERS (Simplified) ---
  const offersData = [
    // --- GRENOBLE OFFERS ---
    { title: 'Coupe Homme', price: 20, isActive: true, orderIndex: 1, salonId: salonGrenoble.id },
    { title: 'Coupe + Traçage Barbe', price: 25, isActive: true, orderIndex: 2, salonId: salonGrenoble.id },
    { title: 'Coupe + Barbe', price: 30, isActive: true, orderIndex: 3, salonId: salonGrenoble.id },
    { title: 'Barbe Uniquement', price: 15, isActive: true, orderIndex: 4, salonId: salonGrenoble.id },
    { title: 'Tarif Étudiant', price: 15, isActive: true, orderIndex: 5, salonId: salonGrenoble.id },
    { title: 'Enfant -12 ans', price: 15, isActive: true, orderIndex: 6, salonId: salonGrenoble.id },

    // --- MEYLAN OFFERS ---
    { title: 'Coupe Homme', price: 27, isActive: true, orderIndex: 1, salonId: salonMeylan.id },
    { title: 'Coupe + Traçage Barbe', price: 33, isActive: true, orderIndex: 2, salonId: salonMeylan.id },
    { title: 'Coupe + Barbe', price: 38, isActive: true, orderIndex: 3, salonId: salonMeylan.id },
    { title: 'Coupe + Barbe + Soin Complet', price: 48, isActive: true, orderIndex: 4, salonId: salonMeylan.id },
    { title: 'Barbe Uniquement', price: 20, isActive: true, orderIndex: 5, salonId: salonMeylan.id },
    { title: 'Soin Visage + Barbe', price: 30, isActive: true, orderIndex: 6, salonId: salonMeylan.id }, // Corrected price to 30€
    { title: 'Coupe Étudiante', price: 24, isActive: true, orderIndex: 7, salonId: salonMeylan.id },
    { title: 'Coupe Partenaire', price: 24, isActive: true, orderIndex: 8, salonId: salonMeylan.id },
    { title: 'Coupe + Traçage Partenaire', price: 29, isActive: true, orderIndex: 9, salonId: salonMeylan.id },
    { title: 'Coupe + Barbe Partenaire', price: 33, isActive: true, orderIndex: 10, salonId: salonMeylan.id },
  ];

  for (const offer of offersData) {
    const existing = await prisma.offer.findFirst({ 
      where: { title: offer.title, salonId: offer.salonId } 
    });
    
    // If it exists, update it so it gets the new orderIndex and price corrections.
    if (existing) {
      await prisma.offer.update({
        where: { id: existing.id },
        data: offer,
      });
    } else {
      await prisma.offer.create({ data: offer });
    }
  }

  // --- GLOBAL OFFERS (promotions, Offres tab - table global_offers) ---
  console.log('Seeding global offers (offres)...');
  const globalOffersData = [
    {
      title: 'Première visite',
      description: 'Bienvenue au Barber Club. Bénéficiez d\'un tarif privilégié pour votre première coupe ou barbe dans l\'un de nos salons.',
      imageUrl: null,
      discount: 10,
      isActive: true,
    },
    {
      title: 'Duo coupe + barbe',
      description: 'Coupe et barbe ensemble dans tous nos salons. Une expérience complète à prix avantageux.',
      imageUrl: null,
      discount: 15,
      isActive: true,
    },
    {
      title: 'Offre fidélité',
      description: 'Après 5 passages, une coupe ou barbe offerte. Valable dans tous les salons Barber Club.',
      imageUrl: null,
      discount: null,
      isActive: true,
    },
  ];

  let globalCreated = 0;
  for (const go of globalOffersData) {
    const existing = await prisma.globalOffer.findFirst({ where: { title: go.title } });
    if (!existing) {
      await prisma.globalOffer.create({ data: go });
      globalCreated++;
    }
  }
  console.log('Global offers (offres):', globalCreated, 'created,', globalOffersData.length - globalCreated, 'already present.');

  // --- CLIENT OFFERS (public feed synced to website) ---
  await syncWebsiteOffers(prisma);
  console.log('Client offers synced from website: BarberClub Carte Cadeau + welcome offer.');

  // --- Loyalty v2 rewards (idempotent) ---
  const loyaltyRewardsData = [
    { name: 'Cire ou Poudre au choix', costPoints: 160, description: 'Cire ou poudre au choix', imageUrl: '/images/rewards/placeholder.png', isActive: true },
    { name: 'Soin visage offert', costPoints: 200, description: 'Soin visage offert', imageUrl: '/images/rewards/placeholder.png', isActive: true },
    { name: '-25% sur une coupe', costPoints: 250, description: 'Réduction 25% sur une coupe', imageUrl: '/images/rewards/placeholder.png', isActive: true },
  ];
  for (const r of loyaltyRewardsData) {
    const existing = await prisma.loyaltyReward.findFirst({ where: { name: r.name } });
    if (!existing) {
      await prisma.loyaltyReward.create({ data: r });
    }
  }
  console.log('Loyalty rewards seeded.');

  // --- Backfill LoyaltyAccount for existing users (idempotent) ---
  const users = await prisma.user.findMany({ select: { id: true } });
  for (const u of users) {
    await prisma.loyaltyAccount.upsert({
      where: { userId: u.id },
      create: { userId: u.id },
      update: {},
    });
  }
  console.log('LoyaltyAccount backfill:', users.length, 'users.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
