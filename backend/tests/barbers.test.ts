/**
 * Barbers endpoint tests
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

describe('GET /api/v1/barbers', () => {
  it('should return empty list when no barbers exist', async () => {
    const response = await request(app).get('/api/v1/barbers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(0);
  });

  it('should return only active barbers', async () => {
    const barber1 = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        interests: [],
        images: [],
        isActive: true,
      },
    });

    const barber2 = await prisma.barber.create({
      data: {
        firstName: 'Jane',
        lastName: 'Smith',
        bio: 'Master barber',
        interests: [],
        images: [],
        isActive: false,
      },
    });

    const barber3 = await prisma.barber.create({
      data: {
        firstName: 'Bob',
        lastName: 'Johnson',
        bio: 'Senior barber',
        interests: [],
        images: [],
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/barbers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(2);
    expect(response.body.data.map((b: { id: string }) => b.id)).toContain(barber1.id);
    expect(response.body.data.map((b: { id: string }) => b.id)).toContain(barber3.id);
    expect(response.body.data.map((b: { id: string }) => b.id)).not.toContain(barber2.id);
  });

  it('should sort barbers by firstName ASC', async () => {
    await prisma.barber.createMany({
      data: [
        {
          firstName: 'Charlie',
          lastName: 'Brown',
          bio: 'Bio',
          interests: [],
          images: [],
          isActive: true,
        },
        {
          firstName: 'Alice',
          lastName: 'Williams',
          bio: 'Bio',
          interests: [],
          images: [],
          isActive: true,
        },
        {
          firstName: 'Bob',
          lastName: 'Johnson',
          bio: 'Bio',
          interests: [],
          images: [],
          isActive: true,
        },
      ],
    });

    const response = await request(app).get('/api/v1/barbers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(3);
    expect(response.body.data[0].firstName).toBe('Alice');
    expect(response.body.data[1].firstName).toBe('Bob');
    expect(response.body.data[2].firstName).toBe('Charlie');
  });

  it('should return all required fields with salons', async () => {
    const salon1 = await prisma.salon.create({
      data: {
        name: 'Salon 1',
        city: 'Paris',
        address: '123 Main St',
        description: 'Description',
        openingHours: 'Mon-Fri 9-18',
        images: [],
        isActive: true,
      },
    });

    const salon2 = await prisma.salon.create({
      data: {
        name: 'Salon 2',
        city: 'Lyon',
        address: '456 Main St',
        description: 'Description',
        openingHours: 'Mon-Fri 9-18',
        images: [],
        isActive: true,
      },
    });

    const inactiveSalon = await prisma.salon.create({
      data: {
        name: 'Inactive Salon',
        city: 'Marseille',
        address: '789 Main St',
        description: 'Description',
        openingHours: 'Mon-Fri 9-18',
        images: [],
        isActive: false,
      },
    });

    const barber = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        experienceYears: 5,
        interests: [],
        images: ['barber1.jpg', 'barber2.jpg'],
        isActive: true,
      },
    });

    await prisma.barberSalon.createMany({
      data: [
        { barberId: barber.id, salonId: salon1.id },
        { barberId: barber.id, salonId: salon2.id },
        { barberId: barber.id, salonId: inactiveSalon.id },
      ],
    });

    const response = await request(app).get('/api/v1/barbers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    const barberData = response.body.data[0];
    expect(barberData).toHaveProperty('id', barber.id);
    expect(barberData).toHaveProperty('firstName', 'John');
    expect(barberData).toHaveProperty('lastName', 'Doe');
    expect(barberData).toHaveProperty('bio', 'Experienced barber');
    expect(barberData).toHaveProperty('experienceYears', 5);
    expect(barberData).toHaveProperty('images', ['barber1.jpg', 'barber2.jpg']);
    expect(barberData).toHaveProperty('salons');
    expect(barberData.salons).toHaveLength(2);
    expect(barberData.salons.map((s: { id: string }) => s.id)).toContain(salon1.id);
    expect(barberData.salons.map((s: { id: string }) => s.id)).toContain(salon2.id);
    expect(barberData.salons.map((s: { id: string }) => s.id)).not.toContain(inactiveSalon.id);
    
    const salon1Data = barberData.salons.find((s: { id: string }) => s.id === salon1.id);
    expect(salon1Data).toHaveProperty('id', salon1.id);
    expect(salon1Data).toHaveProperty('name', 'Salon 1');
    expect(salon1Data).toHaveProperty('city', 'Paris');
  });

  it('should return barber with null experienceYears', async () => {
    await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        experienceYears: null,
        interests: [],
        images: [],
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/barbers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0].experienceYears).toBeNull();
  });

  it('should return barber without salons when none are associated', async () => {
    await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        interests: [],
        images: [],
        isActive: true,
      },
    });

    const response = await request(app).get('/api/v1/barbers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0].salons).toHaveLength(0);
  });
});

describe('GET /api/v1/barbers/:id', () => {
  it('should return barber details with salons and interests', async () => {
    const salon1 = await prisma.salon.create({
      data: {
        name: 'Salon 1',
        city: 'Paris',
        address: '123 Main St',
        description: 'Description',
        openingHours: 'Mon-Fri 9-18',
        images: [],
        isActive: true,
      },
    });

    const salon2 = await prisma.salon.create({
      data: {
        name: 'Salon 2',
        city: 'Lyon',
        address: '456 Main St',
        description: 'Description',
        openingHours: 'Mon-Fri 9-18',
        images: [],
        isActive: true,
      },
    });

    const barber = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        experienceYears: 10,
        interests: ['Haircuts', 'Beards', 'Styling'],
        images: ['barber1.jpg'],
        isActive: true,
      },
    });

    await prisma.barberSalon.createMany({
      data: [
        { barberId: barber.id, salonId: salon1.id },
        { barberId: barber.id, salonId: salon2.id },
      ],
    });

    const response = await request(app).get(`/api/v1/barbers/${barber.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('id', barber.id);
    expect(response.body.data).toHaveProperty('firstName', 'John');
    expect(response.body.data).toHaveProperty('lastName', 'Doe');
    expect(response.body.data).toHaveProperty('bio', 'Experienced barber');
    expect(response.body.data).toHaveProperty('experienceYears', 10);
    expect(response.body.data).toHaveProperty('interests', ['Haircuts', 'Beards', 'Styling']);
    expect(response.body.data).toHaveProperty('images', ['barber1.jpg']);
    expect(response.body.data).toHaveProperty('salons');
    expect(response.body.data.salons).toHaveLength(2);
    expect(response.body.data.salons.map((s: { id: string }) => s.id)).toContain(salon1.id);
    expect(response.body.data.salons.map((s: { id: string }) => s.id)).toContain(salon2.id);
  });

  it('should return barber with null experienceYears and empty interests', async () => {
    const barber = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        experienceYears: null,
        interests: [],
        images: [],
        isActive: true,
      },
    });

    const response = await request(app).get(`/api/v1/barbers/${barber.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data.experienceYears).toBeNull();
    expect(response.body.data.interests).toEqual([]);
  });

  it('should return barber without salons when none are associated', async () => {
    const barber = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        interests: [],
        images: [],
        isActive: true,
      },
    });

    const response = await request(app).get(`/api/v1/barbers/${barber.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('salons');
    expect(response.body.data.salons).toHaveLength(0);
  });

  it('should return 404 for non-existent barber', async () => {
    const response = await request(app).get('/api/v1/barbers/00000000-0000-0000-0000-000000000000');

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('BARBER_NOT_FOUND');
  });

  it('should return 400 for invalid barber id format', async () => {
    const response = await request(app).get('/api/v1/barbers/invalid-id');

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});
