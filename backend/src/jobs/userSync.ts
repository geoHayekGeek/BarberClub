/**
 * Periodic user sync between the app database and the reservation website database.
 *
 * The app remains the source of truth for its own auth model, but we keep a
 * website-compatible password hash on each app user so the sync job can mirror
 * credentials across both systems.
 */

import { Prisma, UserSyncSource } from '@prisma/client';
import prisma from '../db/client';
import { getWebsiteClient } from '../db/websiteClient';
import { logger } from '../utils/logger';
import { validatePhoneNumber } from '../modules/auth/utils/phone';
import { isBcryptHash } from '../modules/auth/utils/password';

const INTERVAL_MS = 10 * 60 * 1000;

type CanonicalProfile = {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  isActive: boolean;
  passwordHash: string | null;
};

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

let intervalId: ReturnType<typeof setInterval> | null = null;
let isRunning = false;

function normalizeEmail(email: string | null | undefined): string {
  return (email ?? '').trim().toLowerCase();
}

function normalizeOptionalPhone(phone: string | null | undefined): string {
  if (!phone) return '';
  try {
    return validatePhoneNumber(phone);
  } catch {
    return phone.trim();
  }
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
    // Ignore invalid phone formats here; matching should still work via the raw variants above.
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

function splitFullName(fullName: string | null | undefined, email: string, phone: string): { firstName: string; lastName: string } {
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

function appSyncPasswordHash(user: AppUserRow): string | null {
  if (user.websitePasswordHash) {
    return user.websitePasswordHash;
  }

  if (isBcryptHash(user.passwordHash)) {
    return user.passwordHash;
  }

  return null;
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

function buildAppProfile(user: AppUserRow): CanonicalProfile {
  const { firstName, lastName } = splitFullName(user.fullName, user.email, user.phoneNumber);
  return {
    firstName,
    lastName,
    email: normalizeEmail(user.email),
    phone: normalizeOptionalPhone(user.phoneNumber),
    isActive: user.isActive,
    passwordHash: appSyncPasswordHash(user),
  };
}

function buildWebsiteProfile(client: WebsiteClientRow): CanonicalProfile {
  return {
    firstName: clamp(client.first_name) || 'Client',
    lastName: clamp(client.last_name) || clamp(client.first_name) || 'Client',
    email: normalizeEmail(client.email),
    phone: normalizeOptionalPhone(client.phone),
    isActive: client.deleted_at == null,
    passwordHash: client.password_hash,
  };
}

function serializeProfile(profile: CanonicalProfile): string {
  return JSON.stringify(profile);
}

function parseProfile(serialized: string | null | undefined): CanonicalProfile | null {
  if (!serialized) return null;

  try {
    const parsed = JSON.parse(serialized) as Partial<CanonicalProfile>;
    return {
      firstName: typeof parsed.firstName === 'string' ? parsed.firstName : '',
      lastName: typeof parsed.lastName === 'string' ? parsed.lastName : '',
      email: typeof parsed.email === 'string' ? parsed.email : '',
      phone: typeof parsed.phone === 'string' ? parsed.phone : '',
      isActive: typeof parsed.isActive === 'boolean' ? parsed.isActive : false,
      passwordHash: typeof parsed.passwordHash === 'string' ? parsed.passwordHash : null,
    };
  } catch {
    return null;
  }
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function assignProfileField(
  profile: CanonicalProfile,
  field: keyof CanonicalProfile,
  value: CanonicalProfile[keyof CanonicalProfile]
): void {
  switch (field) {
    case 'firstName':
      profile.firstName = String(value);
      break;
    case 'lastName':
      profile.lastName = String(value);
      break;
    case 'email':
      profile.email = String(value);
      break;
    case 'phone':
      profile.phone = String(value);
      break;
    case 'isActive':
      profile.isActive = Boolean(value);
      break;
    case 'passwordHash':
      profile.passwordHash = typeof value === 'string' ? value : null;
      break;
  }
}

function fieldSource(
  field: keyof CanonicalProfile,
  appProfile: CanonicalProfile,
  websiteProfile: CanonicalProfile,
  previousAppProfile: CanonicalProfile | null,
  previousWebsiteProfile: CanonicalProfile | null,
  lastSyncedFrom: UserSyncSource | null
): UserSyncSource | null {
  const appValue = appProfile[field];
  const websiteValue = websiteProfile[field];

  if (Object.is(appValue, websiteValue)) {
    return null;
  }

  const appUsable = field === 'isActive' ? typeof appValue === 'boolean' : isNonEmptyString(appValue);
  const websiteUsable = field === 'isActive' ? typeof websiteValue === 'boolean' : isNonEmptyString(websiteValue);

  if (appUsable && !websiteUsable) {
    return UserSyncSource.APP;
  }

  if (!appUsable && websiteUsable) {
    return UserSyncSource.WEBSITE;
  }

  const appChanged = previousAppProfile == null || !Object.is(appValue, previousAppProfile[field]);
  const websiteChanged = previousWebsiteProfile == null || !Object.is(websiteValue, previousWebsiteProfile[field]);

  if (appChanged && !websiteChanged) {
    return UserSyncSource.APP;
  }

  if (websiteChanged && !appChanged) {
    return UserSyncSource.WEBSITE;
  }

  if (appChanged && websiteChanged) {
    return lastSyncedFrom ?? UserSyncSource.APP;
  }

  return null;
}

function resolveMergedProfile(
  appProfile: CanonicalProfile,
  websiteProfile: CanonicalProfile,
  previousAppProfile: CanonicalProfile | null,
  previousWebsiteProfile: CanonicalProfile | null,
  lastSyncedFrom: UserSyncSource | null
): { profile: CanonicalProfile; sourceWeights: Record<UserSyncSource, number> } {
  const profile: CanonicalProfile = { ...appProfile };
  const sourceWeights: Record<UserSyncSource, number> = {
    [UserSyncSource.APP]: 0,
    [UserSyncSource.WEBSITE]: 0,
  };

  const weightByField: Record<keyof CanonicalProfile, number> = {
    firstName: 1,
    lastName: 1,
    email: 1,
    phone: 1,
    isActive: 1,
    passwordHash: 3,
  };

  (Object.keys(profile) as Array<keyof CanonicalProfile>).forEach((field) => {
    const source = fieldSource(
      field,
      appProfile,
      websiteProfile,
      previousAppProfile,
      previousWebsiteProfile,
      lastSyncedFrom
    );

    if (source === UserSyncSource.WEBSITE) {
      assignProfileField(profile, field, websiteProfile[field]);
      sourceWeights[UserSyncSource.WEBSITE] += weightByField[field];
    } else if (source === UserSyncSource.APP) {
      assignProfileField(profile, field, appProfile[field]);
      sourceWeights[UserSyncSource.APP] += weightByField[field];
    }
  });

  return { profile, sourceWeights };
}

function selectBestWebsiteClient(candidates: WebsiteClientRow[]): WebsiteClientRow | null {
  if (candidates.length === 0) {
    return null;
  }

  return [...candidates].sort((a, b) => {
    const aScore = (a.deleted_at == null ? 4 : 0) + (a.password_hash ? 2 : 0) + (a.has_account ? 1 : 0);
    const bScore = (b.deleted_at == null ? 4 : 0) + (b.password_hash ? 2 : 0) + (b.has_account ? 1 : 0);

    if (aScore !== bScore) {
      return bScore - aScore;
    }

    return a.created_at.getTime() - b.created_at.getTime();
  })[0];
}

async function persistLinkState(params: {
  appUserId: string;
  websiteClientId?: string | null;
  appSnapshot?: string | null;
  websiteSnapshot?: string | null;
  lastSyncedFrom?: UserSyncSource | null;
}): Promise<void> {
  const { appUserId, websiteClientId, appSnapshot, websiteSnapshot, lastSyncedFrom } = params;

  await prisma.userSyncLink.upsert({
    where: { appUserId },
    create: {
      appUserId,
      websiteClientId: websiteClientId ?? null,
      appSnapshot: appSnapshot ?? null,
      websiteSnapshot: websiteSnapshot ?? null,
      lastSyncedFrom: lastSyncedFrom ?? undefined,
    },
    update: {
      ...(websiteClientId !== undefined ? { websiteClientId } : {}),
      ...(appSnapshot !== undefined ? { appSnapshot } : {}),
      ...(websiteSnapshot !== undefined ? { websiteSnapshot } : {}),
      ...(lastSyncedFrom !== undefined ? { lastSyncedFrom } : {}),
    },
  });
}

async function syncAppUserToWebsite(
  appUser: AppUserRow,
  websiteClient: WebsiteClientRow | null,
  mergedProfile: CanonicalProfile,
  lastSyncedFrom: UserSyncSource | null
): Promise<void> {
  const websiteClientDb = getWebsiteClient();
  if (!websiteClientDb) {
    return;
  }

  if (!websiteClient) {
    const created = await websiteClientDb.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
      INSERT INTO clients (first_name, last_name, phone, email, password_hash, has_account, deleted_at)
      VALUES (
        ${mergedProfile.firstName},
        ${mergedProfile.lastName},
        ${mergedProfile.phone},
        ${mergedProfile.email || null},
        ${mergedProfile.isActive ? mergedProfile.passwordHash : null},
        ${mergedProfile.isActive && Boolean(mergedProfile.passwordHash)},
        ${mergedProfile.isActive ? null : new Date()}
      )
      RETURNING id, first_name, last_name, phone, email, password_hash, has_account, deleted_at, created_at
    `);

    const createdClient = created[0];
    await persistLinkState({
      appUserId: appUser.id,
      websiteClientId: createdClient.id,
      appSnapshot: serializeProfile(mergedProfile),
      websiteSnapshot: serializeProfile(mergedProfile),
      lastSyncedFrom,
    });
    return;
  }

  await websiteClientDb.$executeRaw(Prisma.sql`
    UPDATE clients
    SET
      first_name = ${mergedProfile.firstName},
      last_name = ${mergedProfile.lastName},
      phone = ${mergedProfile.phone},
      email = ${mergedProfile.email || null},
      password_hash = ${mergedProfile.isActive ? mergedProfile.passwordHash : null},
      has_account = ${mergedProfile.isActive && Boolean(mergedProfile.passwordHash)},
      deleted_at = ${mergedProfile.isActive ? null : new Date()}
    WHERE id = CAST(${websiteClient.id} AS UUID)
  `);

  await persistLinkState({
    appUserId: appUser.id,
    websiteClientId: websiteClient.id,
    appSnapshot: serializeProfile(mergedProfile),
    websiteSnapshot: serializeProfile(mergedProfile),
    lastSyncedFrom,
  });
}

async function syncWebsiteClientToApp(
  websiteClient: WebsiteClientRow,
  appUser: AppUserRow | null,
  mergedProfile: CanonicalProfile,
  lastSyncedFrom: UserSyncSource | null
): Promise<void> {
  if (!appUser) {
    if (!websiteClient.password_hash || !websiteClient.email || !websiteClient.phone || websiteClient.deleted_at != null) {
      return;
    }

    const created = await prisma.user.create({
      data: {
        email: mergedProfile.email,
        phoneNumber: mergedProfile.phone,
        passwordHash: mergedProfile.passwordHash ?? websiteClient.password_hash,
        websitePasswordHash: mergedProfile.passwordHash ?? websiteClient.password_hash,
        fullName: composeFullName(mergedProfile.firstName, mergedProfile.lastName),
        isActive: mergedProfile.isActive,
      },
      select: {
        id: true,
      },
    });

    await persistLinkState({
      appUserId: created.id,
      websiteClientId: websiteClient.id,
      appSnapshot: serializeProfile(mergedProfile),
      websiteSnapshot: serializeProfile(mergedProfile),
      lastSyncedFrom,
    });
    return;
  }

  await prisma.user.update({
    where: { id: appUser.id },
    data: {
      email: mergedProfile.email,
      phoneNumber: mergedProfile.phone,
      fullName: composeFullName(mergedProfile.firstName, mergedProfile.lastName),
      isActive: mergedProfile.isActive,
      websitePasswordHash: mergedProfile.passwordHash,
    },
  });

  await persistLinkState({
    appUserId: appUser.id,
    websiteClientId: websiteClient.id,
    appSnapshot: serializeProfile(mergedProfile),
    websiteSnapshot: serializeProfile(mergedProfile),
    lastSyncedFrom,
  });
}

async function reconcilePair(
  appUser: AppUserRow,
  websiteClient: WebsiteClientRow,
  link: {
    appSnapshot: string | null;
    websiteSnapshot: string | null;
    lastSyncedFrom: UserSyncSource | null;
  }
): Promise<void> {
  const appProfile = buildAppProfile(appUser);
  const websiteProfile = buildWebsiteProfile(websiteClient);
  const previousAppProfile = parseProfile(link.appSnapshot);
  const previousWebsiteProfile = parseProfile(link.websiteSnapshot);

  const { profile: mergedProfile, sourceWeights } = resolveMergedProfile(
    appProfile,
    websiteProfile,
    previousAppProfile,
    previousWebsiteProfile,
    link.lastSyncedFrom
  );

  const dominantSource = sourceWeights[UserSyncSource.WEBSITE] > sourceWeights[UserSyncSource.APP]
    ? UserSyncSource.WEBSITE
    : sourceWeights[UserSyncSource.APP] > sourceWeights[UserSyncSource.WEBSITE]
      ? UserSyncSource.APP
      : link.lastSyncedFrom ?? UserSyncSource.APP;

  try {
    await prisma.user.update({
      where: { id: appUser.id },
      data: {
        email: mergedProfile.email,
        phoneNumber: mergedProfile.phone,
        fullName: composeFullName(mergedProfile.firstName, mergedProfile.lastName),
        isActive: mergedProfile.isActive,
        websitePasswordHash: mergedProfile.passwordHash,
      },
    });

    await persistLinkState({
      appUserId: appUser.id,
      websiteClientId: websiteClient.id,
      appSnapshot: serializeProfile(mergedProfile),
      websiteSnapshot: link.websiteSnapshot,
      lastSyncedFrom: dominantSource,
    });
  } catch (error) {
    logger.warn('App user sync update failed', {
      appUserId: appUser.id,
      websiteClientId: websiteClient.id,
      error: error instanceof Error ? error.message : error,
    });
    return;
  }

  const websiteClientDb = getWebsiteClient();
  if (!websiteClientDb) {
    return;
  }

  try {
    await websiteClientDb.$executeRaw(Prisma.sql`
      UPDATE clients
      SET
        first_name = ${mergedProfile.firstName},
        last_name = ${mergedProfile.lastName},
        phone = ${mergedProfile.phone},
        email = ${mergedProfile.email || null},
        password_hash = ${mergedProfile.isActive ? mergedProfile.passwordHash : null},
        has_account = ${mergedProfile.isActive && Boolean(mergedProfile.passwordHash)},
        deleted_at = ${mergedProfile.isActive ? null : new Date()}
      WHERE id = CAST(${websiteClient.id} AS UUID)
    `);

    await persistLinkState({
      appUserId: appUser.id,
      websiteClientId: websiteClient.id,
      appSnapshot: serializeProfile(mergedProfile),
      websiteSnapshot: serializeProfile(mergedProfile),
      lastSyncedFrom: dominantSource,
    });
  } catch (error) {
    logger.warn('Website client sync update failed', {
      appUserId: appUser.id,
      websiteClientId: websiteClient.id,
      error: error instanceof Error ? error.message : error,
    });
  }
}

export async function runUserSyncOnce(): Promise<void> {
  if (isRunning) {
    return;
  }

  const websiteClientDb = getWebsiteClient();
  if (!websiteClientDb) {
    logger.info('User sync skipped - WEBSITE_DATABASE_URL is not configured');
    return;
  }

  isRunning = true;

  try {
    const [appUsers, websiteClients, links] = await Promise.all([
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
      websiteClientDb.$queryRaw<WebsiteClientRow[]>(Prisma.sql`
        SELECT id, first_name, last_name, phone, email, password_hash, has_account, deleted_at, created_at
        FROM clients
      `),
      prisma.userSyncLink.findMany({
        select: {
          appUserId: true,
          websiteClientId: true,
          appSnapshot: true,
          websiteSnapshot: true,
          lastSyncedFrom: true,
        },
      }),
    ]);

    const appUsersById = new Map(appUsers.map((user) => [user.id, user]));
    const websiteClientsById = new Map(websiteClients.map((client) => [client.id, client]));
    const appUsersByPhone = new Map<string, AppUserRow[]>();
    const appUsersByEmail = new Map<string, AppUserRow[]>();
    const websiteClientsByPhone = new Map<string, WebsiteClientRow[]>();
    const websiteClientsByEmail = new Map<string, WebsiteClientRow[]>();

    for (const user of appUsers) {
      const phoneKeys = phoneMatchKeys(user.phoneNumber);
      const emailKey = normalizeEmail(user.email);
      addIndexedValue(appUsersByPhone, phoneKeys, user);
      if (!appUsersByEmail.has(emailKey)) appUsersByEmail.set(emailKey, []);
      appUsersByEmail.get(emailKey)!.push(user);
    }

    for (const client of websiteClients) {
      const phoneKeys = phoneMatchKeys(client.phone);
      const emailKey = normalizeEmail(client.email);
      addIndexedValue(websiteClientsByPhone, phoneKeys, client);
      if (emailKey && !websiteClientsByEmail.has(emailKey)) websiteClientsByEmail.set(emailKey, []);
      if (emailKey) websiteClientsByEmail.get(emailKey)!.push(client);
    }

    const matchedAppUserIds = new Set<string>();
    const matchedWebsiteClientIds = new Set<string>();

    const matchWebsiteForApp = (appUser: AppUserRow): WebsiteClientRow | null => {
      const phoneMatches = collectIndexedValues(
        websiteClientsByPhone,
        phoneMatchKeys(appUser.phoneNumber),
        matchedWebsiteClientIds
      ).filter((client) => client.deleted_at == null);
      const emailMatches = (websiteClientsByEmail.get(normalizeEmail(appUser.email)) ?? [])
        .filter((client) => !matchedWebsiteClientIds.has(client.id) && client.deleted_at == null);
      const allPhoneMatches = collectIndexedValues(
        websiteClientsByPhone,
        phoneMatchKeys(appUser.phoneNumber),
        new Set<string>()
      ).filter((client) => client.deleted_at == null);
      const allEmailMatches = (websiteClientsByEmail.get(normalizeEmail(appUser.email)) ?? [])
        .filter((client) => client.deleted_at == null);
      const candidates = uniqueById([...phoneMatches, ...emailMatches]);
      const fallbackCandidates = uniqueById([...allPhoneMatches, ...allEmailMatches]);
      return selectBestWebsiteClient(candidates) ?? selectBestWebsiteClient(fallbackCandidates);
    };

    const matchAppForWebsite = (websiteClient: WebsiteClientRow): AppUserRow | null => {
      const phoneMatches = collectIndexedValues(
        appUsersByPhone,
        phoneMatchKeys(websiteClient.phone),
        matchedAppUserIds
      );
      const emailMatches = (appUsersByEmail.get(normalizeEmail(websiteClient.email)) ?? [])
        .filter((user) => !matchedAppUserIds.has(user.id));
      const allPhoneMatches = collectIndexedValues(
        appUsersByPhone,
        phoneMatchKeys(websiteClient.phone),
        new Set<string>()
      );
      const allEmailMatches = appUsersByEmail.get(normalizeEmail(websiteClient.email)) ?? [];
      const candidates = uniqueById([...phoneMatches, ...emailMatches]);
      const fallbackCandidates = uniqueById([...allPhoneMatches, ...allEmailMatches]);
      return selectBestAppUser(candidates) ?? selectBestAppUser(fallbackCandidates);
    };

    // Reconcile already linked users first.
    for (const link of links) {
      const appUser = appUsersById.get(link.appUserId);
      if (!appUser) {
        continue;
      }

      let websiteClient = link.websiteClientId ? websiteClientsById.get(link.websiteClientId) ?? null : null;
      if (!websiteClient) {
        websiteClient = matchWebsiteForApp(appUser);
      }

      if (!websiteClient) {
        matchedAppUserIds.add(appUser.id);
        continue;
      }

      matchedAppUserIds.add(appUser.id);
      matchedWebsiteClientIds.add(websiteClient.id);

      try {
        await reconcilePair(appUser, websiteClient, {
          appSnapshot: link.appSnapshot,
          websiteSnapshot: link.websiteSnapshot,
          lastSyncedFrom: link.lastSyncedFrom,
        });
      } catch (error) {
        logger.warn('User sync pair reconciliation failed', {
          appUserId: appUser.id,
          websiteClientId: websiteClient.id,
          error: error instanceof Error ? error.message : error,
        });
      }
    }

    // App users without a link yet.
    for (const appUser of appUsers) {
      if (matchedAppUserIds.has(appUser.id)) {
        continue;
      }

      const websiteClient = matchWebsiteForApp(appUser);
      const appProfile = buildAppProfile(appUser);

      if (websiteClient) {
        matchedAppUserIds.add(appUser.id);
        matchedWebsiteClientIds.add(websiteClient.id);

        const websiteProfile = buildWebsiteProfile(websiteClient);
        const linkSource = appUser.createdAt <= websiteClient.created_at ? UserSyncSource.APP : UserSyncSource.WEBSITE;

        try {
          await reconcilePair(appUser, websiteClient, {
            appSnapshot: serializeProfile(appProfile),
            websiteSnapshot: serializeProfile(websiteProfile),
            lastSyncedFrom: linkSource,
          });
        } catch (error) {
          logger.warn('User sync app match reconciliation failed', {
            appUserId: appUser.id,
            websiteClientId: websiteClient.id,
            error: error instanceof Error ? error.message : error,
          });
        }
        continue;
      }

      // No website row yet. Create one so the reservation backend can see the user.
      try {
        await syncAppUserToWebsite(appUser, null, appProfile, UserSyncSource.APP);
      } catch (error) {
        logger.warn('User sync app-to-website create failed', {
          appUserId: appUser.id,
          error: error instanceof Error ? error.message : error,
        });
      }
      matchedAppUserIds.add(appUser.id);
    }

    // Website clients not linked yet.
    for (const websiteClient of websiteClients) {
      if (matchedWebsiteClientIds.has(websiteClient.id)) {
        continue;
      }

      const appUser = matchAppForWebsite(websiteClient);
      const websiteProfile = buildWebsiteProfile(websiteClient);

      if (appUser) {
        matchedAppUserIds.add(appUser.id);
        matchedWebsiteClientIds.add(websiteClient.id);

        const appProfile = buildAppProfile(appUser);
        const linkSource = appUser.createdAt <= websiteClient.created_at ? UserSyncSource.APP : UserSyncSource.WEBSITE;

        try {
          await reconcilePair(appUser, websiteClient, {
            appSnapshot: serializeProfile(appProfile),
            websiteSnapshot: serializeProfile(websiteProfile),
            lastSyncedFrom: linkSource,
          });
        } catch (error) {
          logger.warn('User sync website match reconciliation failed', {
            appUserId: appUser.id,
            websiteClientId: websiteClient.id,
            error: error instanceof Error ? error.message : error,
          });
        }
        continue;
      }

      if (!websiteClient.password_hash || websiteClient.deleted_at != null) {
        continue;
      }

      try {
        await syncWebsiteClientToApp(websiteClient, null, websiteProfile, UserSyncSource.WEBSITE);
      } catch (error) {
        logger.warn('User sync website-to-app create failed', {
          websiteClientId: websiteClient.id,
          error: error instanceof Error ? error.message : error,
        });
      }
      matchedWebsiteClientIds.add(websiteClient.id);
    }

    logger.info('User sync completed', {
      appUsers: appUsers.length,
      websiteClients: websiteClients.length,
      linkedUsers: links.length,
    });
  } catch (error) {
    logger.error('User sync job failed', {
      error: error instanceof Error ? error.message : error,
    });
  } finally {
    isRunning = false;
  }
}

export function startUserSyncJob(): void {
  if (intervalId) {
    return;
  }

  const websiteClient = getWebsiteClient();
  if (!websiteClient) {
    logger.info('User sync job disabled - WEBSITE_DATABASE_URL not configured');
    return;
  }

  intervalId = setInterval(() => {
    void runUserSyncOnce();
  }, INTERVAL_MS);

  logger.info('User sync job started', { intervalMinutes: INTERVAL_MS / 60000 });
  void runUserSyncOnce();
}

export function stopUserSyncJob(): void {
  if (!intervalId) {
    return;
  }

  clearInterval(intervalId);
  intervalId = null;
  logger.info('User sync job stopped');
}
