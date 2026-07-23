import fs from 'fs';
import os from 'os';
import path from 'path';
import { Prisma, PrismaClient } from '@prisma/client';

const RECOVERY_CONFIRMATION = 'restore-catalog-20260723';
const targetDatabaseUrl = process.env.RECOVERY_DATABASE_URL?.trim();

if (!targetDatabaseUrl) {
  throw new Error('RECOVERY_DATABASE_URL is required.');
}

if (process.env.RECOVERY_CONFIRM !== RECOVERY_CONFIRMATION) {
  throw new Error(
    `Refusing to write without RECOVERY_CONFIRM=${RECOVERY_CONFIRMATION}.`,
  );
}

const decodedPath = path.join(
  os.homedir(),
  'Barber-Recovery',
  'catalog-tuples-decoded.json',
);

if (!fs.existsSync(decodedPath)) {
  throw new Error(`Decoded heap recovery file is missing: ${decodedPath}`);
}

interface DecodedBarber {
  id: string;
  firstName: string;
  lastName: string;
  displayName: string | null;
  bio: string | null;
  experienceYears: number | null;
  interests: string[];
  images: string[];
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  level: string;
  age: number | null;
  gallery: string[];
  imageUrl: string | null;
  origin: string | null;
  role: string;
  salonId: string | null;
  videoUrl: string | null;
}

interface DecodedRecovery {
  relations: {
    barbers: DecodedBarber[];
  };
}

const decoded = JSON.parse(
  fs.readFileSync(decodedPath, 'utf8'),
) as DecodedRecovery;

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: targetDatabaseUrl,
    },
  },
});

const salonIds = {
  grenoble: 'cdc66f3c-eabb-4b58-bc34-d74a5781bfa9',
  meylan: '6a931b98-9160-47af-a7bd-f5a1369b5bc0',
  voiron: 'e1a2cc5c-641a-4a81-a79e-d69b324c9ba9',
} as const;

const activeBarberRecovery = [
  {
    firstName: 'Tom',
    lastName: 'Martin',
    id: '51a141ea-4565-40e1-a026-c0438d47501a',
    salonId: salonIds.grenoble,
  },
  {
    firstName: 'Nathan',
    lastName: 'Dupont',
    id: '70c5bd83-1402-43fa-9db3-c2de84fa98a8',
    salonId: salonIds.grenoble,
  },
  {
    firstName: 'Clément',
    lastName: 'Leroi',
    id: '1b9c2c87-8d61-4b96-ae4e-44e168696bda',
    salonId: salonIds.grenoble,
  },
  {
    firstName: 'Lucas',
    lastName: 'Bernard',
    id: '0cc659f0-4bd4-4e53-816c-c77f4628b42e',
    salonId: salonIds.meylan,
  },
  {
    firstName: 'Julien',
    lastName: 'Morel',
    id: '62463742-8527-4ac5-8c52-5b9ae33d34b9',
    salonId: salonIds.meylan,
  },
  {
    firstName: 'Alan',
    lastName: 'Smith',
    id: '34fff522-b16e-441a-8689-74bf66349bb8',
    salonId: salonIds.grenoble,
  },
] as const;

const inactiveBarberIds = new Set([
  '4650582e-9d0d-4d39-9152-d395a41c3d68',
  '0b237140-c800-49b8-852e-e8b3ff6a15b0',
  '1d67d26d-f873-47fc-8ad0-59185725eafa',
  '2c4b7c3e-ec2b-456c-a27a-f25ab1d97dc4',
  '6d51bdb1-a07d-4175-b6b7-551f2364adfe',
]);

const barberSalonLinks = [
  ['2c4b7c3e-ec2b-456c-a27a-f25ab1d97dc4', salonIds.grenoble],
  ['6d51bdb1-a07d-4175-b6b7-551f2364adfe', salonIds.grenoble],
  ['4650582e-9d0d-4d39-9152-d395a41c3d68', salonIds.voiron],
  ['0b237140-c800-49b8-852e-e8b3ff6a15b0', salonIds.meylan],
  ['1d67d26d-f873-47fc-8ad0-59185725eafa', salonIds.voiron],
  ['1d67d26d-f873-47fc-8ad0-59185725eafa', salonIds.grenoble],
  ['51a141ea-4565-40e1-a026-c0438d47501a', salonIds.grenoble],
  ['0cc659f0-4bd4-4e53-816c-c77f4628b42e', salonIds.meylan],
  ['70c5bd83-1402-43fa-9db3-c2de84fa98a8', salonIds.grenoble],
  ['62463742-8527-4ac5-8c52-5b9ae33d34b9', salonIds.meylan],
  ['34fff522-b16e-441a-8689-74bf66349bb8', salonIds.grenoble],
  ['1b9c2c87-8d61-4b96-ae4e-44e168696bda', salonIds.grenoble],
] as const;

const currentOfferIds: Record<string, string> = {
  'grenoble|Coupe Homme': '9bc28eed-2e1e-4eda-b2cd-846f594c1263',
  'grenoble|Coupe + Traçage Barbe': '507b1969-9b29-42f6-ad95-b3483f6b3e10',
  'grenoble|Coupe + Barbe': '133bb12d-c72e-49df-8bcd-9efeb3a307bc',
  'grenoble|Barbe Uniquement': '9221ee67-9595-4e06-9f2f-47668b4e630f',
  'grenoble|Tarif Étudiant': '98a5474f-3bed-49dc-af1b-e244998fd512',
  'grenoble|Enfant -12 ans': 'b6d0c063-8365-4320-b614-f79fb6a9ab5d',
  'meylan|Coupe Homme': '9c44c720-5f87-4d6c-b9d8-d007e0b9ced5',
  'meylan|Coupe + Traçage Barbe': '187a84d0-47dc-408e-af8d-b5e4d6eaca08',
  'meylan|Coupe + Barbe': '6b305da0-a138-4530-a4cd-c5c44f9e96de',
  'meylan|Coupe + Barbe + Soin Complet':
    'a1069ae6-94b8-4ddc-b9e9-79edd90ceafd',
  'meylan|Barbe Uniquement': 'eb573a0f-ac25-49e0-8491-a908a81ce447',
  'meylan|Soin Visage + Barbe': 'b74c9302-01fe-4b68-82c5-f3ebed5aceb8',
  'meylan|Coupe Étudiante': 'e31cea28-16c0-4e85-af0b-7f0cbc751ea2',
  'meylan|Coupe Partenaire': 'ac6f2489-df11-4e93-b53d-7961d1fb1ac4',
  'meylan|Coupe + Traçage Partenaire':
    '6831de27-cf72-4dd7-8b3c-cca1bbbde27c',
  'meylan|Coupe + Barbe Partenaire':
    'f60a91e3-c9ac-415c-be7d-911277ac3a03',
};

const placeholderImage =
  'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=400';

async function main(): Promise<void> {
  const [currentSalons, currentBarbers, currentOffers, currentCounts] =
    await Promise.all([
      prisma.salon.findMany(),
      prisma.barber.findMany(),
      prisma.offer.findMany(),
      Promise.all([
        prisma.salon.count(),
        prisma.barber.count(),
        prisma.barberSalon.count(),
        prisma.offer.count(),
      ]),
    ]);

  const expectedCounts = [2, 6, 6, 16];
  if (currentCounts.some((count, index) => count !== expectedCounts[index])) {
    throw new Error(
      `Unexpected starting catalog counts: ${currentCounts.join(', ')}; ` +
        `expected ${expectedCounts.join(', ')}.`,
    );
  }

  const currentSalonByWebsiteId = new Map(
    currentSalons.map((salon) => [salon.websiteId, salon]),
  );
  const grenoble = currentSalonByWebsiteId.get('grenoble');
  const meylan = currentSalonByWebsiteId.get('meylan');

  if (!grenoble || !meylan) {
    throw new Error('The temporary two-salon catalog is not in the expected state.');
  }

  const recoveredSalons: Prisma.SalonCreateManyInput[] = [
    {
      ...grenoble,
      id: salonIds.grenoble,
    },
    {
      ...meylan,
      id: salonIds.meylan,
    },
    {
      id: salonIds.voiron,
      name: 'Barber Club Voiron',
      city: 'Voiron',
      address: '5 place du Marché, 38500 Voiron',
      description:
        "Notre salon de Voiron reprend l'ADN Barber Club : un cadre soigné, des prestations premium et une équipe formée aux dernières tendances.",
      openingHours: 'Mar–Ven 9h30–19h, Sam 9h–18h, Dim–Lun fermé',
      images: [placeholderImage],
      imageUrl: null,
      gallery: [],
      isActive: false,
      timifyUrl: 'https://www.timify.com/fr-fr/profile/barber-club-voiron/',
      phone: '',
      location: null,
      websiteId: null,
      latitude: null,
      longitude: null,
      openingHoursStructured: Prisma.JsonNull,
      createdAt: new Date('2026-02-14T10:39:44.000Z'),
      updatedAt: new Date('2026-02-19T02:02:44.000Z'),
    },
  ];

  const deadBarbers = decoded.relations.barbers.filter((barber) =>
    inactiveBarberIds.has(barber.id),
  );

  if (deadBarbers.length !== inactiveBarberIds.size) {
    throw new Error(
      `Recovered ${deadBarbers.length} inactive barber rows; expected ${inactiveBarberIds.size}.`,
    );
  }

  const activeSourceByName = new Map(
    currentBarbers.map((barber) => [
      `${barber.firstName}|${barber.lastName}`,
      barber,
    ]),
  );

  const recoveredBarbers: Prisma.BarberCreateManyInput[] = deadBarbers.map(
    (barber) => ({
      id: barber.id,
      firstName: barber.firstName,
      lastName: barber.lastName,
      displayName: barber.displayName,
      bio: barber.bio,
      experienceYears: barber.experienceYears,
      level: barber.level,
      interests: barber.interests,
      images: barber.images,
      isActive: barber.isActive,
      createdAt: new Date(barber.createdAt),
      updatedAt: new Date(barber.updatedAt),
      role: barber.role,
      age: barber.age,
      origin: barber.origin,
      videoUrl: barber.videoUrl,
      imageUrl: barber.imageUrl,
      gallery: barber.gallery,
      salonId: barber.salonId,
    }),
  );

  for (const recovery of activeBarberRecovery) {
    const source = activeSourceByName.get(
      `${recovery.firstName}|${recovery.lastName}`,
    );
    if (!source) {
      throw new Error(
        `Missing source barber ${recovery.firstName} ${recovery.lastName}.`,
      );
    }

    recoveredBarbers.push({
      ...source,
      id: recovery.id,
      salonId: recovery.salonId,
    });
  }

  const currentSalonSlugById = new Map([
    [grenoble.id, 'grenoble'],
    [meylan.id, 'meylan'],
  ]);

  const recoveredOffers: Prisma.OfferCreateManyInput[] = currentOffers.map(
    (offer) => {
      const salonSlug = currentSalonSlugById.get(offer.salonId);
      const recoveredId = salonSlug
        ? currentOfferIds[`${salonSlug}|${offer.title}`]
        : undefined;
      if (!salonSlug || !recoveredId) {
        throw new Error(`Could not map current offer ${offer.title}.`);
      }

      return {
        ...offer,
        id: recoveredId,
        salonId: salonIds[salonSlug as 'grenoble' | 'meylan'],
      };
    },
  );

  const historicalOfferDate = new Date('2026-02-14T10:39:45.000Z');
  recoveredOffers.push(
    {
      id: '917eb749-a4a3-42b3-b124-3d605ed6aefa',
      title: 'Coupe classique',
      price: 25,
      isActive: false,
      salonId: salonIds.grenoble,
      orderIndex: 0,
      createdAt: historicalOfferDate,
      updatedAt: historicalOfferDate,
    },
    {
      id: 'cb0655af-38c3-4b37-9143-a98b892131df',
      title: 'Rasage à l’ancienne',
      price: 20,
      isActive: false,
      salonId: salonIds.grenoble,
      orderIndex: 0,
      createdAt: historicalOfferDate,
      updatedAt: historicalOfferDate,
    },
    {
      id: '66d52c83-4690-470b-b3c8-56c1e91e65f4',
      title: 'Taille de barbe',
      price: 15,
      isActive: true,
      salonId: salonIds.voiron,
      orderIndex: 0,
      createdAt: historicalOfferDate,
      updatedAt: historicalOfferDate,
    },
    {
      id: '7027be55-ecb4-428c-85f5-9278b07d7908',
      title: 'Coupe tendance',
      price: 28,
      isActive: false,
      salonId: salonIds.meylan,
      orderIndex: 0,
      createdAt: historicalOfferDate,
      updatedAt: historicalOfferDate,
    },
    {
      id: '13fa5707-75fe-4494-9608-1fafd2bc0b42',
      title: 'Soin complet',
      price: 40,
      isActive: false,
      salonId: salonIds.meylan,
      orderIndex: 0,
      createdAt: historicalOfferDate,
      updatedAt: historicalOfferDate,
    },
  );

  await prisma.$transaction(
    async (tx) => {
      await tx.offer.deleteMany();
      await tx.barberSalon.deleteMany();
      await tx.barber.deleteMany();
      await tx.salon.deleteMany();

      await tx.salon.createMany({ data: recoveredSalons });
      await tx.barber.createMany({ data: recoveredBarbers });
      await tx.barberSalon.createMany({
        data: barberSalonLinks.map(([barberId, salonId]) => ({
          barberId,
          salonId,
        })),
      });
      await tx.offer.createMany({ data: recoveredOffers });

      const [salons, activeSalons, barbers, activeBarbers, links, offers] =
        await Promise.all([
          tx.salon.count(),
          tx.salon.count({ where: { isActive: true } }),
          tx.barber.count(),
          tx.barber.count({ where: { isActive: true } }),
          tx.barberSalon.count(),
          tx.offer.count(),
        ]);

      const actual = [
        salons,
        activeSalons,
        barbers,
        activeBarbers,
        links,
        offers,
      ];
      const expected = [3, 2, 11, 6, 12, 21];
      if (actual.some((count, index) => count !== expected[index])) {
        throw new Error(
          `Recovery validation failed: ${actual.join(', ')}; ` +
            `expected ${expected.join(', ')}.`,
        );
      }
    },
    {
      isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      timeout: 30_000,
    },
  );

  const result = {
    salons: await prisma.salon.count(),
    activeSalons: await prisma.salon.count({ where: { isActive: true } }),
    barbers: await prisma.barber.count(),
    activeBarbers: await prisma.barber.count({ where: { isActive: true } }),
    barberSalonLinks: await prisma.barberSalon.count(),
    offers: await prisma.offer.count(),
  };

  console.log(JSON.stringify(result, null, 2));
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
