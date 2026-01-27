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
  await prisma.salon.deleteMany();
});

afterAll(async () => {
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
  await prisma.salon.deleteMany();
  await prisma.$disconnect();
});

afterEach(async () => {
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
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

  it('should sort salons by city ASC, then name ASC', async () => {
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
    expect(response.body.data[0].city).toBe('Lyon');
    expect(response.body.data[0].name).toBe('Salon C');
    expect(response.body.data[1].city).toBe('Paris');
    expect(response.body.data[1].name).toBe('Salon A');
    expect(response.body.data[2].city).toBe('Paris');
    expect(response.body.data[2].name).toBe('Salon B');
  });

  it('should return all required fields', async () => {
    const salon = await prisma.salon.create({
      data: {
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
        images: ['image1.jpg', 'image2.jpg'],
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/salons');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    const salonData = response.body.data[0];
    expect(salonData).toHaveProperty('id', salon.id);
    expect(salonData).toHaveProperty('name', 'Test Salon');
    expect(salonData).toHaveProperty('city', 'Paris');
    expect(salonData).toHaveProperty('address', '123 Main St');
    expect(salonData).toHaveProperty('description', 'Test Description');
    expect(salonData).toHaveProperty('openingHours', 'Mon-Fri 9-18');
    expect(salonData).toHaveProperty('images', ['image1.jpg', 'image2.jpg']);
    expect(salonData).not.toHaveProperty('isActive');
    expect(salonData).not.toHaveProperty('createdAt');
    expect(salonData).not.toHaveProperty('updatedAt');
  });
});

describe('GET /api/v1/salons/:id', () => {
  it('should return salon details with barbers', async () => {
    const salon = await prisma.salon.create({
      data: {
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
        images: ['image1.jpg'],
        isActive: true,
      },
    });

    const barber1 = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        interests: ['Haircuts', 'Beards'],
        images: ['barber1.jpg'],
        isActive: true,
      },
    });

    const barber2 = await prisma.barber.create({
      data: {
        firstName: 'Jane',
        lastName: 'Smith',
        bio: 'Master barber',
        interests: ['Styling'],
        images: ['barber2.jpg'],
        isActive: true,
      },
    });

    const inactiveBarber = await prisma.barber.create({
      data: {
        firstName: 'Inactive',
        lastName: 'Barber',
        bio: 'Inactive',
        interests: [],
        images: [],
        isActive: false,
      },
    });

    await prisma.barberSalon.createMany({
      data: [
        { barberId: barber1.id, salonId: salon.id },
        { barberId: barber2.id, salonId: salon.id },
        { barberId: inactiveBarber.id, salonId: salon.id },
      ],
    });

    const response = await request(app).get(`/api/v1/salons/${salon.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('id', salon.id);
    expect(response.body.data).toHaveProperty('name', 'Test Salon');
    expect(response.body.data).toHaveProperty('city', 'Paris');
    expect(response.body.data).toHaveProperty('address', '123 Main St');
    expect(response.body.data).toHaveProperty('description', 'Test Description');
    expect(response.body.data).toHaveProperty('openingHours', 'Mon-Fri 9-18');
    expect(response.body.data).toHaveProperty('images', ['image1.jpg']);
    expect(response.body.data).toHaveProperty('barbers');
    expect(response.body.data.barbers).toHaveLength(2);
    expect(response.body.data.barbers.map((b: { id: string }) => b.id)).toContain(barber1.id);
    expect(response.body.data.barbers.map((b: { id: string }) => b.id)).toContain(barber2.id);
    expect(response.body.data.barbers.map((b: { id: string }) => b.id)).not.toContain(inactiveBarber.id);
    
    const barber1Data = response.body.data.barbers.find((b: { id: string }) => b.id === barber1.id);
    expect(barber1Data).toHaveProperty('id', barber1.id);
    expect(barber1Data).toHaveProperty('firstName', 'John');
    expect(barber1Data).toHaveProperty('lastName', 'Doe');
    expect(barber1Data).not.toHaveProperty('bio');
    expect(barber1Data).not.toHaveProperty('images');
  });

  it('should return salon without barbers when none are associated', async () => {
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
    expect(response.body.data).toHaveProperty('barbers');
    expect(response.body.data.barbers).toHaveLength(0);
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
