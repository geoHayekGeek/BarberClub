/**
 * Award loyalty points and appointment rank progress from completed website bookings.
 */

import { Prisma } from '@prisma/client';
import prisma from '../../db/client';
import { getWebsiteClient } from '../../db/websiteClient';
import { getMessaging } from '../../config/firebase';
import { logger } from '../../utils/logger';
import { validatePhoneNumber } from '../auth/utils/phone';
import { pointsFromPrice } from './points';
import { getCheapestRewardCost, getRankFromAppointments, type LoyaltyTierName } from './tiers';

const NEAR_REWARD_THRESHOLD = 20;

export interface CompletedWebsiteBookingRow {
  id: string;
  client_id: string | null;
  price: number;
  service_name: string | null;
}

interface WebsiteClientRow {
  id: string;
  first_name: string;
  last_name: string;
  phone: string | null;
  email: string | null;
  password_hash: string | null;
  has_account: boolean | null;
  deleted_at: Date | null;
  created_at: Date;
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
  newLifetimeAppointments: number;
  newTier: LoyaltyTierName;
  newRank: LoyaltyTierName;
}

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function normalizeEmail(email: string | null | undefined): string {
  return (email ?? '').trim().toLowerCase();
}

function normalizePhone(phone: string | null | undefined): string {
  if (!phone) {
    return '';
  }

  try {
    return validatePhoneNumber(phone);
  } catch {
    return phone.trim();
  }
}

function buildWebsiteBookingQuery(params?: { fromDate?: string; toDate?: string }): Prisma.Sql {
  const filters: Prisma.Sql[] = [
    Prisma.sql`b.status = 'completed'`,
    Prisma.sql`b.deleted_at IS NULL`,
    Prisma.sql`COALESCE(b.price, 0) >= 0`,
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
      COALESCE(b.price, 0) AS price,
      COALESCE(s.name, 'Reservation') AS service_name
    FROM bookings b
    LEFT JOIN services s ON s.id = b.service_id
    WHERE ${Prisma.join(filters, ' AND ')}
    ORDER BY b.created_at ASC
  `;
}

async function findAppUserForWebsiteClient(websiteClient: WebsiteClientRow) {
  const phone = normalizePhone(websiteClient.phone);
  if (phone) {
    const phoneMatch = await prisma.user.findUnique({
      where: { phoneNumber: phone },
      select: {
        id: true,
        fcmToken: true,
        fullName: true,
        email: true,
      },
    });

    if (phoneMatch) {
      return phoneMatch;
    }
  }

  const email = normalizeEmail(websiteClient.email);
  if (email) {
    const emailMatch = await prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        fcmToken: true,
        fullName: true,
        email: true,
      },
    });

    if (emailMatch) {
      return emailMatch;
    }
  }

  return null;
}

async function sendEarnNotifications(params: {
  accountId: string;
  pointsEarned: number;
  previousTier: LoyaltyTierName;
  currentBalance: number;
  lifetimeAppointments: number;
  user: { fcmToken: string | null; fullName: string | null; email: string | null } | null;
  sourceLabel: string;
}): Promise<LoyaltyTierName> {
  const newTier = getRankFromAppointments(params.lifetimeAppointments);
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

    if (params.pointsEarned > 0) {
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
    }

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

    if (params.pointsEarned > 0) {
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
    logger.info('LOYALTY_BOOKING counted_zero_point_appointment', {
      websiteBookingId: input.websiteBookingId,
      bookingPrice: input.bookingPrice,
    });
  }

  const previousAccount = await prisma.loyaltyAccount.findUnique({
    where: { userId: input.appUserId },
    select: { lifetimeAppointments: true },
  });
  const previousTier = getRankFromAppointments(previousAccount?.lifetimeAppointments ?? 0);

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
          lifetimeAppointments: true,
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
          appointmentsAwarded: 1,
        },
      });

      const updatedAccount = await tx.loyaltyAccount.update({
        where: { id: account.id },
        data: {
          currentBalance: { increment: pointsEarned },
          lifetimeEarned: { increment: pointsEarned },
          lifetimeAppointments: { increment: 1 },
        },
        select: { currentBalance: true, lifetimeEarned: true, lifetimeAppointments: true },
      });

      await tx.loyaltyTransaction.create({
        data: {
          accountId: account.id,
          type: 'EARN',
          points: pointsEarned,
          appointmentCount: 1,
          description: input.serviceName,
          referenceId: input.websiteBookingId,
        },
      });

      return {
        accountId: account.id,
        user: account.user,
        currentBalance: updatedAccount.currentBalance,
        lifetimeEarned: updatedAccount.lifetimeEarned,
        lifetimeAppointments: updatedAccount.lifetimeAppointments,
      };
    });

    const newTier = await sendEarnNotifications({
      accountId: result.accountId,
      pointsEarned,
      previousTier,
      currentBalance: result.currentBalance,
      lifetimeAppointments: result.lifetimeAppointments,
      user: result.user,
      sourceLabel: input.serviceName,
    });

    return {
      pointsEarned,
      newBalance: result.currentBalance,
      newLifetime: result.lifetimeEarned,
      newLifetimeAppointments: result.lifetimeAppointments,
      newTier,
      newRank: newTier,
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
  const websiteClients =
    clientIds.length > 0
      ? await websiteClient.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
          SELECT id, first_name, last_name, phone, email, password_hash, has_account, deleted_at, created_at
          FROM clients
          WHERE id IN (${Prisma.join(clientIds.map((clientId) => Prisma.sql`CAST(${clientId} AS UUID)`))})
        `)
      : [];
  const websiteClientById = new Map(websiteClients.map((client) => [client.id, client]));

  let rewarded = 0;
  let pendingWebsiteClient = 0;
  let pendingAppUser = 0;
  let alreadyRewarded = 0;
  let countedZeroPointAppointments = 0;

  for (const booking of bookings) {
    if (!isNonEmptyString(booking.client_id)) {
      pendingWebsiteClient += 1;
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

    const websiteClientRow = websiteClientById.get(booking.client_id);
    if (!websiteClientRow) {
      pendingWebsiteClient += 1;
      logger.warn('Booking loyalty sync skipped missing website client row', {
        websiteBookingId: booking.id,
        websiteClientId: booking.client_id,
      });
      continue;
    }

    const appUser = await findAppUserForWebsiteClient(websiteClientRow);
    if (!appUser) {
      pendingAppUser += 1;
      continue;
    }

    const result = await awardPointsForCompletedBooking({
      appUserId: appUser.id,
      websiteBookingId: booking.id,
      websiteClientId: booking.client_id,
      serviceName: booking.service_name?.trim() || 'Reservation',
      bookingPrice: booking.price,
    });

    if (result) {
      rewarded += 1;
      if (result.pointsEarned <= 0) {
        countedZeroPointAppointments += 1;
      }
    } else {
      alreadyRewarded += 1;
    }
  }

  logger.info('Booking loyalty reward sync completed', {
    completedBookings: bookings.length,
    rewarded,
    pendingWebsiteClient,
    pendingAppUser,
    alreadyRewarded,
    countedZeroPointAppointments,
  });
}
