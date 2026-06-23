/**
 * One-off script to award loyalty points for bookings completed in the last full week.
 *
 * Run from backend:
 *   npm run backfill-booking-loyalty-yesterday
 *
 * Optional overrides:
 *   npm run backfill-booking-loyalty-yesterday -- --date=2026-06-21
 *   npm run backfill-booking-loyalty-yesterday -- --from=2026-06-21 --to=2026-06-21
 *   npm run backfill-booking-loyalty-yesterday -- --timezone=Europe/Paris
 */

import path from 'path';
import dotenv from 'dotenv';
import { Prisma, UserSyncSource } from '@prisma/client';
import prisma from '../src/db/client';
import { getWebsiteClient } from '../src/db/websiteClient';
import { validatePhoneNumber } from '../src/modules/auth/utils/phone';
import { isBcryptHash } from '../src/modules/auth/utils/password';
import { logger } from '../src/utils/logger';

const backendRoot = path.resolve(__dirname, '..');
dotenv.config({ path: path.join(backendRoot, '.env') });

type CliOptions = {
  date?: string;
  fromDate?: string;
  toDate?: string;
  timezone?: string;
};

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {};

  for (const arg of argv) {
    if (arg.startsWith('--date=')) {
      options.date = arg.slice('--date='.length);
    } else if (arg.startsWith('--from=')) {
      options.fromDate = arg.slice('--from='.length);
    } else if (arg.startsWith('--to=')) {
      options.toDate = arg.slice('--to='.length);
    } else if (arg.startsWith('--timezone=')) {
      options.timezone = arg.slice('--timezone='.length);
    }
  }

  return options;
}

function assertDateString(value: string, label: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(`${label} must be in YYYY-MM-DD format`);
  }

  return value;
}

function formatDateInTimeZone(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);

  const lookup = Object.fromEntries(parts.map((part) => [part.type, part.value]));

  if (!lookup.year || !lookup.month || !lookup.day) {
    throw new Error(`Unable to format date for time zone ${timeZone}`);
  }

  return `${lookup.year}-${lookup.month}-${lookup.day}`;
}

function subtractDays(dateString: string, days: number): string {
  const [year, month, day] = dateString.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
  date.setUTCDate(date.getUTCDate() - days);
  return date.toISOString().slice(0, 10);
}

function normalizeRange(options: CliOptions): { fromDate: string; toDate: string; timezone: string } {
  const timezone = options.timezone?.trim() || 'Europe/Paris';

  if (options.fromDate || options.toDate) {
    const fromDate = assertDateString(options.fromDate ?? options.toDate ?? '', '--from');
    const toDate = assertDateString(options.toDate ?? options.fromDate ?? '', '--to');

    if (fromDate > toDate) {
      throw new Error('--from cannot be after --to');
    }

    return { fromDate, toDate, timezone };
  }

  if (options.date) {
    const date = assertDateString(options.date, '--date');
    return { fromDate: date, toDate: date, timezone };
  }

  const todayInTimeZone = formatDateInTimeZone(new Date(), timezone);
  const yesterday = subtractDays(todayInTimeZone, 1);
  const fromDate = subtractDays(yesterday, 6);

  return { fromDate, toDate: yesterday, timezone };
}

type AppUserRow = {
  id: string;
  email: string;
  phoneNumber: string;
  fullName: string | null;
  passwordHash: string;
  websitePasswordHash: string | null;
  isActive: boolean;
  createdAt: Date;
};

type WebsiteClientRow = {
  id: string;
  first_name: string;
  last_name: string;
  phone: string | null;
  email: string | null;
  password_hash: string | null;
  has_account: boolean | null;
  deleted_at: Date | null;
  created_at: Date;
};

type WebsiteBookingRow = {
  id: string;
  client_id: string | null;
  price: number;
  service_name: string | null;
};

type SyncLinkRow = {
  appUserId: string;
  websiteClientId: string | null;
};

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

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function normalizeEmail(email: string | null | undefined): string {
  return (email ?? '').trim().toLowerCase();
}

function phoneMatchKeys(phone: string | null | undefined): string[] {
  if (!phone) {
    return [];
  }

  const keys = new Set<string>();
  const trimmed = phone.trim();
  if (!trimmed) {
    return [];
  }

  const compact = trimmed.replace(/[\s().-]+/g, '');
  const digits = compact.replace(/\D+/g, '');

  [
    trimmed,
    compact,
    compact.replace(/^\+/, ''),
    digits,
    digits.replace(/^0+/, ''),
    digits.replace(/^33/, ''),
    digits.replace(/^0+/, '').replace(/^33/, ''),
  ].forEach((key) => {
    const normalized = key.trim();
    if (normalized) {
      keys.add(normalized);
    }
  });

  try {
    const normalized = validatePhoneNumber(phone).trim();
    if (normalized) {
      keys.add(normalized);
      keys.add(normalized.replace(/^\+/, ''));
    }
  } catch {
    // Ignore invalid phone formats here; matching can still work through the raw variants above.
  }

  return [...keys];
}

function addIndexedValue<T>(map: Map<string, T[]>, keys: string[], value: T): void {
  for (const key of keys) {
    if (!map.has(key)) {
      map.set(key, []);
    }

    map.get(key)!.push(value);
  }
}

function collectIndexedValues<T extends { id: string }>(
  map: Map<string, T[]>,
  keys: string[],
  excludedIds: Set<string>
): T[] {
  const seen = new Set<string>();
  const values: T[] = [];

  for (const key of keys) {
    for (const item of map.get(key) ?? []) {
      if (excludedIds.has(item.id) || seen.has(item.id)) {
        continue;
      }

      seen.add(item.id);
      values.push(item);
    }
  }

  return values;
}

function uniqueById<T extends { id: string }>(values: T[]): T[] {
  const seen = new Set<string>();
  const result: T[] = [];

  for (const value of values) {
    if (seen.has(value.id)) {
      continue;
    }

    seen.add(value.id);
    result.push(value);
  }

  return result;
}

function clamp(value: string, maxLength = 100): string {
  return value.trim().slice(0, maxLength);
}

function splitFullName(
  fullName: string | null | undefined,
  email: string,
  phone: string
): { firstName: string; lastName: string } {
  const trimmed = fullName?.trim();
  if (trimmed) {
    const parts = trimmed.split(/\s+/).filter(Boolean);
    if (parts.length === 1) {
      const single = clamp(parts[0]) || 'Client';
      return { firstName: single, lastName: single };
    }

    return {
      firstName: clamp(parts[0]) || 'Client',
      lastName: clamp(parts.slice(1).join(' ')) || clamp(parts[0]) || 'Client',
    };
  }

  const emailLocalPart = email.split('@')[0]?.trim();
  const fallbackFirst = clamp(emailLocalPart || 'Client') || 'Client';
  const fallbackLast = clamp(phone.replace(/\D+/g, '').slice(-4)) || 'App';
  return { firstName: fallbackFirst, lastName: fallbackLast };
}

function composeFullName(firstName: string, lastName: string): string {
  return `${firstName} ${lastName}`.trim();
}

function selectBestAppUser(candidates: AppUserRow[]): AppUserRow | null {
  if (candidates.length === 0) {
    return null;
  }

  return [...candidates].sort((a, b) => {
    const aScore = (a.isActive ? 4 : 0) + (a.websitePasswordHash ? 2 : 0) + (isBcryptHash(a.passwordHash) ? 1 : 0);
    const bScore = (b.isActive ? 4 : 0) + (b.websitePasswordHash ? 2 : 0) + (isBcryptHash(b.passwordHash) ? 1 : 0);

    if (aScore !== bScore) {
      return bScore - aScore;
    }

    return a.createdAt.getTime() - b.createdAt.getTime();
  })[0];
}

function isUniqueViolation(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

async function ensureBookingClientLinksForRange(params: { fromDate: string; toDate: string }): Promise<void> {
  const websiteClient = getWebsiteClient();
  if (!websiteClient) {
    throw new Error('WEBSITE_DATABASE_URL is not configured');
  }

  const bookings = await websiteClient.$queryRaw<WebsiteBookingRow[]>(Prisma.sql`
    SELECT
      b.id,
      b.client_id,
      b.price,
      COALESCE(s.name, 'Reservation') AS service_name
    FROM bookings b
    LEFT JOIN services s ON s.id = b.service_id
    WHERE b.status = 'completed'
      AND b.deleted_at IS NULL
      AND b.price > 0
      AND b.date >= CAST(${params.fromDate} AS DATE)
      AND b.date <= CAST(${params.toDate} AS DATE)
    ORDER BY b.created_at ASC
  `);

  const clientIds = [...new Set(bookings.map((row) => row.client_id).filter(isNonEmptyString))];

  if (clientIds.length === 0) {
    logger.info('No booking client ids found for link backfill', {
      fromDate: params.fromDate,
      toDate: params.toDate,
    });
    return;
  }

  const [appUsers, existingLinks, websiteClients] = await Promise.all([
    prisma.user.findMany({
      select: {
        id: true,
        email: true,
        phoneNumber: true,
        fullName: true,
        passwordHash: true,
        websitePasswordHash: true,
        isActive: true,
        createdAt: true,
      },
    }),
    prisma.userSyncLink.findMany({
      select: {
        appUserId: true,
        websiteClientId: true,
      },
    }),
    (async () => {
      const chunks = chunkArray(clientIds, 250);
      const rows: WebsiteClientRow[] = [];

      for (const chunk of chunks) {
        const chunkRows = await websiteClient.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
          SELECT
            id,
            first_name,
            last_name,
            phone,
            email,
            password_hash,
            has_account,
            deleted_at,
            created_at
          FROM clients
          WHERE id IN (${Prisma.join(chunk.map((id) => Prisma.sql`CAST(${id} AS UUID)`))})
        `);
        rows.push(...chunkRows);
      }

      return rows;
    })(),
  ]);

  const appUsersByEmail = new Map<string, AppUserRow[]>();
  const appUsersByPhone = new Map<string, AppUserRow[]>();
  for (const user of appUsers) {
    addIndexedValue(appUsersByEmail, [normalizeEmail(user.email)], user);
    addIndexedValue(appUsersByPhone, phoneMatchKeys(user.phoneNumber), user);
  }

  const linkByAppUserId = new Map(existingLinks.map((link) => [link.appUserId, link]));
  const linkByWebsiteClientId = new Map(
    existingLinks
      .filter((link) => isNonEmptyString(link.websiteClientId))
      .map((link) => [link.websiteClientId as string, link])
  );

  const claimedAppUserIds = new Set(
    existingLinks
      .filter((link) => isNonEmptyString(link.websiteClientId))
      .map((link) => link.appUserId)
  );
  const claimedWebsiteClientIds = new Set(existingLinks.map((link) => link.websiteClientId).filter(isNonEmptyString));

  let linkedExistingUsers = 0;
  let createdAppUsers = 0;
  let skippedClients = 0;

  for (const websiteClient of websiteClients) {
    if (claimedWebsiteClientIds.has(websiteClient.id)) {
      linkedExistingUsers += 1;
      continue;
    }

    const emailKey = normalizeEmail(websiteClient.email);
    const phoneCandidates = collectIndexedValues(
      appUsersByPhone,
      phoneMatchKeys(websiteClient.phone),
      claimedAppUserIds
    );
    const emailCandidates = (appUsersByEmail.get(emailKey) ?? [])
      .filter((user) => !claimedAppUserIds.has(user.id));
    const allPhoneCandidates = collectIndexedValues(
      appUsersByPhone,
      phoneMatchKeys(websiteClient.phone),
      new Set<string>()
    );
    const allEmailCandidates = appUsersByEmail.get(emailKey) ?? [];
    const candidate = selectBestAppUser(uniqueById([...phoneCandidates, ...emailCandidates]))
      ?? selectBestAppUser(uniqueById([...allPhoneCandidates, ...allEmailCandidates]));
    if (candidate) {
      const existingLink = linkByAppUserId.get(candidate.id);
      if (existingLink?.websiteClientId && existingLink.websiteClientId !== websiteClient.id) {
        logger.warn('Booking backfill reassigned app user to a different website client', {
          appUserId: candidate.id,
          previousWebsiteClientId: existingLink.websiteClientId,
          nextWebsiteClientId: websiteClient.id,
        });
      }

      await prisma.userSyncLink.upsert({
        where: { appUserId: candidate.id },
        create: {
          appUserId: candidate.id,
          websiteClientId: websiteClient.id,
          lastSyncedFrom: UserSyncSource.WEBSITE,
        },
        update: {
          websiteClientId: websiteClient.id,
          lastSyncedFrom: UserSyncSource.WEBSITE,
        },
      });

      claimedAppUserIds.add(candidate.id);
      claimedWebsiteClientIds.add(websiteClient.id);
      linkByAppUserId.set(candidate.id, { appUserId: candidate.id, websiteClientId: websiteClient.id });
      linkByWebsiteClientId.set(websiteClient.id, { appUserId: candidate.id, websiteClientId: websiteClient.id });
      linkedExistingUsers += 1;
      continue;
    }

    if (!websiteClient.password_hash || !websiteClient.email || !websiteClient.phone || websiteClient.deleted_at != null) {
      skippedClients += 1;
      continue;
    }

    const email = normalizeEmail(websiteClient.email);
    if (!email) {
      skippedClients += 1;
      continue;
    }

    let phoneNumber: string;
    try {
      phoneNumber = validatePhoneNumber(websiteClient.phone);
    } catch {
      skippedClients += 1;
      continue;
    }

    const { firstName, lastName } = splitFullName(
      `${websiteClient.first_name} ${websiteClient.last_name}`.trim(),
      email,
      phoneNumber
    );

    try {
      const created = await prisma.user.create({
        data: {
          email,
          phoneNumber,
          passwordHash: websiteClient.password_hash,
          websitePasswordHash: websiteClient.password_hash,
          fullName: composeFullName(firstName, lastName),
          isActive: websiteClient.deleted_at == null,
        },
        select: { id: true },
      });

      await prisma.userSyncLink.upsert({
        where: { appUserId: created.id },
        create: {
          appUserId: created.id,
          websiteClientId: websiteClient.id,
          lastSyncedFrom: UserSyncSource.WEBSITE,
        },
        update: {
          websiteClientId: websiteClient.id,
          lastSyncedFrom: UserSyncSource.WEBSITE,
        },
      });

      claimedAppUserIds.add(created.id);
      claimedWebsiteClientIds.add(websiteClient.id);
      createdAppUsers += 1;
    } catch (error) {
      if (isUniqueViolation(error)) {
        skippedClients += 1;
        continue;
      }

      throw error;
    }
  }

  logger.info('Booking client link backfill completed', {
    bookings: bookings.length,
    matchedBookings: clientIds.length,
    linkedExistingUsers,
    createdAppUsers,
    skippedClients,
  });
}

function isPostgresConnectionString(value: string | undefined): boolean {
  return typeof value === 'string' && /^postgres(?:ql)?:\/\//i.test(value.trim());
}

function failWithEnvHint(message: string): never {
  logger.error(message, {
    databaseUrlSet: Boolean(process.env.DATABASE_URL),
    websiteDatabaseUrlSet: Boolean(process.env.WEBSITE_DATABASE_URL),
  });
  process.exit(1);
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const { fromDate, toDate, timezone } = normalizeRange(options);

  if (!isPostgresConnectionString(process.env.DATABASE_URL)) {
    failWithEnvHint(
      'DATABASE_URL must be a Postgres connection string like postgresql://user:pass@host:port/db. ' +
        'You probably set it to a Railway host name or app URL by mistake.'
    );
  }

  if (!isPostgresConnectionString(process.env.WEBSITE_DATABASE_URL)) {
    failWithEnvHint('WEBSITE_DATABASE_URL must be set to the website Postgres connection string.');
  }

  const { runBookingLoyaltyRewardSync } = await import('../src/modules/loyalty_v2/bookingRewards');

  logger.info('Starting week booking loyalty backfill', {
    fromDate,
    toDate,
    timezone,
  });

  logger.info('Linking booking clients before booking loyalty backfill', {
    timezone,
  });
  await ensureBookingClientLinksForRange({ fromDate, toDate });

  await runBookingLoyaltyRewardSync({ fromDate, toDate });

  logger.info('Week booking loyalty backfill completed', {
    fromDate,
    toDate,
    timezone,
  });
}

main().catch((error) => {
  logger.error('Week booking loyalty backfill failed', {
    error: error instanceof Error ? error.message : error,
  });
  process.exit(1);
});
