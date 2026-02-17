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
    expect(response.body.data[0].name).toBe('Alice Williams');
    expect(response.body.data[1].name).toBe('Bob Johnson');
    expect(response.body.data[2].name).toBe('Charlie Brown');
  });

  it('should return all required fields with salon', async () => {
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
        experienceYears: 5,
        interests: [],
        images: ['https://example.com/barber1.jpg', 'https://example.com/barber2.jpg'],
        isActive: true,
        salonId: salon1.id,
      },
    });

    await prisma.barberSalon.createMany({
      data: [
        { barberId: barber.id, salonId: salon1.id },
        { barberId: barber.id, salonId: salon2.id },
      ],
    });

    const response = await request(app).get('/api/v1/barbers');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    const barberData = response.body.data[0];
    expect(barberData).toHaveProperty('id', barber.id);
    expect(barberData).toHaveProperty('name', 'John Doe');
    expect(barberData).toHaveProperty('role', 'BARBER');
    expect(barberData).toHaveProperty('age');
    expect(barberData).toHaveProperty('origin');
    expect(barberData).toHaveProperty('imageUrl', 'https://example.com/barber1.jpg');
    expect(barberData).toHaveProperty('salon');
    expect(barberData.salon).toHaveProperty('id', salon1.id);
    expect(barberData.salon).toHaveProperty('name', 'Salon 1');
  });

  it('should return barber with null age', async () => {
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
    expect(response.body.data[0].age).toBeNull();
  });

  it('should return barber without salon when none are associated', async () => {
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
    expect(response.body.data[0].salon).toBeNull();
  });
});

describe('GET /api/v1/barbers/:id', () => {
  it('should return full barber details with salon, bio, videoUrl, gallery', async () => {
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

    const barber = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        experienceYears: 10,
        interests: ['Haircuts', 'Beards', 'Styling'],
        images: ['https://example.com/barber1.jpg', 'https://example.com/barber2.jpg'],
        isActive: true,
        salonId: salon1.id,
        videoUrl: 'https://example.com/video.mp4',
        gallery: ['https://example.com/g1.jpg', 'https://example.com/g2.jpg'],
      },
    });

    await prisma.barberSalon.create({
      data: { barberId: barber.id, salonId: salon1.id },
    });

    const response = await request(app).get(`/api/v1/barbers/${barber.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('id', barber.id);
    expect(response.body.data).toHaveProperty('name', 'John Doe');
    expect(response.body.data).toHaveProperty('role', 'BARBER');
    expect(response.body.data).toHaveProperty('bio', 'Experienced barber');
    expect(response.body.data).toHaveProperty('videoUrl', 'https://example.com/video.mp4');
    expect(response.body.data).toHaveProperty('imageUrl', 'https://example.com/barber1.jpg');
    expect(response.body.data).toHaveProperty('gallery');
    expect(response.body.data.gallery).toEqual(['https://example.com/g1.jpg', 'https://example.com/g2.jpg']);
    expect(response.body.data).toHaveProperty('salon');
    expect(response.body.data.salon).toHaveProperty('id', salon1.id);
    expect(response.body.data.salon).toHaveProperty('name', 'Salon 1');
    expect(response.body.data.salon).toHaveProperty('address', '123 Main St');
  });

  it('should return barber with null age and empty gallery', async () => {
    const barber = await prisma.barber.create({
      data: {
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        experienceYears: null,
        interests: [],
        images: ['https://example.com/barber1.jpg'],
        isActive: true,
      },
    });

    const response = await request(app).get(`/api/v1/barbers/${barber.id}`);

    expect(response.status).toBe(200);
    expect(response.body.data.age).toBeNull();
    expect(response.body.data.gallery).toEqual([]);
  });

  it('should return barber without salon when none are associated', async () => {
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
    expect(response.body.data).toHaveProperty('salon');
    expect(response.body.data.salon).toBeNull();
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
