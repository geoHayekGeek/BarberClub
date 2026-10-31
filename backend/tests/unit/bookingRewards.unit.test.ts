jest.mock('../../src/db/client', () => ({
  __esModule: true,
  default: {
    websiteBookingLoyaltyGrant: { findMany: jest.fn() },
    user: { findUnique: jest.fn() },
    $transaction: jest.fn(),
  },
}));
jest.mock('../../src/db/websiteClient', () => ({ getWebsiteClient: jest.fn() }));
jest.mock('../../src/config/firebase', () => ({ getMessaging: jest.fn() }));
jest.mock('../../src/utils/logger', () => ({ logger: {
  info: jest.fn(), debug: jest.fn(), warn: jest.fn(), error: jest.fn(),
} }));

import prisma from '../../src/db/client';
import { getWebsiteClient } from '../../src/db/websiteClient';
import { logger } from '../../src/utils/logger';
import { isBookingEligibleForAppLoyalty, runBookingLoyaltyRewardSync } from '../../src/modules/loyalty_v2/bookingRewards';

const website = { $queryRaw: jest.fn() };

beforeEach(() => {
  jest.resetAllMocks();
  (getWebsiteClient as jest.Mock).mockReturnValue(website);
  (prisma.websiteBookingLoyaltyGrant.findMany as jest.Mock).mockResolvedValue([]);
  website.$queryRaw.mockResolvedValueOnce(Array.from({ length: 100 }, (_, i) => ({
    id: `booking-${i}`, client_id: 'client', price: 20, service_name: 'Coupe',
    created_at: new Date('2026-01-01Z'), date: new Date('2026-01-02Z'),
  }))).mockResolvedValueOnce([{
    id: 'client', phone: '+33600000000', email: 'a@example.test',
  }]);
});

test('past appointments retain the enrollment rule without flooding info logs or repeated user reads', async () => {
  (prisma.user.findUnique as jest.Mock).mockResolvedValue({ id: 'app', appFirstLoginAt: new Date('2026-10-01Z') });
  await runBookingLoyaltyRewardSync();
  expect(prisma.user.findUnique).toHaveBeenCalledTimes(1);
  expect(prisma.$transaction).not.toHaveBeenCalled();
  expect(logger.info).toHaveBeenCalledTimes(1);
  expect(logger.info).toHaveBeenCalledWith('Booking loyalty reward sync completed', expect.objectContaining({
    completedBookings: 100, skippedBeforeEnrollment: 100, rewarded: 0,
  }));
});

test('missing app accounts are also cached for the duration of the run', async () => {
  (prisma.user.findUnique as jest.Mock).mockResolvedValue(null);
  await runBookingLoyaltyRewardSync();
  // One phone lookup and one email lookup for the client, not two per booking.
  expect(prisma.user.findUnique).toHaveBeenCalledTimes(2);
  expect(prisma.$transaction).not.toHaveBeenCalled();
  expect(logger.info).toHaveBeenCalledWith('Booking loyalty reward sync completed', expect.objectContaining({
    pendingAppUser: 100, rewarded: 0,
  }));
});

test('enrollment eligibility remains unchanged at its exact boundary', () => {
  const enrollment = new Date('2026-10-01Z');
  expect(isBookingEligibleForAppLoyalty(new Date(enrollment.getTime() - 1), enrollment)).toBe(false);
  expect(isBookingEligibleForAppLoyalty(enrollment, enrollment)).toBe(true);
  expect(isBookingEligibleForAppLoyalty(enrollment, null)).toBe(false);
});
