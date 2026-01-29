/**
 * Offers endpoint tests
 */

import request from 'supertest';
import { createApp } from '../src/app';
import prisma from '../src/db/client';

beforeAll(async () => {
  await prisma.$connect();
  await prisma.offer.deleteMany();
});

afterAll(async () => {
  await prisma.offer.deleteMany();
  await prisma.$disconnect();
});

afterEach(async () => {
  await prisma.offer.deleteMany();
});

const app = createApp();

describe('GET /api/v1/offers', () => {
  it('should return empty list when no offers exist', async () => {
    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(0);
    expect(response.body.data.nextCursor).toBeNull();
  });

  it('should return only active offers by default', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: [
        {
          title: 'Active Offer 1',
          description: 'Description 1',
          isActive: true,
          validFrom: pastDate,
          validTo: futureDate,
        },
        {
          title: 'Inactive Offer',
          description: 'Description 2',
          isActive: false,
          validFrom: pastDate,
          validTo: futureDate,
        },
        {
          title: 'Active Offer 2',
          description: 'Description 3',
          isActive: true,
          validFrom: null,
          validTo: null,
        },
      ],
    });

    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(2);
    expect(response.body.data.items.every((item: { title: string }) => 
      item.title.startsWith('Active')
    )).toBe(true);
  });

  it('should exclude expired offers when status=active', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 48 * 60 * 60 * 1000);
    const expiredDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: [
        {
          title: 'Active Offer',
          description: 'Description 1',
          isActive: true,
          validFrom: pastDate,
          validTo: new Date(now.getTime() + 24 * 60 * 60 * 1000),
        },
        {
          title: 'Expired Offer',
          description: 'Description 2',
          isActive: true,
          validFrom: pastDate,
          validTo: expiredDate,
        },
      ],
    });

    const response = await request(app).get('/api/v1/offers?status=active');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(response.body.data.items[0].title).toBe('Active Offer');
  });

  it('should exclude future validFrom offers when status=active', async () => {
    const now = new Date();
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const farFutureDate = new Date(now.getTime() + 48 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: [
        {
          title: 'Active Offer',
          description: 'Description 1',
          isActive: true,
          validFrom: new Date(now.getTime() - 24 * 60 * 60 * 1000),
          validTo: farFutureDate,
        },
        {
          title: 'Future Offer',
          description: 'Description 2',
          isActive: true,
          validFrom: futureDate,
          validTo: farFutureDate,
        },
      ],
    });

    const response = await request(app).get('/api/v1/offers?status=active');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(response.body.data.items[0].title).toBe('Active Offer');
  });

  it('should include offers with null validFrom when status=active', async () => {
    const now = new Date();
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: [
        {
          title: 'Offer with null validFrom',
          description: 'Description 1',
          isActive: true,
          validFrom: null,
          validTo: futureDate,
        },
      ],
    });

    const response = await request(app).get('/api/v1/offers?status=active');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(response.body.data.items[0].title).toBe('Offer with null validFrom');
  });

  it('should include offers with null validTo when status=active', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: [
        {
          title: 'Offer with null validTo',
          description: 'Description 1',
          isActive: true,
          validFrom: pastDate,
          validTo: null,
        },
      ],
    });

    const response = await request(app).get('/api/v1/offers?status=active');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(response.body.data.items[0].title).toBe('Offer with null validTo');
  });

  it('should return all offers when status=all', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: [
        {
          title: 'Active Offer',
          description: 'Description 1',
          isActive: true,
          validFrom: pastDate,
          validTo: futureDate,
        },
        {
          title: 'Inactive Offer',
          description: 'Description 2',
          isActive: false,
          validFrom: pastDate,
          validTo: futureDate,
        },
        {
          title: 'Expired Offer',
          description: 'Description 3',
          isActive: true,
          validFrom: pastDate,
          validTo: new Date(now.getTime() - 12 * 60 * 60 * 1000),
        },
      ],
    });

    const response = await request(app).get('/api/v1/offers?status=all');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(3);
  });

  it('should support pagination with cursor', async () => {
    const now = new Date();

    await prisma.offer.createMany({
      data: Array.from({ length: 25 }, (_, i) => ({
        title: `Offer ${i + 1}`,
        description: `Description ${i + 1}`,
        isActive: true,
        validFrom: new Date(now.getTime() - (i + 1) * 60 * 60 * 1000),
        validTo: new Date(now.getTime() + (i + 1) * 60 * 60 * 1000),
        createdAt: new Date(now.getTime() - i * 60 * 1000),
      })),
    });

    const firstResponse = await request(app).get('/api/v1/offers?limit=10');

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.body.data.items).toHaveLength(10);
    expect(firstResponse.body.data.nextCursor).toBeTruthy();

    const secondResponse = await request(app).get(
      `/api/v1/offers?limit=10&cursor=${firstResponse.body.data.nextCursor}`
    );

    expect(secondResponse.status).toBe(200);
    expect(secondResponse.body.data.items).toHaveLength(10);
    expect(secondResponse.body.data.items[0].id).not.toBe(firstResponse.body.data.items[0].id);
  });

  it('should respect limit parameter', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: Array.from({ length: 15 }, (_, i) => ({
        title: `Offer ${i + 1}`,
        description: `Description ${i + 1}`,
        isActive: true,
        validFrom: pastDate,
        validTo: futureDate,
        createdAt: new Date(now.getTime() - i * 60 * 1000),
      })),
    });

    const response = await request(app).get('/api/v1/offers?limit=5');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(5);
  });

  it('should cap limit at 50', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    await prisma.offer.createMany({
      data: Array.from({ length: 60 }, (_, i) => ({
        title: `Offer ${i + 1}`,
        description: `Description ${i + 1}`,
        isActive: true,
        validFrom: pastDate,
        validTo: futureDate,
        createdAt: new Date(now.getTime() - i * 60 * 1000),
      })),
    });

    const response = await request(app).get('/api/v1/offers?limit=100');

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('should return offers sorted by newest first', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const olderOffer = await prisma.offer.create({
      data: {
        title: 'Older Offer',
        description: 'Description 1',
        isActive: true,
        validFrom: pastDate,
        validTo: futureDate,
        createdAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
      },
    });

    const newerOffer = await prisma.offer.create({
      data: {
        title: 'Newer Offer',
        description: 'Description 2',
        isActive: true,
        validFrom: pastDate,
        validTo: futureDate,
        createdAt: new Date(now.getTime() - 1 * 60 * 60 * 1000),
      },
    });

    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(2);
    expect(response.body.data.items[0].id).toBe(newerOffer.id);
    expect(response.body.data.items[1].id).toBe(olderOffer.id);
  });
});

describe('GET /api/v1/offers/:id', () => {
  it('should return offer details', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const offer = await prisma.offer.create({
      data: {
        title: 'Test Offer',
        description: 'Test Description',
        imageUrl: 'https://example.com/image.jpg',
        isActive: true,
        validFrom: pastDate,
        validTo: futureDate,
      },
    });

    const response = await request(app).get(`/api/v1/offers/${offer.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('id', offer.id);
    expect(response.body.data).toHaveProperty('title', 'Test Offer');
    expect(response.body.data).toHaveProperty('description', 'Test Description');
    expect(response.body.data).toHaveProperty('imageUrl', 'https://example.com/image.jpg');
    expect(response.body.data).toHaveProperty('validFrom');
    expect(response.body.data).toHaveProperty('validTo');
  });

  it('should return 404 for non-existent offer', async () => {
    const response = await request(app).get('/api/v1/offers/00000000-0000-0000-0000-000000000000');

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('OFFER_NOT_FOUND');
  });

  it('should return 400 for invalid offer id format', async () => {
    const response = await request(app).get('/api/v1/offers/invalid-id');

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('should return offer with null imageUrl', async () => {
    const now = new Date();
    const pastDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const futureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const offer = await prisma.offer.create({
      data: {
        title: 'Test Offer',
        description: 'Test Description',
        imageUrl: null,
        isActive: true,
        validFrom: pastDate,
        validTo: futureDate,
      },
    });

    const response = await request(app).get(`/api/v1/offers/${offer.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data.imageUrl).toBeNull();
  });

  it('should return offer with null validFrom and validTo', async () => {
    const offer = await prisma.offer.create({
      data: {
        title: 'Test Offer',
        description: 'Test Description',
        isActive: true,
        validFrom: null,
        validTo: null,
      },
    });

    const response = await request(app).get(`/api/v1/offers/${offer.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data.validFrom).toBeNull();
    expect(response.body.data.validTo).toBeNull();
  });
});
