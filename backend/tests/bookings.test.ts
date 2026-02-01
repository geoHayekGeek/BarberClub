/**
 * Bookings management endpoint tests (Mes RDVs)
 */

import request from 'supertest';
import nock from 'nock';
import { createApp } from '../src/app';
import prisma from '../src/db/client';
import config from '../src/config';

beforeAll(async () => {
  await prisma.$connect();
  nock.disableNetConnect();
  nock.enableNetConnect('127.0.0.1');
  await prisma.loyaltyRedemptionToken.deleteMany();
  await prisma.loyaltyRedemption.deleteMany();
  await prisma.loyaltyState.deleteMany();
  await prisma.timifyReservation.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.branchCache.deleteMany();
  await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();
});

afterAll(async () => {
  await prisma.loyaltyRedemptionToken.deleteMany();
  await prisma.loyaltyRedemption.deleteMany();
  await prisma.loyaltyState.deleteMany();
  await prisma.timifyReservation.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.branchCache.deleteMany();
  await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();
  await prisma.$disconnect();
  nock.cleanAll();
  nock.enableNetConnect();
});

afterEach(() => {
  nock.cleanAll();
});

const app = createApp();

const TIMIFY_BASE_URL = config.TIMIFY_BASE_URL;

describe('GET /api/v1/bookings/me', () => {
  let accessToken: string;
  let userId: string;

  beforeEach(async () => {
    await prisma.booking.deleteMany();
    await prisma.branchCache.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'bookings@example.com',
        phoneNumber: '+1234567890',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;
  });

  it('should return empty list for user with no bookings', async () => {
    const response = await request(app)
      .get('/api/v1/bookings/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(0);
    expect(response.body.data.nextCursor).toBeNull();
  });

  it('should return only user\'s own bookings', async () => {
    const otherUserResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'other@example.com',
        phoneNumber: '+1987654321',
        password: 'password123',
      });

    const otherUserId = otherUserResponse.body.user.id;

    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const futureDate2 = new Date(Date.now() + 48 * 60 * 60 * 1000);

    await prisma.booking.createMany({
      data: [
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: futureDate,
          status: 'CONFIRMED',
        },
        {
          userId: otherUserId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: futureDate2,
          status: 'CONFIRMED',
        },
        {
          userId,
          branchId: 'branch-2',
          serviceId: 'service-2',
          startDateTime: futureDate2,
          status: 'CONFIRMED',
        },
      ],
    });

    const response = await request(app)
      .get('/api/v1/bookings/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(2);
    for (const item of response.body.data.items) {
      const booking = await prisma.booking.findUnique({
        where: { id: item.id },
      });
      expect(booking?.userId).toBe(userId);
    }
  });

  it('should filter upcoming bookings by default', async () => {
    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000);

    await prisma.booking.createMany({
      data: [
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: futureDate,
          status: 'CONFIRMED',
        },
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: pastDate,
          status: 'CONFIRMED',
        },
      ],
    });

    const response = await request(app)
      .get('/api/v1/bookings/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(1);
    expect(new Date(response.body.data.items[0].startDateTime) > new Date()).toBe(true);
  });

  it('should filter past bookings when status=past', async () => {
    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000);

    await prisma.booking.createMany({
      data: [
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: futureDate,
          status: 'CONFIRMED',
        },
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: pastDate,
          status: 'CONFIRMED',
        },
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: futureDate,
          status: 'CANCELED',
        },
      ],
    });

    const response = await request(app)
      .get('/api/v1/bookings/me?status=past')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items.length).toBeGreaterThanOrEqual(1);
    expect(response.body.data.items.some((item: { status: string }) => item.status === 'CANCELED')).toBe(true);
  });

  it('should return all bookings when status=all', async () => {
    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000);

    await prisma.booking.createMany({
      data: [
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: futureDate,
          status: 'CONFIRMED',
        },
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: pastDate,
          status: 'CONFIRMED',
        },
        {
          userId,
          branchId: 'branch-1',
          serviceId: 'service-1',
          startDateTime: futureDate,
          status: 'CANCELED',
        },
      ],
    });

    const response = await request(app)
      .get('/api/v1/bookings/me?status=all')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items.length).toBe(3);
  });

  it('should support pagination with cursor', async () => {
    const baseDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await prisma.booking.createMany({
      data: Array.from({ length: 25 }, (_, i) => ({
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: new Date(baseDate.getTime() + i * 60 * 60 * 1000),
        status: 'CONFIRMED',
      })),
    });

    const firstResponse = await request(app)
      .get('/api/v1/bookings/me?limit=10')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.body.data.items).toHaveLength(10);
    expect(firstResponse.body.data.nextCursor).toBeTruthy();

    const secondResponse = await request(app)
      .get(`/api/v1/bookings/me?limit=10&cursor=${firstResponse.body.data.nextCursor}`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(secondResponse.status).toBe(200);
    expect(secondResponse.body.data.items).toHaveLength(10);
    expect(secondResponse.body.data.items[0].id).not.toBe(firstResponse.body.data.items[0].id);
  });

  it('should include branch and service names when available', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies')
      .reply(200, [
        {
          id: 'branch-1',
          name: 'Downtown Branch',
          city: 'New York',
          address: '123 Main St',
          timezone: 'America/New_York',
        },
      ]);

    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies/branch-1/services')
      .reply(200, [
        {
          id: 'service-1',
          name: 'Haircut',
          duration: 30,
        },
      ]);

    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await prisma.booking.create({
      data: {
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: futureDate,
        status: 'CONFIRMED',
      },
    });

    const response = await request(app)
      .get('/api/v1/bookings/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items[0].branch).toHaveProperty('name', 'Downtown Branch');
    expect(response.body.data.items[0].branch).toHaveProperty('city', 'New York');
    expect(response.body.data.items[0].service).toHaveProperty('name', 'Haircut');
  });

  it('should return only ids when branch/service not found', async () => {
    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await prisma.booking.create({
      data: {
        userId,
        branchId: 'unknown-branch',
        serviceId: 'unknown-service',
        startDateTime: futureDate,
        status: 'CONFIRMED',
      },
    });

    const response = await request(app)
      .get('/api/v1/bookings/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items[0].branch).toEqual({ id: 'unknown-branch' });
    expect(response.body.data.items[0].service).toEqual({ id: 'unknown-service' });
  });

  it('should require authentication', async () => {
    const response = await request(app).get('/api/v1/bookings/me');

    expect(response.status).toBe(401);
  });

  it('should respect limit parameter', async () => {
    const baseDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await prisma.booking.createMany({
      data: Array.from({ length: 15 }, (_, i) => ({
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: new Date(baseDate.getTime() + i * 60 * 60 * 1000),
        status: 'CONFIRMED',
      })),
    });

    const response = await request(app)
      .get('/api/v1/bookings/me?limit=5')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data.items).toHaveLength(5);
  });

  it('should cap limit at 50', async () => {
    const baseDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    await prisma.booking.createMany({
      data: Array.from({ length: 60 }, (_, i) => ({
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: new Date(baseDate.getTime() + i * 60 * 60 * 1000),
        status: 'CONFIRMED',
      })),
    });

    const response = await request(app)
      .get('/api/v1/bookings/me?limit=100')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
});
});
describe('GET /api/v1/bookings/:id', () => {
  let accessToken: string;
  let userId: string;
  let bookingId: string;

  beforeEach(async () => {
    await prisma.booking.deleteMany();
    await prisma.branchCache.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'details@example.com',
        phoneNumber: '+1234567891',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;

    const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

    const booking = await prisma.booking.create({
      data: {
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: futureDate,
        status: 'CONFIRMED',
        timifyAppointmentId: 'timify-appt-123',
      },
    });

    bookingId = booking.id;
  });

  it('should return booking details', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies')
      .reply(200, [
        {
          id: 'branch-1',
          name: 'Downtown Branch',
          address: '123 Main St',
          city: 'New York',
          timezone: 'America/New_York',
        },
      ]);

    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies/branch-1/services')
      .reply(200, [
        {
          id: 'service-1',
          name: 'Haircut',
          duration: 30,
        },
      ]);

    const response = await request(app)
      .get(`/api/v1/bookings/${bookingId}`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('id', bookingId);
    expect(response.body.data).toHaveProperty('startDateTime');
    expect(response.body.data).toHaveProperty('status', 'CONFIRMED');
    expect(response.body.data.branch).toHaveProperty('name', 'Downtown Branch');
    expect(response.body.data.service).toHaveProperty('name', 'Haircut');
    expect(response.body.data).toHaveProperty('timifyAppointmentId', 'timify-appt-123');
  });

  it('should return 404 for non-existent booking', async () => {
    const response = await request(app)
      .get('/api/v1/bookings/00000000-0000-0000-0000-000000000000')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('BOOKING_NOT_FOUND');
  });

  it('should return 403 for booking belonging to another user', async () => {
    const otherUserResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'other@example.com',
        phoneNumber: '+1987654321',
        password: 'password123',
      });

    const otherAccessToken = otherUserResponse.body.accessToken;

    const response = await request(app)
      .get(`/api/v1/bookings/${bookingId}`)
      .set('Authorization', `Bearer ${otherAccessToken}`);

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('FORBIDDEN');
  });

  it('should require authentication', async () => {
    const response = await request(app).get(`/api/v1/bookings/${bookingId}`);

    expect(response.status).toBe(401);
  });

  it('should return 400 for invalid booking id format', async () => {
    const response = await request(app)
      .get('/api/v1/bookings/invalid-id')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});

describe('POST /api/v1/bookings/:id/cancel', () => {
  let accessToken: string;
  let userId: string;
  let bookingId: string;

  beforeEach(async () => {
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'cancel@example.com',
        phoneNumber: '+1234567892',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;

    const futureDate = new Date(Date.now() + 2 * 60 * 60 * 1000);

    const booking = await prisma.booking.create({
      data: {
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: futureDate,
        status: 'CONFIRMED',
      },
    });

    bookingId = booking.id;
  });

  it('should cancel booking when ENABLE_LOCAL_CANCEL=true', async () => {
    const originalValue = process.env.ENABLE_LOCAL_CANCEL;
    process.env.ENABLE_LOCAL_CANCEL = 'true';

    const response = await request(app)
      .post(`/api/v1/bookings/${bookingId}/cancel`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('status', 'CANCELED');

    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
    });

    expect(booking?.status).toBe('CANCELED');

    if (originalValue) {
      process.env.ENABLE_LOCAL_CANCEL = originalValue;
    } else {
      delete process.env.ENABLE_LOCAL_CANCEL;
    }
  });

  it('should fail when ENABLE_LOCAL_CANCEL=false', async () => {
    const originalValue = process.env.ENABLE_LOCAL_CANCEL;
    process.env.ENABLE_LOCAL_CANCEL = 'false';

    const response = await request(app)
      .post(`/api/v1/bookings/${bookingId}/cancel`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('CANCEL_NOT_AVAILABLE');

    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
    });

    expect(booking?.status).toBe('CONFIRMED');

    if (originalValue) {
      process.env.ENABLE_LOCAL_CANCEL = originalValue;
    } else {
      delete process.env.ENABLE_LOCAL_CANCEL;
    }
  });

  it('should fail for past booking', async () => {
    const originalValue = process.env.ENABLE_LOCAL_CANCEL;
    process.env.ENABLE_LOCAL_CANCEL = 'true';

    const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const pastBooking = await prisma.booking.create({
      data: {
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: pastDate,
        status: 'CONFIRMED',
      },
    });

    const response = await request(app)
      .post(`/api/v1/bookings/${pastBooking.id}/cancel`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('BOOKING_NOT_CANCELABLE');

    if (originalValue) {
      process.env.ENABLE_LOCAL_CANCEL = originalValue;
    } else {
      delete process.env.ENABLE_LOCAL_CANCEL;
    }
  });

  it('should fail if already canceled', async () => {
    const originalValue = process.env.ENABLE_LOCAL_CANCEL;
    process.env.ENABLE_LOCAL_CANCEL = 'true';

    await prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'CANCELED' },
    });

    const response = await request(app)
      .post(`/api/v1/bookings/${bookingId}/cancel`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('BOOKING_NOT_CANCELABLE');

    if (originalValue) {
      process.env.ENABLE_LOCAL_CANCEL = originalValue;
    } else {
      delete process.env.ENABLE_LOCAL_CANCEL;
    }
  });

  it('should fail if within cancel cutoff time', async () => {
    const originalValue = process.env.ENABLE_LOCAL_CANCEL;
    const originalCutoff = process.env.BOOKING_CANCEL_CUTOFF_MINUTES;
    process.env.ENABLE_LOCAL_CANCEL = 'true';
    process.env.BOOKING_CANCEL_CUTOFF_MINUTES = '120';

    const nearFutureDate = new Date(Date.now() + 30 * 60 * 1000);

    const nearBooking = await prisma.booking.create({
      data: {
        userId,
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDateTime: nearFutureDate,
        status: 'CONFIRMED',
      },
    });

    const response = await request(app)
      .post(`/api/v1/bookings/${nearBooking.id}/cancel`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('BOOKING_NOT_CANCELABLE');

    if (originalValue) {
      process.env.ENABLE_LOCAL_CANCEL = originalValue;
    } else {
      delete process.env.ENABLE_LOCAL_CANCEL;
    }

    if (originalCutoff) {
      process.env.BOOKING_CANCEL_CUTOFF_MINUTES = originalCutoff;
    } else {
      delete process.env.BOOKING_CANCEL_CUTOFF_MINUTES;
    }
  });

  it('should return 404 for non-existent booking', async () => {
    const originalValue = process.env.ENABLE_LOCAL_CANCEL;
    process.env.ENABLE_LOCAL_CANCEL = 'true';

    const response = await request(app)
      .post('/api/v1/bookings/00000000-0000-0000-0000-000000000000/cancel')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('BOOKING_NOT_FOUND');

    if (originalValue) {
      process.env.ENABLE_LOCAL_CANCEL = originalValue;
    } else {
      delete process.env.ENABLE_LOCAL_CANCEL;
    }
  });

  it('should return 403 for booking belonging to another user', async () => {
    const originalValue = process.env.ENABLE_LOCAL_CANCEL;
    process.env.ENABLE_LOCAL_CANCEL = 'true';

    const otherUserResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'other2@example.com',
        phoneNumber: '+1987654322',
        password: 'password123',
      });

    const otherAccessToken = otherUserResponse.body.accessToken;

    const response = await request(app)
      .post(`/api/v1/bookings/${bookingId}/cancel`)
      .set('Authorization', `Bearer ${otherAccessToken}`);

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('FORBIDDEN');

    if (originalValue) {
      process.env.ENABLE_LOCAL_CANCEL = originalValue;
    } else {
      delete process.env.ENABLE_LOCAL_CANCEL;
    }
  });

  it('should require authentication', async () => {
    const response = await request(app).post(`/api/v1/bookings/${bookingId}/cancel`);

    expect(response.status).toBe(401);
  });
});
