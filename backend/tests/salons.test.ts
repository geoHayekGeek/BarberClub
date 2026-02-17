/**
 * Salons endpoint tests
 */

import request from 'supertest';
import { createApp } from '../src/app';
import prisma from '../src/db/client';

beforeAll(async () => {
  await prisma.$connect();
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
  await prisma.offer.deleteMany();
  await prisma.salon.deleteMany();
});

afterAll(async () => {
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
  await prisma.offer.deleteMany();
  await prisma.salon.deleteMany();
  await prisma.$disconnect();
});

afterEach(async () => {
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
  await prisma.offer.deleteMany();
  await prisma.salon.deleteMany();
});

const app = createApp();

describe('GET /api/v1/salons', () => {
  it('should return empty list when no salons exist', async () => {
    const response = await request(app).get('/api/v1/salons');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(0);
  });

  it('should return only active salons', async () => {
    const salon1 = await prisma.salon.create({
      data: {
        name: 'Active Salon 1',
        city: 'Paris',
        address: '123 Main St',
        description: 'Description 1',
        openingHours: 'Mon-Fri 9-18',
        images: ['image1.jpg'],
        isActive: true,
      },
    });

    const salon2 = await prisma.salon.create({
      data: {
        name: 'Inactive Salon',
        city: 'Lyon',
        address: '456 Main St',
        description: 'Description 2',
        openingHours: 'Mon-Fri 9-18',
        images: ['image2.jpg'],
        isActive: false,
      },
    });

    const salon3 = await prisma.salon.create({
      data: {
        name: 'Active Salon 2',
        city: 'Marseille',
        address: '789 Main St',
        description: 'Description 3',
        openingHours: 'Mon-Fri 9-18',
        images: ['image3.jpg'],
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/salons');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(2);
    expect(response.body.data.map((s: { id: string }) => s.id)).toContain(salon1.id);
    expect(response.body.data.map((s: { id: string }) => s.id)).toContain(salon3.id);
    expect(response.body.data.map((s: { id: string }) => s.id)).not.toContain(salon2.id);
  });

  it('should sort salons by name ASC', async () => {
    await prisma.salon.createMany({
      data: [
        {
          name: 'Salon B',
          city: 'Paris',
          address: '123 Main St',
          description: 'Description',
          openingHours: 'Mon-Fri 9-18',
          images: [],
          isActive: true,
        },
        {
          name: 'Salon A',
          city: 'Paris',
          address: '456 Main St',
          description: 'Description',
          openingHours: 'Mon-Fri 9-18',
          images: [],
          isActive: true,
        },
        {
          name: 'Salon C',
          city: 'Lyon',
          address: '789 Main St',
          description: 'Description',
          openingHours: 'Mon-Fri 9-18',
          images: [],
          isActive: true,
        },
      ],
    });

    const response = await request(app).get('/api/v1/salons');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(3);
    expect(response.body.data[0].name).toBe('Salon A');
    expect(response.body.data[1].name).toBe('Salon B');
    expect(response.body.data[2].name).toBe('Salon C');
  });

  it('should return lightweight list fields (id, name, imageUrl)', async () => {
    const salon = await prisma.salon.create({
      data: {
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
        images: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/salons');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    const salonData = response.body.data[0];
    expect(salonData).toHaveProperty('id', salon.id);
    expect(salonData).toHaveProperty('name', 'Test Salon');
    expect(salonData).toHaveProperty('imageUrl', 'https://example.com/image1.jpg');
    expect(Object.keys(salonData)).toEqual(['id', 'name', 'imageUrl']);
  });
});

describe('GET /api/v1/salons/:id', () => {
  it('should return full salon details with openingHours structure', async () => {
    const openingHoursJson = {
      monday: { open: '09:00', close: '19:00', closed: false },
      tuesday: { open: '09:00', close: '19:00', closed: false },
      wednesday: { open: '09:00', close: '19:00', closed: false },
      thursday: { open: '09:00', close: '19:00', closed: false },
      friday: { open: '09:00', close: '19:00', closed: false },
      saturday: { open: '09:00', close: '19:00', closed: false },
      sunday: { closed: true },
    };

    const salon = await prisma.salon.create({
      data: {
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
        openingHoursStructured: openingHoursJson,
        images: ['https://example.com/image1.jpg'],
        imageUrl: 'https://example.com/hero.jpg',
        gallery: ['https://example.com/g1.jpg', 'https://example.com/g2.jpg'],
        phone: '01 23 45 67 89',
        latitude: 48.8566,
        longitude: 2.3522,
        isActive: true,
      },
    });

    const response = await request(app).get(`/api/v1/salons/${salon.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('id', salon.id);
    expect(response.body.data).toHaveProperty('name', 'Test Salon');
    expect(response.body.data).toHaveProperty('description', 'Test Description');
    expect(response.body.data).toHaveProperty('imageUrl', 'https://example.com/hero.jpg');
    expect(response.body.data).toHaveProperty('gallery');
    expect(response.body.data.gallery).toEqual(['https://example.com/g1.jpg', 'https://example.com/g2.jpg']);
    expect(response.body.data).toHaveProperty('address', '123 Main St');
    expect(response.body.data).toHaveProperty('phone', '01 23 45 67 89');
    expect(response.body.data).toHaveProperty('latitude', 48.8566);
    expect(response.body.data).toHaveProperty('longitude', 2.3522);
    expect(response.body.data).toHaveProperty('openingHours');
    expect(response.body.data.openingHours).toHaveProperty('monday');
    expect(response.body.data.openingHours.monday).toEqual({ open: '09:00', close: '19:00', closed: false });
    expect(response.body.data.openingHours.sunday).toEqual({ closed: true });
  });

  it('should return salon with default openingHours when structured is null', async () => {
    const salon = await prisma.salon.create({
      data: {
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
        images: [],
        isActive: true,
      },
    });

    const response = await request(app).get(`/api/v1/salons/${salon.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('id', salon.id);
    expect(response.body.data).toHaveProperty('openingHours');
    expect(response.body.data.openingHours).toHaveProperty('monday');
    expect(response.body.data.openingHours.monday).toHaveProperty('open', '09:00');
    expect(response.body.data.openingHours.sunday).toHaveProperty('closed', true);
  });

  it('should return 404 for non-existent salon', async () => {
    const response = await request(app).get('/api/v1/salons/00000000-0000-0000-0000-000000000000');

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('SALON_NOT_FOUND');
  });

  it('should return 400 for invalid salon id format', async () => {
    const response = await request(app).get('/api/v1/salons/invalid-id');

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});
