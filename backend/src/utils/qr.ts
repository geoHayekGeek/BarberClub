/**
 * QR token utilities
 * Standardized QR payload format: BC|v1|<type>|<token>
 */

import { randomBytes, createHash } from 'crypto';
import config from '../config';

export enum QRType {
  /** Legacy: point scan (old loyalty) */
  POINT = 'P',
  /** Legacy: coupon redeem (old loyalty) */
  COUPON = 'C',
  /** New: earn QR (user shows, admin scans after selecting service) */
  EARN = 'E',
  /** New: voucher redeem QR (user redeems reward -> gets voucher QR -> admin scans) */
  VOUCHER = 'V',
}

export interface QRPayload {
  type: QRType;
  token: string;
}

const QR_PREFIX = 'BC';
const QR_VERSION = 'v1';

/**
 * Generate a URL-safe token
 */
export function generateToken(): string {
  return randomBytes(32).toString('hex');
}

/**
 * Hash token with pepper for storage
 */
export function hashToken(token: string): string {
  return createHash('sha256')
    .update(token + config.QR_TOKEN_PEPPER)
    .digest('hex');
}

/**
 * Encode QR payload: BC|v1|<type>|<token>
 */
export function encodeQRPayload(type: QRType, token: string): string {
  return `${QR_PREFIX}|${QR_VERSION}|${type}|${token}`;
}

/**
 * Parse QR payload: BC|v1|<type>|<token>
 * Returns null if invalid format
 */
export function parseQRPayload(payload: string): QRPayload | null {
  const trimmed = payload.trim();
  const parts = trimmed.split('|');

  if (parts.length !== 4) {
    return null;
  }

  const [prefix, version, typeRaw, token] = parts;

  if (prefix !== QR_PREFIX || version !== QR_VERSION) {
    return null;
  }

  const validTypes = [QRType.POINT, QRType.COUPON, QRType.EARN, QRType.VOUCHER];
  if (!validTypes.includes(typeRaw as QRType)) {
    return null;
  }

  if (!token || token.length < 8) {
    return null;
  }

  return {
    type: typeRaw as QRType,
    token,
  };
}
