/**
 * GET /api/v1/offers: public ClientOffer feed (non-expired, excluding welcome)
 */

import request from 'supertest';
import { createApp } from '../src/app';
import prisma from '../src/db/client';
import { ClientOfferType, DiscountType } from '@prisma/client';

beforeAll(async () => {
  await prisma.$connect();
});

afterAll(async () => {
  await prisma.$disconnect();
});

beforeEach(async () => {
  await prisma.offerActivation.deleteMany();
  await prisma.clientOffer.deleteMany();
});

const app = createApp();

describe('GET /api/v1/offers', () => {
  it('returns empty list when no client offers exist', async () => {
    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body.data)).toBe(true);
    expect(response.body.data).toHaveLength(0);
  });

  it('returns current and upcoming non-expired offers and excludes welcome and expired', async () => {
    const past = new Date(Date.now() - 86400000);
    const future = new Date(Date.now() + 7 * 86400000);
    const farFuture = new Date(Date.now() + 30 * 86400000);

    await prisma.clientOffer.create({
      data: {
        type: ClientOfferType.event,
        title: 'Current test',
        discountType: DiscountType.percentage,
        discountValue: 10,
        applicableServices: [],
        startsAt: past,
        endsAt: future,
        isActive: true,
      },
    });
    await prisma.clientOffer.create({
      data: {
        type: ClientOfferType.event,
        title: 'Upcoming test',
        discountType: DiscountType.percentage,
        discountValue: 5,
        applicableServices: [],
        startsAt: future,
        endsAt: farFuture,
        isActive: true,
      },
    });
    await prisma.clientOffer.create({
      data: {
        type: ClientOfferType.welcome,
        title: 'Welcome hidden',
        discountType: DiscountType.percentage,
        discountValue: 5,
        applicableServices: [],
        startsAt: past,
        endsAt: null,
        isActive: true,
      },
    });
    await prisma.clientOffer.create({
      data: {
        type: ClientOfferType.event,
        title: 'Expired',
        discountType: DiscountType.percentage,
        discountValue: 5,
        applicableServices: [],
        startsAt: past,
        endsAt: past,
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    const titles = response.body.data.map((o: { title: string }) => o.title);
    expect(titles).toContain('Current test');
    expect(titles).toContain('Upcoming test');
    expect(titles).not.toContain('Welcome hidden');
    expect(titles).not.toContain('Expired');
  });
});
