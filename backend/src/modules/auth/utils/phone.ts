/**
 * Phone number normalization and validation
 * Converts to E.164 format
 */

import { z } from 'zod';

const phoneSchema = z.string().regex(
  /^\+?[1-9]\d{1,14}$/,
  'Phone number must be in E.164 format'
);

export function normalizePhoneNumber(phone: string): string {
  let normalized = phone.trim().replace(/\s+/g, '');

  if (!normalized.startsWith('+')) {
    if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }
    normalized = '+' + normalized;
  }

  return normalized;
}

export function validatePhoneNumber(phone: string): string {
  const normalized = normalizePhoneNumber(phone);
  const result = phoneSchema.safeParse(normalized);
  
  if (!result.success) {
    throw new Error('Invalid phone number format. Must be in E.164 format (e.g., +1234567890)');
  }

  return normalized;
}
