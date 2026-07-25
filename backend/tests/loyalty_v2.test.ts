/**
 * Loyalty v2 tests: points-as-currency, earn flow, redeem flow, appointment ranks.
 */

const TEST_ADMIN_SECRET = 'test-admin-secret-12345678901234567890';
const ORIGINAL_ADMIN_SECRET = process.env.ADMIN_SECRET;
process.env.ADMIN_SECRET = TEST_ADMIN_SECRET;

import request from 'supertest';
import nock from 'nock';
import { createApp } from '../src/app';
import prisma from '../src/db/client';
import { getNextRank, getRankFromAppointments } from '../src/modules/loyalty_v2/tiers';
import { PRIVATE_CLUB_REWARDS } from '../src/modules/loyalty_v2/rewards';
import { awardPointsForCompletedBooking } from '../src/modules/loyalty_v2/bookingRewards';

beforeAll(async () => {
  await prisma.$connect();
  await ensurePrivateClubRewards();
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
  await prisma.websiteBookingLoyaltyGrant.deleteMany();
  await prisma.loyaltyTransaction.deleteMany();
  await prisma.loyaltyRedemptionVoucher.deleteMany();
  await prisma.loyaltyAccountQrToken.deleteMany();
  await prisma.loyaltyAccount.deleteMany();
}

async function ensurePrivateClubRewards() {
  await prisma.loyaltyReward.updateMany({
    where: { slug: null, isActive: true },
    data: { isActive: false },
  });

  await Promise.all(
    PRIVATE_CLUB_REWARDS.map((reward) =>
      prisma.loyaltyReward.upsert({
        where: { slug: reward.slug },
        create: {
          slug: reward.slug,
          name: reward.name,
          costPoints: reward.costPoints,
          description: reward.description,
          imageUrl: reward.imageUrl,
          isActive: true,
          sortOrder: reward.sortOrder,
        },
        update: {
          name: reward.name,
          costPoints: reward.costPoints,
          description: reward.description,
          imageUrl: reward.imageUrl,
          isActive: true,
          sortOrder: reward.sortOrder,
        },
      })
    )
  );
}

const app = createApp();

describe('Loyalty v2 appointment rank logic', () => {
  it('returns Bronze on registration before 10 appointments', () => {
    expect(getRankFromAppointments(0)).toBe('Bronze');
    expect(getRankFromAppointments(9)).toBe('Bronze');
  });
  it('returns Silver from 10 appointments', () => {
    expect(getRankFromAppointments(10)).toBe('Silver');
    expect(getRankFromAppointments(19)).toBe('Silver');
  });
  it('returns Gold from 20 appointments', () => {
    expect(getRankFromAppointments(20)).toBe('Gold');
    expect(getRankFromAppointments(29)).toBe('Gold');
  });
  it('returns Diamond from 30 appointments', () => {
    expect(getRankFromAppointments(30)).toBe('Diamond');
    expect(getRankFromAppointments(49)).toBe('Diamond');
  });
  it('returns Platinum from 50 appointments', () => {
    expect(getRankFromAppointments(50)).toBe('Platinum');
    expect(getRankFromAppointments(5000)).toBe('Platinum');
  });
  it('getNextRank returns next rank and remaining appointments', () => {
    const next = getNextRank(4);
    expect(next?.name).toBe('Silver');
    expect(next?.remainingAppointments).toBe(6);
    const next29 = getNextRank(29);
    expect(next29?.name).toBe('Diamond');
    expect(next29?.remainingAppointments).toBe(1);
    expect(getNextRank(50)).toBeNull();
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
    expect(res.body.data.lifetimeAppointments).toBe(0);
    expect(res.body.data.tier).toBe('Bronze');
    expect(res.body.data.rank).toBe('Bronze');
    expect(res.body.data.nextRank).toMatchObject({
      name: 'Silver',
      requiredAppointments: 10,
      remainingAppointments: 10,
    });
    expect(res.body.data.rankScale).toHaveLength(5);
    expect(res.body.data.themeVariables).toMatchObject({
      '--accent': '#E4975A',
      '--accent-2': '#C4753A',
      '--glow': 'rgba(228,151,90,.50)',
      '--ink': '#2A1808',
    });
    expect(res.body.data.memberPosition).toEqual({
      label: 'You \u00B7 0 pts',
      points: 0,
    });
    expect(res.body.data.rewardMilestones.map((reward: { costPoints: number }) => reward.costPoints)).toEqual([
      75,
      150,
      250,
      300,
    ]);
    expect(res.body.data.rewardMilestones[0]).toMatchObject({
      slug: 'product_30_percent',
      isReached: false,
      canRedeem: false,
      isLocked: true,
      pointsRemaining: 75,
      remainingLabel: '75 pts remaining',
      positionLabel: 'You \u00B7 0 pts',
    });
    expect(res.body.data.pointsRule).toEqual({
      spendAmount: 1,
      spendCurrency: 'EUR',
      pointsEarned: 1,
    });
    expect(res.body.data.enrolledAt).toBeDefined();
  });

  it('GET /loyalty/private-club exposes the same aggregate contract', async () => {
    const res = await request(app).get('/api/v1/loyalty/private-club').set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.member.memberCode).toMatch(/^BC-[A-F0-9]{8}$/);
    expect(res.body.data.rankScale.map((rank: { name: string }) => rank.name)).toEqual([
      'Bronze',
      'Silver',
      'Gold',
      'Diamond',
      'Platinum',
    ]);
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
    expect(earnRes.body.data.newLifetimeAppointments).toBe(1);
    expect(earnRes.body.data.newTier).toBe('Bronze');
    expect(earnRes.body.data.newRank).toBe('Bronze');
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

describe('Loyalty v2 completed booking awards', () => {
  let appUserId: string;

  beforeAll(async () => {
    await cleanupLoyaltyV2();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany({ where: { email: 'bookingaward@example.com' } });

    const reg = await request(app).post('/api/v1/auth/register').send({
      email: 'bookingaward@example.com',
      phoneNumber: '+12025550109',
      password: 'password123',
      fullName: 'Booking Award',
    });
    if (reg.status !== 201) {
      throw new Error(`Register failed: ${JSON.stringify(reg.body)}`);
    }
    appUserId = reg.body.user.id;
  });

  afterAll(async () => {
    await cleanupLoyaltyV2();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany({ where: { email: 'bookingaward@example.com' } });
  });

  it('awards spendable points and one appointment for a paid completed booking', async () => {
    const result = await awardPointsForCompletedBooking({
      appUserId,
      websiteBookingId: 'website-booking-paid-1',
      websiteClientId: 'website-client-1',
      serviceName: 'Paid Cut',
      bookingPrice: 2500,
    });

    expect(result).toMatchObject({
      pointsEarned: 25,
      newBalance: 25,
      newLifetime: 25,
      newLifetimeAppointments: 1,
      newTier: 'Bronze',
      newRank: 'Bronze',
    });

    const account = await prisma.loyaltyAccount.findUnique({ where: { userId: appUserId } });
    expect(account?.currentBalance).toBe(25);
    expect(account?.lifetimeEarned).toBe(25);
    expect(account?.lifetimeAppointments).toBe(1);

    const transaction = await prisma.loyaltyTransaction.findFirst({
      where: { accountId: account!.id, referenceId: 'website-booking-paid-1' },
    });
    expect(transaction?.points).toBe(25);
    expect(transaction?.appointmentCount).toBe(1);
  });

  it('counts a zero-point completed booking toward rank without adding points', async () => {
    const result = await awardPointsForCompletedBooking({
      appUserId,
      websiteBookingId: 'website-booking-zero-1',
      websiteClientId: 'website-client-1',
      serviceName: 'Comped Cut',
      bookingPrice: 0,
    });

    expect(result).toMatchObject({
      pointsEarned: 0,
      newBalance: 25,
      newLifetime: 25,
      newLifetimeAppointments: 2,
      newTier: 'Bronze',
      newRank: 'Bronze',
    });

    const grant = await prisma.websiteBookingLoyaltyGrant.findUnique({
      where: { websiteBookingId: 'website-booking-zero-1' },
    });
    expect(grant?.pointsAwarded).toBe(0);
    expect(grant?.appointmentsAwarded).toBe(1);
  });

  it('does not double-count the same website booking', async () => {
    const duplicate = await awardPointsForCompletedBooking({
      appUserId,
      websiteBookingId: 'website-booking-paid-1',
      websiteClientId: 'website-client-1',
      serviceName: 'Paid Cut',
      bookingPrice: 2500,
    });

    expect(duplicate).toBeNull();

    const account = await prisma.loyaltyAccount.findUnique({ where: { userId: appUserId } });
    expect(account?.currentBalance).toBe(25);
    expect(account?.lifetimeEarned).toBe(25);
    expect(account?.lifetimeAppointments).toBe(2);
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
    expect(res.body.data.redemptionId).toBeDefined();
    expect(res.body.data.qrPayload).toMatch(/^BC\|v1\|V\|/);
    expect(res.body.data.rewardName).toBeDefined();
    expect(res.body.data.newBalance).toBeDefined();
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
    expect(res.body.data.redemptionId).toBeDefined();
    expect(res.body.data.rewardName).toBeDefined();
    expect(res.body.data.qrPayload).toMatch(/^BC\|v1\|V\|/);
    expect(res.body.data.newBalance).toBeLessThanOrEqual(beforeBalance);

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
    const qrPayload = redeemRes.body.data?.qrPayload;
    if (!qrPayload) throw new Error('Redeem must return qrPayload');

    const adminRes = await request(app)
      .post('/api/v1/admin/loyalty/redeem')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ qrPayload });
    expect(adminRes.status).toBe(200);
    expect(adminRes.body.data.success).toBe(true);
    expect(adminRes.body.data.rewardName).toBeDefined();
    expect(typeof adminRes.body.data.newBalance).toBe('number');

    const redemptionId = redeemRes.body.data.redemptionId;
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
    const qrPayload = redeemRes.body.data?.qrPayload;
    if (!qrPayload) throw new Error('Redeem must return qrPayload');

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
    const redemptionId = redeemRes.body.data?.redemptionId;
    const qrPayload = redeemRes.body.data?.qrPayload;
    if (!redemptionId || !qrPayload) throw new Error('Redeem must return redemptionId and qrPayload');

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
