/**
 * Reverse website-booking loyalty rewards created before a user's first app login.
 *
 * Dry-run is the default. Pass --apply only after reviewing the report.
 */

import { Prisma } from '@prisma/client';
import prisma from '../src/db/client';
import { disconnectWebsiteClient, getWebsiteClient } from '../src/db/websiteClient';
import { logger } from '../src/utils/logger';

const REVERSAL_PREFIX = 'pre-app-enrollment-reversal:';
const BOOKING_BATCH_SIZE = 500;

type BookingCreatedAt = { id: string; created_at: Date };

function isApplyMode(argv: string[]): boolean {
  return argv.includes('--apply');
}

async function loadBookingDates(bookingIds: string[]): Promise<Map<string, Date>> {
  const websiteClient = getWebsiteClient();
  if (!websiteClient) {
    throw new Error('WEBSITE_DATABASE_URL is required for this repair');
  }

  const dates = new Map<string, Date>();
  for (let offset = 0; offset < bookingIds.length; offset += BOOKING_BATCH_SIZE) {
    const batch = bookingIds.slice(offset, offset + BOOKING_BATCH_SIZE);
    const rows = await websiteClient.$queryRaw<BookingCreatedAt[]>(Prisma.sql`
      SELECT id, created_at
      FROM bookings
      WHERE id IN (${Prisma.join(batch.map((id) => Prisma.sql`CAST(${id} AS UUID)`))})
    `);

    for (const row of rows) {
      dates.set(row.id, row.created_at);
    }
  }

  return dates;
}

async function main(): Promise<void> {
  const apply = isApplyMode(process.argv.slice(2));
  const grants = await prisma.websiteBookingLoyaltyGrant.findMany({
    where: { appUserId: { not: null }, loyaltyAccountId: { not: null } },
    select: {
      websiteBookingId: true,
      appUserId: true,
      loyaltyAccountId: true,
      pointsAwarded: true,
      appointmentsAwarded: true,
      appUser: { select: { appFirstLoginAt: true } },
    },
  });
  const bookingDates = await loadBookingDates(grants.map((grant) => grant.websiteBookingId));

  let candidates = 0;
  let reversed = 0;
  let alreadyReversed = 0;
  let skippedMissingBooking = 0;
  let skippedUnenrolled = 0;
  let skippedInsufficientBalance = 0;

  for (const grant of grants) {
    const bookingCreatedAt = bookingDates.get(grant.websiteBookingId);
    if (!bookingCreatedAt) {
      skippedMissingBooking += 1;
      continue;
    }

    const appFirstLoginAt = grant.appUser?.appFirstLoginAt ?? null;
    if (!appFirstLoginAt) {
      skippedUnenrolled += 1;
      continue;
    }

    if (bookingCreatedAt >= appFirstLoginAt) {
      continue;
    }

    candidates += 1;
    const reversalReferenceId = `${REVERSAL_PREFIX}${grant.websiteBookingId}`;
    const existingReversal = await prisma.loyaltyTransaction.findFirst({
      where: { referenceId: reversalReferenceId, type: 'ADJUST' },
      select: { id: true },
    });
    if (existingReversal) {
      alreadyReversed += 1;
      continue;
    }

    if (!apply) {
      logger.info('LOYALTY_REPAIR candidate', {
        websiteBookingId: grant.websiteBookingId,
        appUserId: grant.appUserId,
        points: grant.pointsAwarded,
        appointments: grant.appointmentsAwarded,
        bookingCreatedAt,
        appFirstLoginAt,
      });
      continue;
    }

    const result = await prisma.$transaction(async (tx) => {
      const account = await tx.loyaltyAccount.findUnique({
        where: { id: grant.loyaltyAccountId! },
        select: { currentBalance: true, lifetimeEarned: true, lifetimeAppointments: true },
      });
      if (!account || account.currentBalance < grant.pointsAwarded ||
          account.lifetimeEarned < grant.pointsAwarded ||
          account.lifetimeAppointments < grant.appointmentsAwarded) {
        return 'insufficient' as const;
      }

      const duplicate = await tx.loyaltyTransaction.findFirst({
        where: { referenceId: reversalReferenceId, type: 'ADJUST' },
        select: { id: true },
      });
      if (duplicate) {
        return 'already-reversed' as const;
      }

      await tx.loyaltyAccount.update({
        where: { id: grant.loyaltyAccountId! },
        data: {
          currentBalance: { decrement: grant.pointsAwarded },
          lifetimeEarned: { decrement: grant.pointsAwarded },
          lifetimeAppointments: { decrement: grant.appointmentsAwarded },
        },
      });
      await tx.loyaltyTransaction.create({
        data: {
          accountId: grant.loyaltyAccountId!,
          type: 'ADJUST',
          points: -grant.pointsAwarded,
          appointmentCount: -grant.appointmentsAwarded,
          description: 'Reverse pre-app-enrollment website booking reward',
          referenceId: reversalReferenceId,
        },
      });
      return 'reversed' as const;
    });

    if (result === 'reversed') reversed += 1;
    if (result === 'already-reversed') alreadyReversed += 1;
    if (result === 'insufficient') {
      skippedInsufficientBalance += 1;
      logger.warn('LOYALTY_REPAIR skipped_insufficient_balance', {
        websiteBookingId: grant.websiteBookingId,
        appUserId: grant.appUserId,
        points: grant.pointsAwarded,
      });
    }
  }

  logger.info('LOYALTY_REPAIR completed', {
    mode: apply ? 'apply' : 'dry-run',
    grantsScanned: grants.length,
    candidates,
    reversed,
    alreadyReversed,
    skippedMissingBooking,
    skippedUnenrolled,
    skippedInsufficientBalance,
  });
}

main()
  .catch((error) => {
    logger.error('LOYALTY_REPAIR failed', { error: error instanceof Error ? error.message : error });
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
    await disconnectWebsiteClient();
  });
