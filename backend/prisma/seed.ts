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

// Keep placeholders just in case
const PLACEHOLDER_IMAGE = 'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400';
const GALLERY_IMAGES = [
  'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400',
  'https://images.unsplash.com/photo-1622287162716-f311baa1a2b8?w=400',
  'https://images.unsplash.com/photo-1599351431202-1e0f0137899a?w=400',
  'https://images.unsplash.com/photo-1605499466077-3385ab955905?w=400',
  'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=400',
];

// --- LOCAL SERVER CONFIGURATION ---
// Use 10.0.2.2 for Android Emulator, or your LAN IP for physical device.
const BASE_URL = 'http://10.0.2.2:3000/images';
const getImg = (path: string) => `${BASE_URL}/${path}`;

function getBarberGallery(barberName: string) {
  // 1. Path to the folder on your computer
  // Adjust '../public' if your public folder is somewhere else relative to prisma folder
  const dirPath = path.join(process.cwd(), 'public/images/barbers', barberName.toLowerCase());

  try {
    if (!fs.existsSync(dirPath)) {
      console.warn(`⚠️ Warning: Folder not found for ${barberName} at ${dirPath}`);
      return []; // Return empty if folder doesn't exist
    }

    // 2. Read all files (jpg, png, mp4, etc.)
    const files = fs.readdirSync(dirPath);

    // 3. Convert filenames to http://10.0.2.2... URLs
    // Filters out system files like .DS_Store
    const validFiles = files.filter(file => !file.startsWith('.'));
    
    return validFiles.map(file => getImg(`barbers/${barberName.toLowerCase()}/${file}`));

  } catch (error) {
    console.error(`Error reading gallery for ${barberName}:`, error);
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
  await seedAdmin();

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
  // Based on your screenshots
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
      gallery: [IMAGES.barbers.tom, ...GALLERY_IMAGES.slice(0, 2)],
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
      gallery: [IMAGES.barbers.nathan, ...GALLERY_IMAGES.slice(0, 2)],
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
      gallery: [IMAGES.barbers.clement, ...GALLERY_IMAGES.slice(0, 2)],
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
      gallery: [IMAGES.barbers.lucas, ...GALLERY_IMAGES.slice(0, 2)],
    },
    {
      firstName: 'Julien',
      lastName: 'Morel', 
      displayName: 'Julien',
      bio: "Julien est originaire de Voiron et est arrivé à Grenoble en 2018. La coiffure est son premier métier, où il a travaillé en tant qu'employé jusqu'en 2023. Fondateur de BarberClub Grenoble en 2024 et Co-Fondateur de BarberClub Meylan en 2025, il a créé un lieu où passion, expertise et convivialité se rencontrent.",
      experienceYears: 7, 
      level: 'Fondateur',
      interests: ['Expertise', 'Convivialité'],
      salonIds: [salonMeylan.id], // Removed Grenoble to focus on his main salon
      age: 26,
      origin: 'Voiron',
      videoUrl: IMAGES.videos.julien,
      imageUrl: IMAGES.barbers.julien, 
      gallery: [IMAGES.barbers.julien, ...GALLERY_IMAGES.slice(0, 2)],
    },
    {
      // Alan reassigned to Grenoble since Voiron is gone
      firstName: 'Alan',
      lastName: 'Smith',
      displayName: 'Alan',
      bio: "Expert polyvalent, Alan vous accueille au salon pour une expérience barber authentique.",
      experienceYears: 4,
      level: 'Senior',
      interests: ['Barbe', 'Coupe'],
      salonIds: [salonGrenoble.id], // Moved to Grenoble
      age: 22,
      origin: 'Lyon',
      videoUrl: IMAGES.videos.alan,
      imageUrl: IMAGES.barbers.alan,
      gallery: [IMAGES.barbers.alan, ...GALLERY_IMAGES.slice(0, 2)],
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
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });