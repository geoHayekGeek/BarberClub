/**
 * Loyalty endpoint tests
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
  await prisma.loyaltyState.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();
});

afterAll(async () => {
  await prisma.loyaltyState.deleteMany();
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

describe('GET /api/v1/loyalty/me', () => {
  let accessToken: string;
  let userId: string;

  beforeEach(async () => {
    await prisma.loyaltyState.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'loyalty@example.com',
        phoneNumber: '+1234567890',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;
  });

  it('should return loyalty state for new user', async () => {
    const response = await request(app)
      .get('/api/v1/loyalty/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('points', 0);
    expect(response.body.data).toHaveProperty('target', config.LOYALTY_TARGET);
    expect(response.body.data).toHaveProperty('availableCoupons', 0);
    expect(response.body.data).toHaveProperty('memberSince');
  });

  it('should return loyalty state with existing stamps', async () => {
    await prisma.user.update({
      where: { id: userId },
      data: { loyaltyPoints: 5 },
    });

    const response = await request(app)
      .get('/api/v1/loyalty/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('points', 5);
    expect(response.body.data).toHaveProperty('target', config.LOYALTY_TARGET);
    expect(response.body.data).toHaveProperty('availableCoupons', 0);
  });

  it('should return eligibleForReward true when stamps >= target', async () => {
    await prisma.user.update({
      where: { id: userId },
      data: { loyaltyPoints: config.LOYALTY_TARGET },
    });

    const response = await request(app)
      .get('/api/v1/loyalty/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('points', config.LOYALTY_TARGET);
    expect(response.body.data).toHaveProperty('target', config.LOYALTY_TARGET);
  });

  it('should require authentication', async () => {
    const response = await request(app).get('/api/v1/loyalty/me');

    expect(response.status).toBe(401);
  });
});

describe('POST /api/v1/loyalty/redeem', () => {
  let accessToken: string;
  let userId: string;

  beforeEach(async () => {
    await prisma.loyaltyState.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'redeem@example.com',
        phoneNumber: '+1234567891',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;
  });

  it('should fail when not enough stamps', async () => {
    await prisma.loyaltyState.create({
      data: {
        userId,
        stamps: 5,
      },
    });

    const response = await request(app)
      .post('/api/v1/loyalty/redeem')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('BOOKING_VALIDATION_ERROR');
    expect(response.body.error.message).toContain('Not enough stamps');
  });

  it('should redeem reward when eligible', async () => {
    await prisma.loyaltyState.create({
      data: {
        userId,
        stamps: config.LOYALTY_TARGET,
      },
    });

    const response = await request(app)
      .post('/api/v1/loyalty/redeem')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('success', true);

    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    expect(loyaltyState?.stamps).toBe(0);
  });

  it('should subtract target from stamps when redeeming', async () => {
    const initialStamps = config.LOYALTY_TARGET + 3;
    await prisma.loyaltyState.create({
      data: {
        userId,
        stamps: initialStamps,
      },
    });

    const response = await request(app)
      .post('/api/v1/loyalty/redeem')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('success', true);

    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    expect(loyaltyState?.stamps).toBe(3);
  });

  it('should require authentication', async () => {
    const response = await request(app).post('/api/v1/loyalty/redeem');

    expect(response.status).toBe(401);
  });
});

describe('GET /api/v1/loyalty/qr', () => {
  let accessToken: string;
  let userId: string;

  beforeEach(async () => {
    await prisma.loyaltyRedemptionToken.deleteMany();
    await prisma.loyaltyRedemption.deleteMany();
    await prisma.loyaltyState.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'qr@example.com',
        phoneNumber: '+1234567893',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;
  });

  it('should fail when stamps < target', async () => {
    await prisma.loyaltyState.create({
      data: {
        userId,
        stamps: 5,
      },
    });

    const response = await request(app)
      .get('/api/v1/loyalty/qr')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('LOYALTY_NOT_READY');
    expect(response.body.error.message).toContain('target not reached');
  });

  it('should generate QR when stamps >= target', async () => {
    await prisma.loyaltyState.create({
      data: {
        userId,
        stamps: config.LOYALTY_TARGET,
      },
    });

    const response = await request(app)
      .get('/api/v1/loyalty/qr')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('qrPayload');
    expect(response.body.data).toHaveProperty('expiresAt');
    expect(response.body.data.qrPayload).toMatch(/^LOYALTY:/);
  });

  it('should invalidate previous token when generating new QR', async () => {
    await prisma.loyaltyState.create({
      data: {
        userId,
        stamps: config.LOYALTY_TARGET,
      },
    });

    const firstResponse = await request(app)
      .get('/api/v1/loyalty/qr')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(firstResponse.status).toBe(200);
    const firstToken = firstResponse.body.data.qrPayload;

    await new Promise((resolve) => setTimeout(resolve, 100));

    const secondResponse = await request(app)
      .get('/api/v1/loyalty/qr')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(secondResponse.status).toBe(200);
    const secondToken = secondResponse.body.data.qrPayload;

    expect(firstToken).not.toBe(secondToken);

    const tokens = await prisma.loyaltyRedemptionToken.findMany({
      where: { userId },
    });

    const unusedTokens = tokens.filter((t) => !t.usedAt && t.expiresAt > new Date());
    expect(unusedTokens).toHaveLength(1);
  });

  it('should require authentication', async () => {
    const response = await request(app).get('/api/v1/loyalty/qr');

    expect(response.status).toBe(401);
  });
});

describe('POST /api/v1/loyalty/scan', () => {
  let accessToken: string;
  let userId: string;
  let qrPayload: string;

  beforeEach(async () => {
    await prisma.loyaltyRedemptionToken.deleteMany();
    await prisma.loyaltyRedemption.deleteMany();
    await prisma.loyaltyState.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'scan@example.com',
        phoneNumber: '+1234567894',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;

    await prisma.loyaltyState.create({
      data: {
        userId,
        stamps: config.LOYALTY_TARGET,
      },
    });

    const qrResponse = await request(app)
      .get('/api/v1/loyalty/qr')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(qrResponse.status).toBe(200);
    qrPayload = qrResponse.body.data.qrPayload;
  });

  it('should redeem QR code and reset stamps', async () => {
    const response = await request(app)
      .post('/api/v1/loyalty/scan')
      .send({ qrPayload });

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('status', 'redeemed');
    expect(response.body.data).toHaveProperty('resetStamps', true);

    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    expect(loyaltyState?.stamps).toBe(0);

    const redemption = await prisma.loyaltyRedemption.findFirst({
      where: { userId },
    });

    expect(redemption).toBeTruthy();
    expect(redemption?.previousStamps).toBe(config.LOYALTY_TARGET);

    const token = await prisma.loyaltyRedemptionToken.findFirst({
      where: { userId },
    });

    expect(token?.usedAt).toBeTruthy();
  });

  it('should fail for invalid QR payload', async () => {
    const response = await request(app)
      .post('/api/v1/loyalty/scan')
      .send({ qrPayload: 'INVALID:token' });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('INVALID_OR_EXPIRED_QR');
  });

  it('should fail for reused QR code', async () => {
    const firstResponse = await request(app)
      .post('/api/v1/loyalty/scan')
      .send({ qrPayload });

    expect(firstResponse.status).toBe(200);

    const secondResponse = await request(app)
      .post('/api/v1/loyalty/scan')
      .send({ qrPayload });

    expect(secondResponse.status).toBe(400);
    expect(secondResponse.body.error.code).toBe('INVALID_OR_EXPIRED_QR');
  });

  it('should fail for expired QR code', async () => {
    const { createHash } = require('crypto');
    const rawToken = require('crypto').randomBytes(32).toString('hex');
    const tokenHash = createHash('sha256').update(rawToken).digest('hex');
    const expiredAt = new Date(Date.now() - 1000);

    await prisma.loyaltyRedemptionToken.create({
      data: {
        userId,
        tokenHash,
        expiresAt: expiredAt,
      },
    });

    const expiredQrPayload = `LOYALTY:${rawToken}`;

    const response = await request(app)
      .post('/api/v1/loyalty/scan')
      .send({ qrPayload: expiredQrPayload });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('INVALID_OR_EXPIRED_QR');
  });

  it('should handle race condition (double scan)', async () => {
    const scanPromises = [
      request(app).post('/api/v1/loyalty/scan').send({ qrPayload }),
      request(app).post('/api/v1/loyalty/scan').send({ qrPayload }),
    ];

    const responses = await Promise.all(scanPromises);

    const successCount = responses.filter((r) => r.status === 200).length;
    const errorCount = responses.filter((r) => r.status === 400).length;

    expect(successCount).toBe(1);
    expect(errorCount).toBe(1);

    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    expect(loyaltyState?.stamps).toBe(0);
  });

  it('should require valid qrPayload format', async () => {
    const response = await request(app)
      .post('/api/v1/loyalty/scan')
      .send({ qrPayload: 'not-a-valid-format' });

    expect(response.status).toBe(400);
  });
});

describe('GET /api/v1/loyalty/me - updated response', () => {
  let accessToken: string;
  let userId: string;

  beforeEach(async () => {
    await prisma.loyaltyState.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.passwordResetCode.deleteMany();
  await prisma.passwordResetToken.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'me@example.com',
        phoneNumber: '+1234567895',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(registerResponse.status).toBe(201);
    accessToken = registerResponse.body.accessToken;
    userId = registerResponse.body.user.id;
  });

  it('should return points and target', async () => {
    await prisma.user.update({
      where: { id: userId },
      data: { loyaltyPoints: config.LOYALTY_TARGET },
    });

    const response = await request(app)
      .get('/api/v1/loyalty/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveProperty('points', config.LOYALTY_TARGET);
    expect(response.body.data).toHaveProperty('target', config.LOYALTY_TARGET);
  });
});
