/**
 * Award loyalty points automatically from completed website bookings.
 */

import { Prisma } from '@prisma/client';
import prisma from '../../db/client';
import { getWebsiteClient } from '../../db/websiteClient';
import { getMessaging } from '../../config/firebase';
import { logger } from '../../utils/logger';
import { pointsFromPrice } from './points';
import { getCheapestRewardCost, getTierFromLifetime, type LoyaltyTierName } from './tiers';

const NEAR_REWARD_THRESHOLD = 20;

export interface CompletedWebsiteBookingRow {
  id: string;
  client_id: string | null;
  price: number;
  service_name: string | null;
}

export interface CompletedBookingRewardInput {
  appUserId: string;
  websiteBookingId: string;
  websiteClientId: string;
  serviceName: string;
  bookingPrice: number;
}

export interface CompletedBookingRewardResult {
  pointsEarned: number;
  newBalance: number;
  newLifetime: number;
  newTier: LoyaltyTierName;
}

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function chunkArray<T>(values: T[], size: number): T[][] {
  if (size <= 0) {
    return [values];
  }

  const chunks: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }

  return chunks;
}

function buildWebsiteBookingQuery(params?: { fromDate?: string; toDate?: string }): Prisma.Sql {
  const filters: Prisma.Sql[] = [
    Prisma.sql`b.status = 'completed'`,
    Prisma.sql`b.deleted_at IS NULL`,
    Prisma.sql`b.price > 0`,
  ];

  if (params?.fromDate) {
    filters.push(Prisma.sql`b.date >= CAST(${params.fromDate} AS DATE)`);
  }

  if (params?.toDate) {
    filters.push(Prisma.sql`b.date <= CAST(${params.toDate} AS DATE)`);
  }

  return Prisma.sql`
    SELECT
      b.id,
      b.client_id,
      b.price,
      COALESCE(s.name, 'Reservation') AS service_name
    FROM bookings b
    LEFT JOIN services s ON s.id = b.service_id
    WHERE ${Prisma.join(filters, ' AND ')}
    ORDER BY b.created_at ASC
  `;
}

async function sendEarnNotifications(params: {
  accountId: string;
  pointsEarned: number;
  previousTier: LoyaltyTierName;
  currentBalance: number;
  lifetimeEarned: number;
  user: { fcmToken: string | null; fullName: string | null; email: string | null } | null;
  sourceLabel: string;
}): Promise<LoyaltyTierName> {
  const newTier = getTierFromLifetime(params.lifetimeEarned);
  const token = params.user?.fcmToken;

  if (!token) {
    return newTier;
  }

  try {
    const messaging = getMessaging();
    if (!messaging) {
      logger.warn('Firebase messaging not initialized; skipping booking loyalty push');
      return newTier;
    }

    await messaging.send({
      token,
      notification: {
        title: 'Points fidelite',
        body: `+${params.pointsEarned} points pour ${params.sourceLabel}. Solde: ${params.currentBalance} pts`,
      },
      data: {
        type: 'LOYALTY_EARN',
        pointsEarned: String(params.pointsEarned),
        newBalance: String(params.currentBalance),
      },
    });

    if (newTier !== params.previousTier) {
      await messaging.send({
        token,
        notification: {
          title: 'Nouveau statut',
          body: `Vous etes passe ${newTier}`,
        },
        data: { type: 'LOYALTY_TIER', tier: newTier },
      });
    }

    const rewards = await prisma.loyaltyReward.findMany({
      where: { isActive: true },
      select: { costPoints: true },
    });
    const cheapest = getCheapestRewardCost(rewards);
    if (cheapest != null) {
      const gap = cheapest - params.currentBalance;
      if (gap > 0 && gap <= NEAR_REWARD_THRESHOLD) {
        await messaging.send({
          token,
          notification: {
            title: 'Bientot une recompense',
            body: `Plus que ${gap} points pour une recompense`,
          },
          data: { type: 'LOYALTY_NEAR_REWARD' },
        });
      }
    }
  } catch (error) {
    logger.warn('FCM push failed LOYALTY_EARN', {
      accountId: params.accountId,
      error: error instanceof Error ? error.message : error,
    });
  }

  return newTier;
}

export async function awardPointsForCompletedBooking(
  input: CompletedBookingRewardInput
): Promise<CompletedBookingRewardResult | null> {
  const pointsEarned = pointsFromPrice(input.bookingPrice);
  if (pointsEarned <= 0) {
    logger.info('LOYALTY_BOOKING skipped_zero_points', {
      websiteBookingId: input.websiteBookingId,
      bookingPrice: input.bookingPrice,
    });
    return null;
  }

  const previousAccount = await prisma.loyaltyAccount.findUnique({
    where: { userId: input.appUserId },
    select: { lifetimeEarned: true },
  });
  const previousTier = getTierFromLifetime(previousAccount?.lifetimeEarned ?? 0);

  try {
    const result = await prisma.$transaction(async (tx) => {
      const account = await tx.loyaltyAccount.upsert({
        where: { userId: input.appUserId },
        create: { userId: input.appUserId },
        update: {},
        select: {
          id: true,
          currentBalance: true,
          lifetimeEarned: true,
          user: {
            select: {
              fcmToken: true,
              fullName: true,
              email: true,
            },
          },
        },
      });

      await tx.websiteBookingLoyaltyGrant.create({
        data: {
          websiteBookingId: input.websiteBookingId,
          websiteClientId: input.websiteClientId,
          appUserId: input.appUserId,
          loyaltyAccountId: account.id,
          serviceName: input.serviceName,
          bookingPrice: input.bookingPrice,
          pointsAwarded: pointsEarned,
        },
      });

      const updatedAccount = await tx.loyaltyAccount.update({
        where: { id: account.id },
        data: {
          currentBalance: { increment: pointsEarned },
          lifetimeEarned: { increment: pointsEarned },
        },
        select: { currentBalance: true, lifetimeEarned: true },
      });

      await tx.loyaltyTransaction.create({
        data: {
          accountId: account.id,
          type: 'EARN',
          points: pointsEarned,
          description: input.serviceName,
          referenceId: input.websiteBookingId,
        },
      });

      return {
        accountId: account.id,
        user: account.user,
        currentBalance: updatedAccount.currentBalance,
        lifetimeEarned: updatedAccount.lifetimeEarned,
      };
    });

    const newTier = await sendEarnNotifications({
      accountId: result.accountId,
      pointsEarned,
      previousTier,
      currentBalance: result.currentBalance,
      lifetimeEarned: result.lifetimeEarned,
      user: result.user,
      sourceLabel: input.serviceName,
    });

    return {
      pointsEarned,
      newBalance: result.currentBalance,
      newLifetime: result.lifetimeEarned,
      newTier,
    };
  } catch (error) {
    if (isUniqueViolation(error)) {
      logger.info('LOYALTY_BOOKING already_rewarded', {
        websiteBookingId: input.websiteBookingId,
        websiteClientId: input.websiteClientId,
      });
      return null;
    }

    throw error;
  }
}

export async function runBookingLoyaltyRewardSync(params?: {
  fromDate?: string;
  toDate?: string;
}): Promise<void> {
  const websiteClient = getWebsiteClient();
  if (!websiteClient) {
    logger.info('Booking loyalty reward job disabled - WEBSITE_DATABASE_URL not configured');
    return;
  }

  const query = buildWebsiteBookingQuery(params);
  const [bookings, rewardedRows] = await Promise.all([
    websiteClient.$queryRaw<CompletedWebsiteBookingRow[]>(query),
    prisma.websiteBookingLoyaltyGrant.findMany({
      select: { websiteBookingId: true },
    }),
  ]);

  const rewardedBookingIds = new Set(rewardedRows.map((row) => row.websiteBookingId));
  const clientIds = [...new Set(bookings.map((row) => row.client_id).filter(isNonEmptyString))];

  const links = clientIds.length > 0
    ? (await Promise.all(
        chunkArray(clientIds, 500).map((chunk) =>
          prisma.userSyncLink.findMany({
            where: { websiteClientId: { in: chunk } },
            select: {
              websiteClientId: true,
              appUserId: true,
              user: {
                select: {
                  id: true,
                  fcmToken: true,
                  fullName: true,
                  email: true,
                },
              },
            },
          })
        )
      )).flat()
    : [];

  const linkByClientId = new Map(links.map((link) => [link.websiteClientId, link]));

  let rewarded = 0;
  let pendingLink = 0;
  let alreadyRewarded = 0;
  let skippedNoPoints = 0;

  for (const booking of bookings) {
    if (!isNonEmptyString(booking.client_id)) {
      pendingLink += 1;
      logger.warn('Booking loyalty sync skipped invalid website client id', {
        websiteBookingId: booking.id,
        clientId: booking.client_id,
      });
      continue;
    }

    if (rewardedBookingIds.has(booking.id)) {
      alreadyRewarded += 1;
      continue;
    }

    const link = linkByClientId.get(booking.client_id);
    if (!link) {
      pendingLink += 1;
      continue;
    }

    const result = await awardPointsForCompletedBooking({
      appUserId: link.appUserId,
      websiteBookingId: booking.id,
      websiteClientId: booking.client_id,
      serviceName: booking.service_name?.trim() || 'Reservation',
      bookingPrice: booking.price,
    });

    if (result) {
      rewarded += 1;
    } else if (pointsFromPrice(booking.price) <= 0) {
      skippedNoPoints += 1;
    } else {
      alreadyRewarded += 1;
    }
  }

  logger.info('Booking loyalty reward sync completed', {
    completedBookings: bookings.length,
    rewarded,
    pendingLink,
    alreadyRewarded,
    skippedNoPoints,
  });
}
