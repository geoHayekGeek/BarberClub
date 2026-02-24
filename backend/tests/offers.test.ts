/**
 * Offers endpoint tests
 * GET /api/v1/offers returns active global offers only
 */

import request from 'supertest';
import { createApp } from '../src/app';
import prisma from '../src/db/client';

beforeAll(async () => {
  await prisma.$connect();
  await prisma.globalOffer.deleteMany();
});

afterAll(async () => {
  await prisma.globalOffer.deleteMany();
  await prisma.$disconnect();
});

afterEach(async () => {
  await prisma.globalOffer.deleteMany();
});

const app = createApp();

describe('GET /api/v1/offers', () => {
  it('should return empty list when no global offers exist', async () => {
    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    expect(Array.isArray(response.body.data)).toBe(true);
    expect(response.body.data).toHaveLength(0);
  });

  it('should return only active global offers', async () => {
    await prisma.globalOffer.createMany({
      data: [
        { title: 'Active 1', description: 'Desc 1', isActive: true },
        { title: 'Inactive', description: 'Desc 2', isActive: false },
        { title: 'Active 2', description: null, imageUrl: null, discount: 10, isActive: true },
      ],
    });

    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(2);
    expect(response.body.data.every((o: { isActive: boolean }) => o.isActive)).toBe(true);
  });

  it('should return offers with title, description, imageUrl, discount', async () => {
    await prisma.globalOffer.create({
      data: {
        title: 'Promo Test',
        description: 'Une super offre',
        imageUrl: 'https://example.com/img.jpg',
        discount: 20,
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/offers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0].title).toBe('Promo Test');
    expect(response.body.data[0].description).toBe('Une super offre');
    expect(response.body.data[0].imageUrl).toBe('https://example.com/img.jpg');
    expect(response.body.data[0].discount).toBe(20);
  });
});
