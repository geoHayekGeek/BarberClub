/**
 * Booking endpoint tests
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
  // Clean up all data before starting tests
  await prisma.timifyReservation.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();
});

afterAll(async () => {
  // Clean up all data after tests
  await prisma.timifyReservation.deleteMany();
  await prisma.booking.deleteMany();
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

describe('GET /api/v1/booking/branches', () => {
  it('should return list of branches', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies')
      .reply(200, [
        {
          id: 'company-1',
          name: 'Barber Shop Downtown',
          address: '123 Main St',
          city: 'New York',
          country: 'US',
        },
        {
          id: 'company-2',
          name: 'Barber Shop Uptown',
          address: '456 Park Ave',
          city: 'New York',
          country: 'US',
        },
      ]);

    const response = await request(app).get('/api/v1/booking/branches');

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('data');
    expect(response.body.data).toHaveLength(2);
    expect(response.body.data[0]).toHaveProperty('id');
    expect(response.body.data[0]).toHaveProperty('name');
  });

  it('should filter branches by TIMIFY_COMPANY_IDS when configured', async () => {
    const originalCompanyIds = process.env.TIMIFY_COMPANY_IDS;
    process.env.TIMIFY_COMPANY_IDS = 'company-1';

    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies')
      .reply(200, [
        {
          id: 'company-1',
          name: 'Barber Shop Downtown',
        },
        {
          id: 'company-2',
          name: 'Barber Shop Uptown',
        },
      ]);

    const response = await request(app).get('/api/v1/booking/branches');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0].id).toBe('company-1');

    if (originalCompanyIds) {
      process.env.TIMIFY_COMPANY_IDS = originalCompanyIds;
    } else {
      delete process.env.TIMIFY_COMPANY_IDS;
    }
  });

  it('should handle TIMIFY API errors', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies')
      .reply(500, { error: 'Internal server error' });

    const response = await request(app).get('/api/v1/booking/branches');

    expect(response.status).toBe(500);
    expect(response.body.error).toBeDefined();
    expect(response.body.error.code).toBe('BOOKING_PROVIDER_ERROR');
  });
});

describe('GET /api/v1/booking/branches/:branchId/services', () => {
  it('should return services for a branch', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies/branch-1/services')
      .reply(200, [
        {
          id: 'service-1',
          name: 'Haircut',
          duration: 30,
          price: 25,
          currency: 'USD',
        },
        {
          id: 'service-2',
          name: 'Beard Trim',
          duration: 15,
          price: 15,
          currency: 'USD',
        },
      ]);

    const response = await request(app).get('/api/v1/booking/branches/branch-1/services');

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('data');
    expect(response.body.data).toHaveLength(2);
    expect(response.body.data[0]).toHaveProperty('id');
    expect(response.body.data[0]).toHaveProperty('name');
    expect(response.body.data[0]).toHaveProperty('durationMinutes');
  });

  it('should filter out services with zero duration', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies/branch-1/services')
      .reply(200, [
        {
          id: 'service-1',
          name: 'Haircut',
          duration: 30,
        },
        {
          id: 'service-2',
          name: 'Invalid Service',
          duration: 0,
        },
      ]);

    const response = await request(app).get('/api/v1/booking/branches/branch-1/services');

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0].id).toBe('service-1');
  });
});

describe('GET /api/v1/booking/availability', () => {
  it('should return availability data', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/availabilities')
      .query({
        company_id: 'branch-1',
        service_id: 'service-1',
        start_date: '2024-01-01',
        end_date: '2024-01-07',
      })
      .reply(200, {
        calendar_begin: '2024-01-01',
        calendar_end: '2024-01-07',
        on_days: ['2024-01-01', '2024-01-02', '2024-01-03'],
        off_days: ['2024-01-04'],
        slots: [
          {
            start: '2024-01-01T10:00:00Z',
            end: '2024-01-01T10:30:00Z',
          },
          {
            start: '2024-01-01T11:00:00Z',
            end: '2024-01-01T11:30:00Z',
          },
        ],
      });

    const response = await request(app)
      .get('/api/v1/booking/availability')
      .query({
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDate: '2024-01-01',
        endDate: '2024-01-07',
      });

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('data');
    expect(response.body.data).toHaveProperty('calendarBegin');
    expect(response.body.data).toHaveProperty('calendarEnd');
    expect(response.body.data).toHaveProperty('onDays');
    expect(response.body.data).toHaveProperty('offDays');
    expect(response.body.data).toHaveProperty('timesByDay');
    expect(response.body.data.timesByDay['2024-01-01']).toContain('10:00');
    expect(response.body.data.timesByDay['2024-01-01']).toContain('11:00');
  });

  it('should return 400 for invalid query parameters', async () => {
    const response = await request(app)
      .get('/api/v1/booking/availability')
      .query({
        branchId: 'branch-1',
        serviceId: 'service-1',
        startDate: 'invalid-date',
        endDate: '2024-01-07',
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toBeDefined();
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });
});

describe('POST /api/v1/booking/reserve', () => {
  let accessToken: string;
  let userId: string;

  beforeEach(async () => {
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'booking@example.com',
        phoneNumber: '+1234567890',
        password: 'password123',
      });

    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;
  });

  afterEach(async () => {
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();
  });

  it('should create a reservation', async () => {
    nock(TIMIFY_BASE_URL)
      .post('/booker-services/reservations', {
        company_id: 'branch-1',
        service_id: 'service-1',
        date: '2024-01-01',
        time: '10:00',
      })
      .reply(200, {
        reservation_id: 'timify-res-123',
        secret: 'timify-secret-456',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      });

    const response = await request(app)
      .post('/api/v1/booking/reserve')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        branchId: 'branch-1',
        serviceId: 'service-1',
        date: '2024-01-01',
        time: '10:00',
      });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('data');
    expect(response.body.data).toHaveProperty('reservationId');
    expect(response.body.data).toHaveProperty('expiresAt');

    const reservation = await prisma.timifyReservation.findUnique({
      where: { id: response.body.data.reservationId },
    });

    expect(reservation).toBeTruthy();
    expect(reservation?.userId).toBe(userId);
    expect(reservation?.branchId).toBe('branch-1');
    expect(reservation?.serviceId).toBe('service-1');
  });

  it('should return 401 without token', async () => {
    const response = await request(app)
      .post('/api/v1/booking/reserve')
      .send({
        branchId: 'branch-1',
        serviceId: 'service-1',
        date: '2024-01-01',
        time: '10:00',
      });

    expect(response.status).toBe(401);
  });

  it('should return 400 for invalid request body', async () => {
    const response = await request(app)
      .post('/api/v1/booking/reserve')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        branchId: 'branch-1',
        date: 'invalid-date',
      });

    expect(response.status).toBe(400);
  });

  it('should handle TIMIFY API errors', async () => {
    nock(TIMIFY_BASE_URL)
      .post('/booker-services/reservations')
      .reply(409, { error: 'Slot already taken' });

    const response = await request(app)
      .post('/api/v1/booking/reserve')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        branchId: 'branch-1',
        serviceId: 'service-1',
        date: '2024-01-01',
        time: '10:00',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe('BOOKING_SLOT_UNAVAILABLE');
  });
});

describe('POST /api/v1/booking/confirm', () => {
  let accessToken: string;
  let userId: string;
  let reservationId: string;

  beforeEach(async () => {
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'confirm@example.com',
        phoneNumber: '+1234567890',
        password: 'password123',
      });

    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;

    nock(TIMIFY_BASE_URL)
      .post('/booker-services/reservations')
      .reply(200, {
        reservation_id: 'timify-res-123',
        secret: 'timify-secret-456',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      });

    const reserveResponse = await request(app)
      .post('/api/v1/booking/reserve')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        branchId: 'branch-1',
        serviceId: 'service-1',
        date: '2024-01-01',
        time: '10:00',
      });

    expect(reserveResponse.status).toBe(201);
    expect(reserveResponse.body.data).toBeDefined();
    reservationId = reserveResponse.body.data.reservationId;
    expect(reservationId).toBeDefined();
  });

  afterEach(async () => {
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();
  });

  it('should confirm a reservation and create booking', async () => {
    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies/branch-1/services')
      .reply(200, [
        {
          id: 'service-1',
          name: 'Haircut',
          duration: 30,
        },
      ]);

    nock(TIMIFY_BASE_URL)
      .post('/booker-services/appointments/confirm', {
        company_id: 'branch-1',
        reservation_id: 'timify-res-123',
        secret: 'timify-secret-456',
        external_customer_id: userId,
        is_course: false,
        region: config.TIMIFY_REGION,
      })
      .reply(200, {
        appointment_id: 'timify-appt-789',
        status: 'confirmed',
      });

    const response = await request(app)
      .post('/api/v1/booking/confirm')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        reservationId,
      });

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('data');
    expect(response.body.data).toHaveProperty('id');
    expect(response.body.data).toHaveProperty('status', 'CONFIRMED');
    expect(response.body.data.userId).toBe(userId);

    const booking = await prisma.booking.findUnique({
      where: { id: response.body.data.id },
    });

    expect(booking).toBeTruthy();
    expect(booking?.status).toBe('CONFIRMED');

    const reservation = await prisma.timifyReservation.findUnique({
      where: { id: reservationId },
    });

    expect(reservation?.usedAt).toBeTruthy();
  });

  it('should fail for expired reservation', async () => {
    nock(TIMIFY_BASE_URL)
      .post('/booker-services/reservations')
      .reply(200, {
        reservation_id: 'timify-res-expired',
        secret: 'timify-secret-expired',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      });

    const reserveResponse = await request(app)
      .post('/api/v1/booking/reserve')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        branchId: 'branch-1',
        serviceId: 'service-1',
        date: '2024-01-01',
        time: '13:00',
      });

    expect(reserveResponse.status).toBe(201);
    const testReservationId = reserveResponse.body.data.reservationId;

    await prisma.timifyReservation.update({
      where: { id: testReservationId },
      data: {
        expiresAt: new Date(Date.now() - 1000),
      },
    });

    const response = await request(app)
      .post('/api/v1/booking/confirm')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        reservationId: testReservationId,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('BOOKING_VALIDATION_ERROR');
    expect(response.body.error.message).toContain('expired');
  });

  it('should fail for used reservation', async () => {
    nock(TIMIFY_BASE_URL)
      .post('/booker-services/reservations')
      .reply(200, {
        reservation_id: 'timify-res-used',
        secret: 'timify-secret-used',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      });

    const reserveResponse = await request(app)
      .post('/api/v1/booking/reserve')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        branchId: 'branch-1',
        serviceId: 'service-1',
        date: '2024-01-01',
        time: '12:00',
      });

    expect(reserveResponse.status).toBe(201);
    const testReservationId = reserveResponse.body.data.reservationId;

    await prisma.timifyReservation.update({
      where: { id: testReservationId },
      data: {
        usedAt: new Date(),
      },
    });

    const response = await request(app)
      .post('/api/v1/booking/confirm')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        reservationId: testReservationId,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('BOOKING_VALIDATION_ERROR');
    expect(response.body.error.message).toContain('already used');
  });

  it('should not create booking on TIMIFY confirmation failure', async () => {
    nock(TIMIFY_BASE_URL)
      .post('/booker-services/reservations')
      .reply(200, {
        reservation_id: 'timify-res-fail',
        secret: 'timify-secret-fail',
        expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
      });

    const reserveResponse = await request(app)
      .post('/api/v1/booking/reserve')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        branchId: 'branch-1',
        serviceId: 'service-1',
        date: '2024-01-01',
        time: '11:00',
      });

    expect(reserveResponse.status).toBe(201);
    const testReservationId = reserveResponse.body.data.reservationId;

    nock(TIMIFY_BASE_URL)
      .get('/booker-services/companies/branch-1/services')
      .reply(200, [
        {
          id: 'service-1',
          name: 'Haircut',
          duration: 30,
        },
      ]);

    nock(TIMIFY_BASE_URL)
      .post('/booker-services/appointments/confirm')
      .reply(400, { error: 'Reservation expired' });

    const bookingCountBefore = await prisma.booking.count();

    const response = await request(app)
      .post('/api/v1/booking/confirm')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        reservationId: testReservationId,
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('BOOKING_VALIDATION_ERROR');

    const bookingCountAfter = await prisma.booking.count();
    expect(bookingCountAfter).toBe(bookingCountBefore);

    const reservation = await prisma.timifyReservation.findUnique({
      where: { id: testReservationId },
    });

    expect(reservation?.usedAt).toBeNull();
  });

  it('should return 404 for non-existent reservation', async () => {
    const response = await request(app)
      .post('/api/v1/booking/confirm')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        reservationId: '00000000-0000-0000-0000-000000000000',
      });

    expect(response.status).toBe(404);
  });

  it('should return 403 for reservation belonging to another user', async () => {
    const otherUserResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'other@example.com',
        phoneNumber: '+1987654321',
        password: 'password123',
      });

    const otherAccessToken = otherUserResponse.body.accessToken;

    const response = await request(app)
      .post('/api/v1/booking/confirm')
      .set('Authorization', `Bearer ${otherAccessToken}`)
      .send({
        reservationId,
      });

    expect(response.status).toBe(403);
  });
});
