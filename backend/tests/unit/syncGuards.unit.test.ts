jest.mock('../../src/db/client', () => ({
  __esModule: true,
  default: {
    user: { findFirst: jest.fn() },
    userSyncLink: { findFirst: jest.fn() },
    $transaction: jest.fn(),
  },
}));

import { Prisma } from '@prisma/client';
import prisma from '../../src/db/client';
import {
  assertAppProfileAvailable, assertMatchingTargets, assertUnclaimedSyncIdentity,
  claimSyncLink, UserSyncConflict,
} from '../../src/modules/auth/syncGuards';

const tx = { userSyncLink: { findMany: jest.fn(), upsert: jest.fn() } };
const transaction = prisma.$transaction as jest.Mock;

beforeEach(() => {
  jest.resetAllMocks();
  tx.userSyncLink.findMany.mockResolvedValue([]);
  transaction.mockImplementation((callback) => callback(tx));
});

test('phone and email must not identify different accounts', () => {
  expect(() => assertMatchingTargets('one', 'two')).toThrow(UserSyncConflict);
  expect(() => assertMatchingTargets('one', 'one')).not.toThrow();
  expect(() => assertMatchingTargets(null, 'one')).not.toThrow();
});

test('profile uniqueness is checked before copying fields', async () => {
  (prisma.user.findFirst as jest.Mock).mockResolvedValue({ id: 'another' });
  await expect(assertAppProfileAvailable('app', { email: 'a@example.test', phone: '+33600000000' }))
    .rejects.toThrow(UserSyncConflict);
  expect(prisma.user.findFirst).toHaveBeenCalledWith(expect.objectContaining({
    where: expect.objectContaining({ id: { not: 'app' } }),
  }));
});

test('new customer creation is blocked if its identity is already linked', async () => {
  (prisma.userSyncLink.findFirst as jest.Mock).mockResolvedValue({ id: 'owned' });
  await expect(assertUnclaimedSyncIdentity({ appUserId: 'app' })).rejects.toThrow(UserSyncConflict);
  await expect(assertUnclaimedSyncIdentity({ websiteClientId: 'web' })).rejects.toThrow(UserSyncConflict);
});

test('an unclaimed identity can proceed', async () => {
  (prisma.userSyncLink.findFirst as jest.Mock).mockResolvedValue(null);
  await expect(assertUnclaimedSyncIdentity({ appUserId: 'app' })).resolves.toBeUndefined();
});

test('new pairs are claimed in a serializable transaction', async () => {
  await claimSyncLink('app', 'web');
  expect(transaction).toHaveBeenCalledWith(expect.any(Function), {
    isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
  });
  expect(tx.userSyncLink.upsert).toHaveBeenCalledWith({
    where: { appUserId: 'app' }, create: { appUserId: 'app', websiteClientId: 'web' },
    update: { websiteClientId: 'web' },
  });
});

test('an existing pair is idempotent', async () => {
  tx.userSyncLink.findMany.mockResolvedValue([{ appUserId: 'app', websiteClientId: 'web' }]);
  await claimSyncLink('app', 'web');
  expect(tx.userSyncLink.upsert).not.toHaveBeenCalled();
});

test.each([
  [{ appUserId: 'other', websiteClientId: 'web' }],
  [{ appUserId: 'app', websiteClientId: 'other' }],
])('never reassign an already owned identity: %j', async (link) => {
  tx.userSyncLink.findMany.mockResolvedValue([link]);
  await expect(claimSyncLink('app', 'web')).rejects.toThrow(UserSyncConflict);
  expect(tx.userSyncLink.upsert).not.toHaveBeenCalled();
});

test('a serialization conflict is retried once', async () => {
  transaction.mockRejectedValueOnce(new Prisma.PrismaClientKnownRequestError('retry', {
    code: 'P2034', clientVersion: 'test',
  }));
  await claimSyncLink('app', 'web');
  expect(transaction).toHaveBeenCalledTimes(2);
});

test('a concurrent unique claim is a safe conflict, not a relink', async () => {
  transaction.mockRejectedValueOnce(new Prisma.PrismaClientKnownRequestError('claimed', {
    code: 'P2002', clientVersion: 'test',
  }));
  await expect(claimSyncLink('app', 'web')).rejects.toThrow(UserSyncConflict);
  expect(transaction).toHaveBeenCalledTimes(1);
});
