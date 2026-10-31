import { Prisma } from '@prisma/client';
import prisma from '../../db/client';

/** Conflicting identities need review, never an automatic merge or relink. */
export class UserSyncConflict extends Error {
  constructor(reason: string) {
    super(`User sync skipped: ${reason}`);
    this.name = 'UserSyncConflict';
  }
}

export function assertMatchingTargets(phoneId?: string | null, emailId?: string | null): void {
  if (phoneId && emailId && phoneId !== emailId) {
    throw new UserSyncConflict('email and phone identify different accounts');
  }
}

export async function assertAppProfileAvailable(
  appUserId: string,
  profile: { email: string; phone: string },
): Promise<void> {
  const identity: Prisma.UserWhereInput[] = [];
  if (profile.email) identity.push({ email: { equals: profile.email, mode: 'insensitive' } });
  if (profile.phone) identity.push({ phoneNumber: profile.phone });
  if (identity.length === 0) return;
  const conflict = await prisma.user.findFirst({
    where: { id: { not: appUserId }, OR: identity }, select: { id: true },
  });
  if (conflict) throw new UserSyncConflict('profile identity belongs to another app user');
}

export async function assertUnclaimedSyncIdentity(identity: {
  appUserId?: string; websiteClientId?: string;
}): Promise<void> {
  const conflict = await prisma.userSyncLink.findFirst({
    where: {
      ...identity,
      websiteClientId: identity.websiteClientId ?? { not: null },
    },
    select: { id: true },
  });
  if (conflict) throw new UserSyncConflict('identity already has a sync link');
}

/** Reserve the one-to-one pair BEFORE writing either customer's profile.
 * Serializable isolation plus database unique indexes prevent two workers
 * from claiming the same website identity. Existing ownership is immutable.
 */
export async function claimSyncLink(appUserId: string, websiteClientId: string): Promise<void> {
  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      await prisma.$transaction(async (tx) => {
        const links = await tx.userSyncLink.findMany({
          where: { OR: [{ appUserId }, { websiteClientId }] },
          select: { appUserId: true, websiteClientId: true },
        });
        if (links.some((link) => link.websiteClientId === websiteClientId && link.appUserId !== appUserId)) {
          throw new UserSyncConflict('website client belongs to another app user');
        }
        if (links.some((link) => link.appUserId === appUserId && link.websiteClientId && link.websiteClientId !== websiteClientId)) {
          throw new UserSyncConflict('app user is already linked to another website client');
        }
        if (links.some((link) => link.appUserId === appUserId && link.websiteClientId === websiteClientId)) return;
        await tx.userSyncLink.upsert({
          where: { appUserId }, create: { appUserId, websiteClientId }, update: { websiteClientId },
        });
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      return;
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2034' && attempt === 0) continue;
        if (error.code === 'P2002') throw new UserSyncConflict('identity was claimed concurrently');
      }
      throw error;
    }
  }
}
