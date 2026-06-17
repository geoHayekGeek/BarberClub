/**
 * Password hashing utilities for app auth and website sync.
 */

import argon2 from 'argon2';
import bcrypt from 'bcryptjs';

const WEBSITE_BCRYPT_ROUNDS = 12;

export function isBcryptHash(hash: string): boolean {
  return /^\$2[aby]\$\d{2}\$/.test(hash);
}

export function isArgon2Hash(hash: string): boolean {
  return hash.startsWith('$argon2');
}

export async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 4,
  });
}

export async function hashWebsitePassword(password: string): Promise<string> {
  return bcrypt.hash(password, WEBSITE_BCRYPT_ROUNDS);
}

export async function verifyPassword(
  hash: string,
  password: string
): Promise<boolean> {
  try {
    if (isBcryptHash(hash)) {
      return await bcrypt.compare(password, hash);
    }

    if (isArgon2Hash(hash)) {
      return await argon2.verify(hash, password);
    }

    const bcryptValid = await bcrypt.compare(password, hash);
    if (bcryptValid) {
      return true;
    }

    return await argon2.verify(hash, password);
  } catch {
    return false;
  }
}

export async function verifyPasswordAgainstAnyHash(
  password: string,
  hashes: Array<string | null | undefined>
): Promise<boolean> {
  for (const hash of hashes) {
    if (!hash) continue;
    if (await verifyPassword(hash, password)) {
      return true;
    }
  }

  return false;
}
