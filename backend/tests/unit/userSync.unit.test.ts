jest.mock('../../src/db/client', () => ({
  __esModule: true,
  default: {
    user: { findMany: jest.fn(), findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn(), create: jest.fn() },
    userSyncLink: { findMany: jest.fn(), findFirst: jest.fn(), upsert: jest.fn() },
    $transaction: jest.fn(),
  },
}));
jest.mock('../../src/db/websiteClient', () => ({ getWebsiteClient: jest.fn() }));
jest.mock('../../src/utils/logger', () => ({ logger: {
  info: jest.fn(), warn: jest.fn(), error: jest.fn(),
} }));

import prisma from '../../src/db/client';
import { getWebsiteClient } from '../../src/db/websiteClient';
import { runUserSyncOnce } from '../../src/jobs/userSync';

const app = {
  id: 'app', email: 'a@example.test', phoneNumber: '+33600000000', fullName: 'Test Client',
  passwordHash: '$2b$10$hash', websitePasswordHash: '$2b$10$hash', isActive: true, createdAt: new Date('2026-01-01Z'),
};
const client = {
  id: 'web', email: app.email, phone: app.phoneNumber, first_name: 'Test', last_name: 'Client',
  password_hash: app.passwordHash, has_account: true, deleted_at: null, created_at: app.createdAt,
};
const link = { appUserId: app.id, websiteClientId: client.id, appSnapshot: null, websiteSnapshot: null, lastSyncedFrom: null };
const website = { $queryRaw: jest.fn(), $executeRaw: jest.fn() };
const tx = { userSyncLink: { findMany: jest.fn(), upsert: jest.fn() } };

beforeEach(() => {
  jest.resetAllMocks();
  (getWebsiteClient as jest.Mock).mockReturnValue(website);
  (prisma.user.findMany as jest.Mock).mockResolvedValue([app]);
  (prisma.user.findFirst as jest.Mock).mockResolvedValue(null);
  (prisma.user.findUnique as jest.Mock).mockResolvedValue(null);
  (prisma.userSyncLink.findMany as jest.Mock).mockResolvedValue([link]);
  (prisma.$transaction as jest.Mock).mockImplementation((callback) => callback(tx));
  tx.userSyncLink.findMany.mockResolvedValue([link]);
  website.$queryRaw.mockImplementation(async (query) => query.sql.includes('WHERE') ? [] : [client]);
});

test('an existing valid pair stays linked to its current website customer', async () => {
  await runUserSyncOnce();
  expect(prisma.user.update).toHaveBeenCalledTimes(1);
  expect(website.$executeRaw).toHaveBeenCalledTimes(1);
  expect(prisma.userSyncLink.upsert).toHaveBeenCalledWith(expect.objectContaining({
    where: { appUserId: app.id }, update: expect.objectContaining({ websiteClientId: client.id }),
  }));
});

test('a conflicting website identity blocks profile/password copying before either customer update', async () => {
  website.$queryRaw.mockImplementation(async (query) => query.sql.includes('WHERE') ? [{ ...client, id: 'conflict' }] : [client]);
  await runUserSyncOnce();
  expect(prisma.user.update).not.toHaveBeenCalled();
  expect(website.$executeRaw).not.toHaveBeenCalled();
  expect(prisma.userSyncLink.upsert).not.toHaveBeenCalled();
});

test('an unlinked app customer cannot reuse a website customer owned by another app account', async () => {
  (prisma.user.findMany as jest.Mock).mockResolvedValue([{ ...app, id: 'other-app' }]);
  (prisma.userSyncLink.findMany as jest.Mock).mockResolvedValue([]);
  website.$queryRaw.mockImplementation(async (query) => {
    if (!query.sql.includes('WHERE')) return [client];
    return query.sql.includes('id <>') ? [] : [client];
  });
  await runUserSyncOnce();
  expect(prisma.user.update).not.toHaveBeenCalled();
  expect(prisma.user.create).not.toHaveBeenCalled();
  expect(website.$executeRaw).not.toHaveBeenCalled();
  expect(prisma.userSyncLink.upsert).not.toHaveBeenCalled();
  expect(tx.userSyncLink.upsert).not.toHaveBeenCalled();
});
