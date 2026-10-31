jest.mock('../../src/db/client', () => ({
  __esModule: true,
  default: {
    user: { findUnique: jest.fn() },
    userSyncLink: { findUnique: jest.fn(), upsert: jest.fn() },
  },
}));
jest.mock('../../src/db/websiteClient', () => ({ getWebsiteClient: jest.fn() }));
jest.mock('../../src/modules/auth/syncGuards', () => ({
  ...jest.requireActual('../../src/modules/auth/syncGuards'),
  claimSyncLink: jest.fn(), assertUnclaimedSyncIdentity: jest.fn(),
}));

import prisma from '../../src/db/client';
import { getWebsiteClient } from '../../src/db/websiteClient';
import { claimSyncLink, UserSyncConflict } from '../../src/modules/auth/syncGuards';
import { syncAppUserToWebsiteNow } from '../../src/modules/auth/websiteSync';

const website = { $queryRaw: jest.fn(), $executeRaw: jest.fn() };
const client = { id: 'web', password_hash: '$2b$10$existing', has_account: true };

beforeEach(() => {
  jest.resetAllMocks();
  (getWebsiteClient as jest.Mock).mockReturnValue(website);
  (prisma.user.findUnique as jest.Mock).mockResolvedValue({
    id: 'app', email: 'a@example.test', phoneNumber: '+33600000000', fullName: 'Test Client',
    passwordHash: 'unused', websitePasswordHash: '$2b$10$website', isActive: true,
  });
  (prisma.userSyncLink.findUnique as jest.Mock).mockResolvedValue({ websiteClientId: 'web' });
  website.$queryRaw.mockResolvedValue([]);
});

test('a missing linked website client is never replaced automatically', async () => {
  await expect(syncAppUserToWebsiteNow('app')).rejects.toThrow(UserSyncConflict);
  expect(website.$executeRaw).not.toHaveBeenCalled();
  expect(prisma.userSyncLink.upsert).not.toHaveBeenCalled();
});

test('split email and phone matches cannot receive a password update', async () => {
  (prisma.userSyncLink.findUnique as jest.Mock).mockResolvedValue(null);
  website.$queryRaw.mockResolvedValueOnce([client]).mockResolvedValueOnce([{ ...client, id: 'other' }]);
  await expect(syncAppUserToWebsiteNow('app')).rejects.toThrow(UserSyncConflict);
  expect(website.$executeRaw).not.toHaveBeenCalled();
  expect(claimSyncLink).not.toHaveBeenCalled();
});

test('a conflicting profile is rejected before either account is written', async () => {
  website.$queryRaw.mockResolvedValueOnce([client]).mockResolvedValueOnce([{ ...client, id: 'other' }]);
  await expect(syncAppUserToWebsiteNow('app')).rejects.toThrow(UserSyncConflict);
  expect(website.$executeRaw).not.toHaveBeenCalled();
  expect(prisma.userSyncLink.upsert).not.toHaveBeenCalled();
});

test('link ownership must be reserved before the website update', async () => {
  website.$queryRaw.mockResolvedValueOnce([client]);
  (claimSyncLink as jest.Mock).mockRejectedValueOnce(new UserSyncConflict('already owned'));
  await expect(syncAppUserToWebsiteNow('app')).rejects.toThrow(UserSyncConflict);
  expect(website.$executeRaw).not.toHaveBeenCalled();
});

test('a valid existing pair updates the website after its link is checked', async () => {
  website.$queryRaw.mockResolvedValueOnce([client]);
  await expect(syncAppUserToWebsiteNow('app')).resolves.toBe('web');
  expect(website.$executeRaw).toHaveBeenCalledTimes(1);
  expect((claimSyncLink as jest.Mock).mock.invocationCallOrder[0])
    .toBeLessThan(website.$executeRaw.mock.invocationCallOrder[0]);
});
