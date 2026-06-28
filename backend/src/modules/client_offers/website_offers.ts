import { PrismaClient } from '@prisma/client';

type ClientOfferSeed = {
  type: 'event' | 'flash' | 'pack' | 'permanent' | 'welcome';
  title: string;
  description: string | null;
  discountType: 'percentage' | 'fixed' | 'free_service';
  discountValue: number;
  applicableServices: string[];
  startsAt: Date;
  endsAt: Date | null;
  maxSpots: number | null;
  imageUrl: string | null;
  isActive: boolean;
};

function buildWebsitePublicOffer(now: Date): ClientOfferSeed {
  return {
    type: 'permanent',
    title: 'BarberClub Carte Cadeau',
    description: 'Montant libre, valable 1 an dans nos deux salons.',
    discountType: 'fixed',
    discountValue: 20,
    applicableServices: [],
    startsAt: now,
    endsAt: null,
    maxSpots: null,
    imageUrl: null,
    isActive: true,
  };
}

function buildWebsiteWelcomeOffer(now: Date): ClientOfferSeed {
  return {
    type: 'welcome',
    title: 'Bienvenue: -10%',
    description:
      'Votre première visite au Barber Club: -10% sur une prestation. Valable 30 jours après inscription.',
    discountType: 'percentage',
    discountValue: 10,
    applicableServices: [],
    startsAt: now,
    endsAt: null,
    maxSpots: null,
    imageUrl: null,
    isActive: true,
  };
}

type ClientOfferDb = Pick<PrismaClient, 'clientOffer'>;

async function upsertOffer(db: ClientOfferDb, offer: ClientOfferSeed) {
  const existing = await db.clientOffer.findFirst({
    where: { title: offer.title, type: offer.type },
  });

  if (existing) {
    await db.clientOffer.update({
      where: { id: existing.id },
      data: offer,
    });
    return;
  }

  await db.clientOffer.create({ data: offer });
}

export async function syncWebsiteOffers(prisma: PrismaClient) {
  const now = new Date();
  const websitePublicOffer = buildWebsitePublicOffer(now);
  const websiteWelcomeOffer = buildWebsiteWelcomeOffer(now);

  await prisma.$transaction(async (tx) => {
    await tx.clientOffer.deleteMany({
      where: { type: { not: 'welcome' } },
    });

    await upsertOffer(tx, websitePublicOffer);
    await upsertOffer(tx, websiteWelcomeOffer);
  });
}
