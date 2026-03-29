/**
 * Seed script: admin user + salons + barbers (coiffeurs) with links.
 *
 * Run AFTER migrations: npx prisma migrate dev
 * Then: npx prisma db seed
 */
// @ts-nocheck
/// <reference types="node" />

import path from 'path';
import fs from 'fs';
import { PrismaClient } from '@prisma/client';
import { hashPassword } from '../src/modules/auth/utils/password';

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
    where: { name: 'Barber Club Grenoble' },
  });

  const grenobleData = {
    name: 'Barber Club Grenoble',
    city: 'Grenoble',
    address: '12 rue de la République, 38000 Grenoble',
    description: 'Barber Club Grenoble est notre premier salon, ouvert au cœur de la ville. Un espace dédié à l\'art de la barberie.',
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    isActive: true,
    timifyUrl: 'https://book.timify.com/?accountId=662ab032662b882b9529faca&hideCloseButton=true',
    phone: '04 76 12 34 56',
    
    // Updated Real Images
    imageUrl: IMAGES.salons.grenoble.main,
    images: [IMAGES.salons.grenoble.main], 
    gallery: IMAGES.salons.grenoble.gallery,
    
    openingHoursStructured: OPENING_HOURS_STRUCTURED,
    latitude: 45.1885,
    longitude: 5.7245,
  };

  if (salonGrenoble) {
    salonGrenoble = await prisma.salon.update({ where: { id: salonGrenoble.id }, data: grenobleData });
  } else {
    salonGrenoble = await prisma.salon.create({ data: grenobleData });
  }

  // --- 2. SALON MEYLAN ---
  let salonMeylan = await prisma.salon.findFirst({
    where: { name: 'Barber Club Meylan' },
  });

  const meylanData = {
    name: 'Barber Club Meylan',
    city: 'Meylan',
    address: '8 avenue Jean Jaurès, 38240 Meylan',
    description: 'Le Barber Club Meylan vous propose les mêmes prestations que nos autres salons, dans un cadre moderne.',
    openingHours: 'Mar–Sam 9h–19h, Dim–Lun fermé',
    isActive: true,
    timifyUrl: 'https://book.timify.com/?accountId=68e13d325845e16b4feb0d4c&hideCloseButton=true',
    phone: '09 56 30 93 86',
    
    // Updated Real Images
    imageUrl: IMAGES.salons.meylan.main,
    images: [IMAGES.salons.meylan.main],
    gallery: IMAGES.salons.meylan.gallery,
    
    openingHoursStructured: OPENING_HOURS_STRUCTURED,
    latitude: 45.2092,
    longitude: 5.7814,
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
      bio: "Julien est originaire de Voiron et est arrivé à Grenoble en 2018. La coiffure est son premier métier, où il a travaillé en tant qu'employé jusqu'en 2023. Fondateur de BarberClub Grenoble en 2024 et Co-Fondateur de BarberClub Meylan en 2025, il a créé un lieu où passion, expertise et convivialité se rencontrent.",
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
    // GRENOBLE OFFERS
    { title: 'Coupe + Barbe', price: 30, isActive: true, salonId: salonGrenoble.id },
    { title: 'Coupe + Traçage Barbe', price: 25, isActive: true, salonId: salonGrenoble.id },
    { title: 'Coupe Homme', price: 20, isActive: true, salonId: salonGrenoble.id },
    { title: 'Barbe Uniquement', price: 15, isActive: true, salonId: salonGrenoble.id },
    { title: 'Tarif Étudiant', price: 15, isActive: true, salonId: salonGrenoble.id },

    // MEYLAN OFFERS
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

  for (const offer of offersData) {
    const existing = await prisma.offer.findFirst({ where: { title: offer.title, salonId: offer.salonId } });
    if (!existing) {
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

  // --- CLIENT OFFERS (promotions: event, flash, pack, permanent, welcome) ---
  const now = new Date();
  const inOneWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const inTwoDays = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);

  const salonOfferIds = await prisma.offer.findMany({
    where: { salonId: salonMeylan.id },
    select: { id: true },
    take: 4,
  });
  const applicableServiceIds = salonOfferIds.map((o) => o.id);

  const clientOffersData = [
    {
      type: 'event' as const,
      title: 'Offre limitée -15%',
      description: 'Profitez de -15% sur toutes les prestations jusqu\'à la fin de la semaine.',
      discountType: 'percentage' as const,
      discountValue: 15,
      applicableServices: [] as string[],
      startsAt: now,
      endsAt: inOneWeek,
      maxSpots: null,
      imageUrl: null,
      isActive: true,
    },
    {
      type: 'flash' as const,
      title: 'Flash: -10€ sur Coupe + Barbe',
      description: 'Places limitées. Réservez dans les 2 heures après activation.',
      discountType: 'fixed' as const,
      discountValue: 10,
      applicableServices: applicableServiceIds.length > 0 ? [applicableServiceIds[0]] : [],
      startsAt: now,
      endsAt: inTwoDays,
      maxSpots: 20,
      imageUrl: null,
      isActive: true,
    },
    {
      type: 'pack' as const,
      title: 'Pack Coupe + Barbe + Soin',
      description: 'Les trois prestations ensemble à prix pack. Économisez sur votre coupe, barbe et soin.',
      discountType: 'fixed' as const,
      discountValue: 49,
      applicableServices: applicableServiceIds,
      startsAt: now,
      endsAt: null,
      maxSpots: null,
      imageUrl: null,
      isActive: true,
    },
    {
      type: 'permanent' as const,
      title: 'Parrainage',
      description: 'Parrainez un ami: vous recevez tous les deux une réduction sur votre prochaine visite.',
      discountType: 'percentage' as const,
      discountValue: 10,
      applicableServices: [] as string[],
      startsAt: now,
      endsAt: null,
      maxSpots: null,
      imageUrl: null,
      isActive: true,
    },
    {
      type: 'permanent' as const,
      title: 'Offre anniversaire',
      description: 'À votre anniversaire, bénéficiez de -20% sur une prestation. Ajoutez votre date de naissance dans votre profil.',
      discountType: 'percentage' as const,
      discountValue: 20,
      applicableServices: [] as string[],
      startsAt: now,
      endsAt: null,
      maxSpots: null,
      imageUrl: null,
      isActive: true,
    },
    {
      type: 'welcome' as const,
      title: 'Bienvenue: -10%',
      description: 'Votre première visite au Barber Club: -10% sur une prestation. Valable 30 jours après inscription.',
      discountType: 'percentage' as const,
      discountValue: 10,
      applicableServices: [] as string[],
      startsAt: now,
      endsAt: null,
      maxSpots: null,
      imageUrl: null,
      isActive: true,
    },
  ];

  let clientOffersCreated = 0;
  for (const co of clientOffersData) {
    const existing = await prisma.clientOffer.findFirst({
      where: { title: co.title, type: co.type },
    });
    if (!existing) {
      await prisma.clientOffer.create({ data: co });
      clientOffersCreated++;
    }
  }
  console.log('Client offers (event, flash, pack, permanent, welcome):', clientOffersCreated, 'created.');

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