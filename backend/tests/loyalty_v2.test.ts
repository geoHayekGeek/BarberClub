/**
 * Loyalty v2 tests: points-as-currency, earn flow, redeem flow, tiers.
 */

const TEST_ADMIN_SECRET = 'test-admin-secret-12345678901234567890';
const ORIGINAL_ADMIN_SECRET = process.env.ADMIN_SECRET;
process.env.ADMIN_SECRET = TEST_ADMIN_SECRET;

import request from 'supertest';
import nock from 'nock';
import { createApp } from '../src/app';
import prisma from '../src/db/client';
import { getTierFromLifetime, getNextTier } from '../src/modules/loyalty_v2/tiers';

beforeAll(async () => {
  await prisma.$connect();
  nock.disableNetConnect();
  nock.enableNetConnect('127.0.0.1');
});

afterAll(async () => {
  await prisma.$disconnect();
  nock.cleanAll();
  nock.enableNetConnect();
  if (ORIGINAL_ADMIN_SECRET !== undefined) {
    process.env.ADMIN_SECRET = ORIGINAL_ADMIN_SECRET;
  } else {
    delete process.env.ADMIN_SECRET;
  }
});

async function cleanupLoyaltyV2() {
  await prisma.loyaltyTransaction.deleteMany();
  await prisma.loyaltyRedemptionVoucher.deleteMany();
  await prisma.loyaltyAccountQrToken.deleteMany();
  await prisma.loyaltyAccount.deleteMany();
}

const app = createApp();

describe('Loyalty v2 tier logic', () => {
  it('returns Bronze for 0-199 lifetime', () => {
    expect(getTierFromLifetime(0)).toBe('Bronze');
    expect(getTierFromLifetime(199)).toBe('Bronze');
  });
  it('returns Silver for 200-499', () => {
    expect(getTierFromLifetime(200)).toBe('Silver');
    expect(getTierFromLifetime(499)).toBe('Silver');
  });
  it('returns Gold for 500-999', () => {
    expect(getTierFromLifetime(500)).toBe('Gold');
    expect(getTierFromLifetime(999)).toBe('Gold');
  });
  it('returns Platinum for 1000+', () => {
    expect(getTierFromLifetime(1000)).toBe('Platinum');
    expect(getTierFromLifetime(5000)).toBe('Platinum');
  });
  it('getNextTier returns next tier and remaining points', () => {
    const next = getNextTier(100);
    expect(next?.name).toBe('Silver');
    expect(next?.remainingPoints).toBe(100);
    const next199 = getNextTier(199);
    expect(next199?.remainingPoints).toBe(1);
    expect(getNextTier(1000)).toBeNull();
  });
});

describe('Loyalty v2 earn flow', () => {
  let userToken: string;
  let adminToken: string;
  let serviceId: string;

  beforeAll(async () => {
    jest.setTimeout(15000);
    await cleanupLoyaltyV2();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany({ where: { email: 'v2earn@example.com' } });
    let salon = (await prisma.salon.findMany({ take: 1 }))[0];
    if (!salon) {
      salon = await prisma.salon.create({
        data: {
          name: 'Test Salon',
          city: 'Paris',
          address: '1 rue Test',
          openingHours: '9h-18h',
          images: [],
        },
      });
    }
    const offer = await prisma.offer.create({
      data: { title: 'Coupe Test', price: 25, isActive: true, salonId: salon.id },
    });
    serviceId = offer.id;

    const reg = await request(app).post('/api/v1/auth/register').send({
      email: 'v2earn@example.com',
      phoneNumber: '+12025550101',
      password: 'password123',
      fullName: 'Earn User',
    });
    if (reg.status !== 201) {
      throw new Error(`Register failed: ${JSON.stringify(reg.body)}`);
    }
    userToken = reg.body.accessToken;

    let adminUser = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
    if (!adminUser) {
      const createAdmin = await request(app)
        .post('/api/v1/auth/register')
        .send({ email: 'adminv2@test.com', phoneNumber: '+12025550102', password: 'password123', fullName: 'Admin' });
      const id = createAdmin.body.user.id;
      await prisma.user.update({ where: { id }, data: { role: 'ADMIN' } });
      adminUser = await prisma.user.findUnique({ where: { id } });
    }
    const login = await request(app).post('/api/v1/auth/login').send({
      email: adminUser!.email,
      password: adminUser!.email === 'adminv2@test.com' ? 'password123' : 'admin123',
    });
    expect(login.status).toBe(200);
    adminToken = login.body.accessToken;
  });

  afterAll(async () => {
    await prisma.offer.deleteMany({ where: { title: 'Coupe Test' } });
    await cleanupLoyaltyV2();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany({ where: { email: 'v2earn@example.com' } });
  });

  it('GET /loyalty/v2/me creates account and returns state', async () => {
    const res = await request(app).get('/api/v1/loyalty/v2/me').set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.currentBalance).toBe(0);
    expect(res.body.data.lifetimeEarned).toBe(0);
    expect(res.body.data.tier).toBe('Bronze');
    expect(res.body.data.enrolledAt).toBeDefined();
  });

  it('POST /loyalty/v2/qr returns earn QR payload', async () => {
    const res = await request(app).post('/api/v1/loyalty/v2/qr').set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.qrPayload).toMatch(/^BC\|v1\|E\|/);
    expect(res.body.data.expiresAt).toBeDefined();
  });

  it('POST /admin/loyalty/earn with valid QR and serviceId updates balance and lifetime', async () => {
    const qrRes = await request(app).post('/api/v1/loyalty/v2/qr').set('Authorization', `Bearer ${userToken}`);
    const qrPayload = qrRes.body.data.qrPayload;

    const earnRes = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload, serviceId });

    expect(earnRes.status).toBe(200);
    expect(earnRes.body.data.pointsEarned).toBe(25);
    expect(earnRes.body.data.newBalance).toBe(25);
    expect(earnRes.body.data.newLifetime).toBe(25);
    expect(earnRes.body.data.newTier).toBe('Bronze');
  });

  it('admin earn with same QR again returns 400 (token used)', async () => {
    const qrRes = await request(app).post('/api/v1/loyalty/v2/qr').set('Authorization', `Bearer ${userToken}`);
    const qrPayload = qrRes.body.data.qrPayload;

    const first = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload, serviceId });
    expect(first.status).toBe(200);

    const second = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload, serviceId });
    expect(second.status).toBe(400);
    expect(second.body.error.code).toBe('INVALID_QR');
  });

  it('admin earn with invalid payload returns 400 INVALID_QR', async () => {
    const res = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload: 'invalid', serviceId });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_QR');
  });

  it('admin earn with wrong type (V) returns 400 INVALID_QR', async () => {
    const qrRes = await request(app).post('/api/v1/loyalty/v2/qr').set('Authorization', `Bearer ${userToken}`);
    const payload = qrRes.body.data.qrPayload as string;
    const voucherPayload = payload.replace(/^BC\|v1\|E\|/, 'BC|v1|V|');
    const res = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload: voucherPayload, serviceId });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_QR');
  });

  it('admin earn with invalid prefix returns 400 INVALID_QR', async () => {
    const res = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload: 'XX|v1|E|abcdefghij1234567890abcdefghij1234567890', serviceId });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_QR');
  });

  it('admin earn with invalid serviceId returns 404', async () => {
    const qrRes = await request(app).post('/api/v1/loyalty/v2/qr').set('Authorization', `Bearer ${userToken}`);
    const qrPayload = qrRes.body.data.qrPayload;
    const fakeServiceId = '00000000-0000-0000-0000-000000000000';
    const res = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload, serviceId: fakeServiceId });
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('OFFER_NOT_FOUND');
  });

  it('admin earn with expired token returns 400 INVALID_QR', async () => {
    const qrRes = await request(app).post('/api/v1/loyalty/v2/qr').set('Authorization', `Bearer ${userToken}`);
    const qrPayload = qrRes.body.data.qrPayload as string;
    const tokenPart = qrPayload.split('|')[3];
    const { hashToken } = await import('../src/utils/qr');
    const tokenHash = hashToken(tokenPart);
    const updated = await prisma.loyaltyAccountQrToken.updateMany(
      { where: { tokenHash }, data: { expiresAt: new Date(0) } }
    );
    if (updated.count === 0) throw new Error('Token not found to expire');
    const res = await request(app)
      .post('/api/v1/admin/loyalty/earn')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload, serviceId });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_QR');
  });
});

describe('Loyalty v2 redeem flow', () => {
  let userToken: string;
  let adminToken: string;
  let rewardId: string;

  beforeAll(async () => {
    await cleanupLoyaltyV2();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany({ where: { email: 'v2redeem@example.com' } });
    const reward = await prisma.loyaltyReward.findFirst({ where: { isActive: true } });
    if (!reward) throw new Error('Need seeded reward');
    rewardId = reward.id;

    const reg = await request(app).post('/api/v1/auth/register').send({
      email: 'v2redeem@example.com',
      phoneNumber: '+12025550103',
      password: 'password123',
      fullName: 'Redeem User',
    });
    if (reg.status !== 201) {
      throw new Error(`Register failed: ${JSON.stringify(reg.body)}`);
    }
    userToken = reg.body.accessToken;

    let adminUser = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
    if (!adminUser) {
      const createAdmin = await request(app)
        .post('/api/v1/auth/register')
        .send({ email: 'adminv2@test.com', phoneNumber: '+12025550104', password: 'password123', fullName: 'Admin' });
      const id = createAdmin.body.user.id;
      await prisma.user.update({ where: { id }, data: { role: 'ADMIN' } });
      adminUser = await prisma.user.findUnique({ where: { id } });
    }
    const login = await request(app).post('/api/v1/auth/login').send({
      email: adminUser!.email,
      password: adminUser!.email === 'adminv2@test.com' ? 'password123' : 'admin123',
    });
    expect(login.status).toBe(200);
    adminToken = login.body.accessToken;
  });

  afterAll(async () => {
    await cleanupLoyaltyV2();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany({ where: { email: 'v2redeem@example.com' } });
  });

  it('POST /loyalty/rewards/redeem with insufficient points returns 400', async () => {
    const res = await request(app)
      .post('/api/v1/loyalty/rewards/redeem')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ rewardId });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INSUFFICIENT_POINTS');
  });

  it('after earning points, redeem returns redemption with qrPayload and creates transaction', async () => {
    const account = await prisma.loyaltyAccount.findFirst({ where: { user: { email: 'v2redeem@example.com' } } });
    if (!account) throw new Error('No account');
    await prisma.loyaltyAccount.update({
      where: { id: account.id },
      data: { currentBalance: 300, lifetimeEarned: 300 },
    });

    const res = await request(app)
      .post('/api/v1/loyalty/rewards/redeem')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ rewardId });
    expect(res.status).toBe(200);
    expect(res.body.data.redemption).toBeDefined();
    expect(res.body.data.redemption.qrPayload).toMatch(/^BC\|v1\|V\|/);
    expect(res.body.data.redemption.qrExpiresAt).toBeDefined();
    expect(res.body.data.newBalance).toBeLessThan(300);
    const txCount = await prisma.loyaltyTransaction.count({
      where: { accountId: account.id, type: 'REDEEM' },
    });
    expect(txCount).toBeGreaterThanOrEqual(1);
  });

  it('POST /loyalty/redemptions/:id/qr returns voucher QR (fallback for Mes bons)', async () => {
    const redemptions = await request(app)
      .get('/api/v1/loyalty/redemptions')
      .set('Authorization', `Bearer ${userToken}`);
    const pending = redemptions.body.data.find((r: { status: string }) => r.status === 'PENDING');
    if (!pending) return;

    const res = await request(app)
      .post(`/api/v1/loyalty/redemptions/${pending.id}/qr`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.qrPayload).toMatch(/^BC\|v1\|V\|/);
  });

  it('GET /admin/salons returns list for admin', async () => {
    const res = await request(app).get('/api/v1/admin/salons').set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  it('POST /loyalty/rewards/redeem returns qrPayload immediately, balance reduced, transaction and redemption created', async () => {
    const account = await prisma.loyaltyAccount.findFirst({ where: { user: { email: 'v2redeem@example.com' } } });
    if (!account) throw new Error('No account');
    const beforeBalance = 300;
    await prisma.loyaltyAccount.update({
      where: { id: account.id },
      data: { currentBalance: beforeBalance, lifetimeEarned: beforeBalance },
    });

    const res = await request(app)
      .post('/api/v1/loyalty/rewards/redeem')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ rewardId });
    expect(res.status).toBe(200);
    expect(res.body.data.redemption).toBeDefined();
    expect(res.body.data.redemption.id).toBeDefined();
    expect(res.body.data.redemption.rewardName).toBeDefined();
    expect(res.body.data.redemption.pointsSpent).toBeGreaterThan(0);
    expect(res.body.data.redemption.status).toBe('PENDING');
    expect(res.body.data.redemption.qrPayload).toMatch(/^BC\|v1\|V\|/);
    expect(res.body.data.redemption.qrExpiresAt).toBeDefined();
    expect(res.body.data.newBalance).toBe(beforeBalance - res.body.data.redemption.pointsSpent);

    const txCount = await prisma.loyaltyTransaction.count({
      where: { accountId: account.id, type: 'REDEEM' },
    });
    expect(txCount).toBeGreaterThanOrEqual(1);
    const redemption = await prisma.loyaltyRedemptionVoucher.findFirst({
      where: { accountId: account.id },
      orderBy: { redeemedAt: 'desc' },
    });
    expect(redemption?.status).toBe('PENDING');
  });

  it('POST /admin/loyalty/redeem with valid voucher QR marks redemption USED', async () => {
    const account = await prisma.loyaltyAccount.findFirst({ where: { user: { email: 'v2redeem@example.com' } } });
    if (!account) throw new Error('No account');
    await prisma.loyaltyAccount.update({
      where: { id: account.id },
      data: { currentBalance: 300 },
    });
    const redeemRes = await request(app)
      .post('/api/v1/loyalty/rewards/redeem')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ rewardId });
    const qrPayload = redeemRes.body.data.redemption?.qrPayload;
    if (!qrPayload) throw new Error('Redeem must return redemption.qrPayload');

    const adminRes = await request(app)
      .post('/api/v1/admin/loyalty/redeem')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload });
    expect(adminRes.status).toBe(200);
    expect(adminRes.body.data.success).toBe(true);
    expect(adminRes.body.data.rewardName).toBeDefined();
    expect(typeof adminRes.body.data.newBalance).toBe('number');

    const redemptionId = redeemRes.body.data.redemption.id;
    const updated = await prisma.loyaltyRedemptionVoucher.findUnique({
      where: { id: redemptionId },
    });
    expect(updated?.status).toBe('USED');
  });

  it('POST /admin/loyalty/redeem with reused voucher QR returns 400 VOUCHER_ALREADY_USED', async () => {
    const account = await prisma.loyaltyAccount.findFirst({ where: { user: { email: 'v2redeem@example.com' } } });
    if (!account) throw new Error('No account');
    await prisma.loyaltyAccount.update({
      where: { id: account.id },
      data: { currentBalance: 500 },
    });
    const redeemRes = await request(app)
      .post('/api/v1/loyalty/rewards/redeem')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ rewardId });
    const qrPayload = redeemRes.body.data?.redemption?.qrPayload;
    if (!qrPayload) throw new Error('Redeem must return redemption.qrPayload');

    const first = await request(app)
      .post('/api/v1/admin/loyalty/redeem')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload });
    expect(first.status).toBe(200);

    const second = await request(app)
      .post('/api/v1/admin/loyalty/redeem')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload });
    expect(second.status).toBe(400);
    expect(second.body.error.code).toBe('VOUCHER_ALREADY_USED');
  });

  it('POST /admin/loyalty/redeem with wrong prefix returns 400', async () => {
    const res = await request(app)
      .post('/api/v1/admin/loyalty/redeem')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload: 'XX|v1|V|abcdefghij1234567890abcdefghij12' });
    expect(res.status).toBe(400);
    expect(['INVALID_QR', 'INVALID_OR_EXPIRED_QR']).toContain(res.body.error?.code);
  });

  it('POST /loyalty/redemptions/:id/qr for USED redemption returns 404', async () => {
    const account = await prisma.loyaltyAccount.findFirst({ where: { user: { email: 'v2redeem@example.com' } } });
    if (!account) throw new Error('No account');
    await prisma.loyaltyAccount.update({
      where: { id: account.id },
      data: { currentBalance: 300 },
    });
    const redeemRes = await request(app)
      .post('/api/v1/loyalty/rewards/redeem')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ rewardId });
    const redemptionId = redeemRes.body.data.redemption?.id;
    const qrPayload = redeemRes.body.data.redemption?.qrPayload;
    if (!redemptionId || !qrPayload) throw new Error('Redeem must return redemption');

    await request(app)
      .post('/api/v1/admin/loyalty/redeem')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload });
    const qrRes = await request(app)
      .post(`/api/v1/loyalty/redemptions/${redemptionId}/qr`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(qrRes.status).toBe(404);
  });
});
