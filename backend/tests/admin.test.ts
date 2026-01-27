/**
 * Admin endpoint tests
 */

// Set ADMIN_SECRET before importing config-dependent modules
const ORIGINAL_ADMIN_SECRET = process.env.ADMIN_SECRET;
const TEST_ADMIN_SECRET = 'test-admin-secret-12345678901234567890';
process.env.ADMIN_SECRET = TEST_ADMIN_SECRET;

import request from 'supertest';
import { createApp } from '../src/app';
import prisma from '../src/db/client';

beforeAll(async () => {
  await prisma.$connect();
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
  await prisma.salon.deleteMany();
  await prisma.offer.deleteMany();
});

afterAll(async () => {
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
  await prisma.salon.deleteMany();
  await prisma.offer.deleteMany();
  await prisma.$disconnect();
  if (ORIGINAL_ADMIN_SECRET) {
    process.env.ADMIN_SECRET = ORIGINAL_ADMIN_SECRET;
  } else {
    delete process.env.ADMIN_SECRET;
  }
});

afterEach(async () => {
  await prisma.barberSalon.deleteMany();
  await prisma.barber.deleteMany();
  await prisma.salon.deleteMany();
  await prisma.offer.deleteMany();
});

const app = createApp();

describe('POST /api/v1/admin/salons', () => {
  it('should return 403 when adminSecret is missing', async () => {
    const response = await request(app)
      .post('/api/v1/admin/salons')
      .send({
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ADMIN_FORBIDDEN');
    expect(response.body.error.message).toBe('Invalid admin secret');
  });

  it('should return 403 when adminSecret is incorrect', async () => {
    const response = await request(app)
      .post('/api/v1/admin/salons')
      .send({
        adminSecret: 'wrong-secret',
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ADMIN_FORBIDDEN');
    expect(response.body.error.message).toBe('Invalid admin secret');
  });

  it('should create salon with correct adminSecret', async () => {
    const response = await request(app)
      .post('/api/v1/admin/salons')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        name: 'Test Salon',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
        images: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg'],
        isActive: true,
      });

    expect(response.status).toBe(201);
    expect(response.body.data).toHaveProperty('id');
    expect(response.body.data).toHaveProperty('name', 'Test Salon');
    expect(response.body.data).toHaveProperty('city', 'Paris');
    expect(response.body.data).toHaveProperty('address', '123 Main St');
    expect(response.body.data).toHaveProperty('description', 'Test Description');
    expect(response.body.data).toHaveProperty('openingHours', 'Mon-Fri 9-18');
    expect(response.body.data).toHaveProperty('images', ['https://example.com/image1.jpg', 'https://example.com/image2.jpg']);
    expect(response.body.data).not.toHaveProperty('adminSecret');

    const salon = await prisma.salon.findUnique({
      where: { id: response.body.data.id },
    });
    expect(salon).toBeTruthy();
    expect(salon?.name).toBe('Test Salon');
    expect(salon?.isActive).toBe(true);
  });

  it('should return 400 for validation errors', async () => {
    const response = await request(app)
      .post('/api/v1/admin/salons')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        name: '',
        city: 'Paris',
        address: '123 Main St',
        description: 'Test Description',
        openingHours: 'Mon-Fri 9-18',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});

describe('POST /api/v1/admin/barbers', () => {
  let salonId: string;

  beforeEach(async () => {
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
    salonId = salon.id;
  });

  it('should return 403 when adminSecret is missing', async () => {
    const response = await request(app)
      .post('/api/v1/admin/barbers')
      .send({
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        salonIds: [salonId],
      });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ADMIN_FORBIDDEN');
  });

  it('should return 403 when adminSecret is incorrect', async () => {
    const response = await request(app)
      .post('/api/v1/admin/barbers')
      .send({
        adminSecret: 'wrong-secret',
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        salonIds: [salonId],
      });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ADMIN_FORBIDDEN');
  });

  it('should create barber with correct adminSecret', async () => {
    const response = await request(app)
      .post('/api/v1/admin/barbers')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        experienceYears: 5,
        interests: ['Haircuts', 'Beards'],
        images: ['https://example.com/barber1.jpg'],
        salonIds: [salonId],
        isActive: true,
      });

    expect(response.status).toBe(201);
    expect(response.body.data).toHaveProperty('id');
    expect(response.body.data).toHaveProperty('firstName', 'John');
    expect(response.body.data).toHaveProperty('lastName', 'Doe');
    expect(response.body.data).toHaveProperty('bio', 'Experienced barber');
    expect(response.body.data).toHaveProperty('experienceYears', 5);
    expect(response.body.data).toHaveProperty('interests', ['Haircuts', 'Beards']);
    expect(response.body.data).toHaveProperty('images', ['https://example.com/barber1.jpg']);
    expect(response.body.data).toHaveProperty('salons');
    expect(response.body.data.salons).toHaveLength(1);
    expect(response.body.data.salons[0]).toHaveProperty('id', salonId);
    expect(response.body.data).not.toHaveProperty('adminSecret');

    const barber = await prisma.barber.findUnique({
      where: { id: response.body.data.id },
      include: { salons: true },
    });
    expect(barber).toBeTruthy();
    expect(barber?.firstName).toBe('John');
    expect(barber?.isActive).toBe(true);
    expect(barber?.salons).toHaveLength(1);
    expect(barber?.salons[0].salonId).toBe(salonId);
  });

  it('should return 400 when salonIds do not exist', async () => {
    const response = await request(app)
      .post('/api/v1/admin/barbers')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        firstName: 'John',
        lastName: 'Doe',
        bio: 'Experienced barber',
        salonIds: ['00000000-0000-0000-0000-000000000000'],
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
    expect(response.body.error.message).toContain('salon IDs do not exist');
  });

  it('should return 400 for validation errors', async () => {
    const response = await request(app)
      .post('/api/v1/admin/barbers')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        firstName: '',
        lastName: 'Doe',
        bio: 'Experienced barber',
        salonIds: [salonId],
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});

describe('POST /api/v1/admin/offers', () => {
  it('should return 403 when adminSecret is missing', async () => {
    const response = await request(app)
      .post('/api/v1/admin/offers')
      .send({
        title: 'Test Offer',
        description: 'Test Description',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ADMIN_FORBIDDEN');
  });

  it('should return 403 when adminSecret is incorrect', async () => {
    const response = await request(app)
      .post('/api/v1/admin/offers')
      .send({
        adminSecret: 'wrong-secret',
        title: 'Test Offer',
        description: 'Test Description',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ADMIN_FORBIDDEN');
  });

  it('should create offer with correct adminSecret', async () => {
    const validFrom = new Date('2026-01-01T00:00:00Z').toISOString();
    const validTo = new Date('2026-12-31T23:59:59Z').toISOString();

    const response = await request(app)
      .post('/api/v1/admin/offers')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        title: 'Test Offer',
        description: 'Test Description',
        imageUrl: 'https://example.com/image.jpg',
        validFrom,
        validTo,
        isActive: true,
      });

    expect(response.status).toBe(201);
    expect(response.body.data).toHaveProperty('id');
    expect(response.body.data).toHaveProperty('title', 'Test Offer');
    expect(response.body.data).toHaveProperty('description', 'Test Description');
    expect(response.body.data).toHaveProperty('imageUrl', 'https://example.com/image.jpg');
    expect(response.body.data).toHaveProperty('validFrom', validFrom);
    expect(response.body.data).toHaveProperty('validTo', validTo);
    expect(response.body.data).not.toHaveProperty('adminSecret');

    const offer = await prisma.offer.findUnique({
      where: { id: response.body.data.id },
    });
    expect(offer).toBeTruthy();
    expect(offer?.title).toBe('Test Offer');
    expect(offer?.isActive).toBe(true);
  });

  it('should return 400 when validFrom > validTo', async () => {
    const validFrom = new Date('2026-12-31T23:59:59Z').toISOString();
    const validTo = new Date('2026-01-01T00:00:00Z').toISOString();

    const response = await request(app)
      .post('/api/v1/admin/offers')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        title: 'Test Offer',
        description: 'Test Description',
        validFrom,
        validTo,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
    expect(response.body.error.fields?.validTo).toContain('validFrom must be less than or equal to validTo');
  });

  it('should return 400 for validation errors', async () => {
    const response = await request(app)
      .post('/api/v1/admin/offers')
      .send({
        adminSecret: TEST_ADMIN_SECRET,
        title: '',
        description: 'Test Description',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});
