/**
 * Immediate sync helper for the website reservation database.
 *
 * The periodic reconciliation job still exists as a safety net, but this helper
 * lets app-side user mutations push the latest profile/password snapshot to the
 * website right away.
 */

import { Prisma } from '@prisma/client';
import prisma from '../../db/client';
import { getWebsiteClient } from '../../db/websiteClient';
import { AppError, ErrorCode } from '../../utils/errors';
import { isBcryptHash } from './utils/password';
import { validatePhoneNumber } from './utils/phone';

type AppUserRow = {
  id: string;
  email: string;
  phoneNumber: string;
  fullName: string | null;
  passwordHash: string;
  websitePasswordHash: string | null;
  isActive: boolean;
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

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function normalizePhone(phone: string): string {
  try {
    return validatePhoneNumber(phone);
  } catch {
    return phone.trim();
  }
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
      const single = parts[0];
      return { firstName: single, lastName: single };
    }

    return {
      firstName: parts[0] || 'Client',
      lastName: parts.slice(1).join(' ') || parts[0] || 'Client',
    };
  }

  const emailLocalPart = email.split('@')[0]?.trim();
  const fallbackFirst = emailLocalPart || 'Client';
  const fallbackLast = phone.replace(/\D+/g, '').slice(-4) || 'App';
  return { firstName: fallbackFirst, lastName: fallbackLast };
}

async function findWebsiteClientById(
  websiteClientDb: NonNullable<ReturnType<typeof getWebsiteClient>>,
  id: string
): Promise<WebsiteClientRow | null> {
  const rows = await websiteClientDb.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
    SELECT id, first_name, last_name, phone, email, password_hash, has_account, deleted_at, created_at
    FROM clients
    WHERE id = CAST(${id} AS UUID)
    LIMIT 1
  `);

  return rows[0] ?? null;
}

async function findWebsiteClientByPhone(
  websiteClientDb: NonNullable<ReturnType<typeof getWebsiteClient>>,
  phone: string,
  excludeId?: string | null
): Promise<WebsiteClientRow | null> {
  const normalizedPhone = phone.trim();
  if (!normalizedPhone) {
    return null;
  }

  const rows = await websiteClientDb.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
    SELECT id, first_name, last_name, phone, email, password_hash, has_account, deleted_at, created_at
    FROM clients
    WHERE phone = ${normalizedPhone}
      ${excludeId ? Prisma.sql`AND id <> CAST(${excludeId} AS UUID)` : Prisma.sql``}
    ORDER BY created_at ASC
    LIMIT 1
  `);

  return rows[0] ?? null;
}

async function findWebsiteClientByEmail(
  websiteClientDb: NonNullable<ReturnType<typeof getWebsiteClient>>,
  email: string,
  excludeId?: string | null
): Promise<WebsiteClientRow | null> {
  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail) {
    return null;
  }

  const rows = await websiteClientDb.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
    SELECT id, first_name, last_name, phone, email, password_hash, has_account, deleted_at, created_at
    FROM clients
    WHERE email IS NOT NULL
      AND LOWER(email) = LOWER(${normalizedEmail})
      ${excludeId ? Prisma.sql`AND id <> CAST(${excludeId} AS UUID)` : Prisma.sql``}
    ORDER BY created_at ASC
    LIMIT 1
  `);

  return rows[0] ?? null;
}

function resolveWebsitePasswordHash(
  appUser: AppUserRow,
  websiteClient: WebsiteClientRow | null
): string | null {
  if (appUser.websitePasswordHash) {
    return appUser.websitePasswordHash;
  }

  if (websiteClient?.password_hash) {
    return websiteClient.password_hash;
  }

  if (isBcryptHash(appUser.passwordHash)) {
    return appUser.passwordHash;
  }

  return null;
}

async function upsertSyncLink(
  appUserId: string,
  websiteClientId: string,
  profileSnapshot: string
): Promise<void> {
  await prisma.userSyncLink.upsert({
    where: { appUserId },
    create: {
      appUserId,
      websiteClientId,
      appSnapshot: profileSnapshot,
      websiteSnapshot: profileSnapshot,
      lastSyncedFrom: 'APP',
    },
    update: {
      websiteClientId,
      appSnapshot: profileSnapshot,
      websiteSnapshot: profileSnapshot,
      lastSyncedFrom: 'APP',
    },
  });
}

/**
 * Push the current app user snapshot to the website database now.
 * Returns the website client id when sync is possible, or null when the website
 * database is not configured.
 */
export async function syncAppUserToWebsiteNow(appUserId: string): Promise<string | null> {
  const websiteClientDb = getWebsiteClient();
  if (!websiteClientDb) {
    return null;
  }

  const appUser = await prisma.user.findUnique({
    where: { id: appUserId },
    select: {
      id: true,
      email: true,
      phoneNumber: true,
      fullName: true,
      passwordHash: true,
      websitePasswordHash: true,
      isActive: true,
    },
  });

  if (!appUser) {
    throw new AppError(ErrorCode.NOT_FOUND, 'User not found', 404);
  }

  const appProfile = {
    ...splitFullName(appUser.fullName, appUser.email, appUser.phoneNumber),
    email: normalizeEmail(appUser.email),
    phone: normalizePhone(appUser.phoneNumber),
  };

  const syncLink = await prisma.userSyncLink.findUnique({
    where: { appUserId: appUser.id },
    select: { websiteClientId: true },
  });

  let websiteClient: WebsiteClientRow | null = null;
  if (syncLink?.websiteClientId) {
    websiteClient = await findWebsiteClientById(
      websiteClientDb,
      syncLink.websiteClientId
    );
  }
  if (!websiteClient) {
    websiteClient = await findWebsiteClientByPhone(
      websiteClientDb,
      appProfile.phone,
      syncLink?.websiteClientId
    );
  }
  if (!websiteClient) {
    websiteClient = await findWebsiteClientByEmail(
      websiteClientDb,
      appProfile.email,
      syncLink?.websiteClientId
    );
  }

  const websitePasswordHash = resolveWebsitePasswordHash(
    appUser,
    websiteClient
  );

  if (appUser.isActive && !websitePasswordHash) {
    throw new AppError(
      ErrorCode.INTERNAL_ERROR,
      'Website password hash missing for active user',
      500
    );
  }

  const activePasswordHash =
    websitePasswordHash ?? websiteClient?.password_hash ?? null;
  const hasAccount = appUser.isActive && Boolean(activePasswordHash);
  const deletedAt = appUser.isActive ? null : new Date();
  const websitePasswordValue = appUser.isActive ? activePasswordHash : null;

  if (websiteClient) {
    await websiteClientDb.$executeRaw(Prisma.sql`
      UPDATE clients
      SET first_name = ${appProfile.firstName},
          last_name = ${appProfile.lastName},
          phone = ${appProfile.phone},
          email = ${appProfile.email || null},
          password_hash = ${websitePasswordValue},
          has_account = ${hasAccount},
          deleted_at = ${deletedAt}
      WHERE id = CAST(${websiteClient.id} AS UUID)
    `);
  } else {
    const created = await websiteClientDb.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
      INSERT INTO clients (
        first_name,
        last_name,
        phone,
        email,
        password_hash,
        has_account,
        deleted_at
      )
      VALUES (
        ${appProfile.firstName},
        ${appProfile.lastName},
        ${appProfile.phone},
        ${appProfile.email || null},
        ${websitePasswordValue},
        ${hasAccount},
        ${deletedAt}
      )
      RETURNING id, first_name, last_name, phone, email, password_hash, has_account, deleted_at, created_at
    `);

    websiteClient = created[0] ?? null;
  }

  if (!websiteClient) {
    throw new AppError(
      ErrorCode.INTERNAL_ERROR,
      'Unable to sync user to website',
      500
    );
  }

  await upsertSyncLink(
    appUser.id,
    websiteClient.id,
    JSON.stringify({
      firstName: appProfile.firstName,
      lastName: appProfile.lastName,
      email: appProfile.email,
      phone: appProfile.phone,
      isActive: appUser.isActive,
      passwordHash: activePasswordHash,
    })
  );

  return websiteClient.id;
}
