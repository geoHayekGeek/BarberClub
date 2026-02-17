/**
 * QR utility tests
 */

import { generateToken, hashToken, encodeQRPayload, parseQRPayload, QRType } from '../src/utils/qr';

describe('QR Utilities', () => {
  describe('generateToken', () => {
    it('should generate 64 character hex token', () => {
      const token = generateToken();
      expect(token).toHaveLength(64);
      expect(token).toMatch(/^[0-9a-f]+$/);
    });

    it('should generate unique tokens', () => {
      const token1 = generateToken();
      const token2 = generateToken();
      expect(token1).not.toBe(token2);
    });
  });

  describe('hashToken', () => {
    it('should hash token consistently', () => {
      const token = 'abc123';
      const hash1 = hashToken(token);
      const hash2 = hashToken(token);
      expect(hash1).toBe(hash2);
    });

    it('should produce different hashes for different tokens', () => {
      const hash1 = hashToken('token1');
      const hash2 = hashToken('token2');
      expect(hash1).not.toBe(hash2);
    });

    it('should produce 64 character hex hash', () => {
      const hash = hashToken('test');
      expect(hash).toHaveLength(64);
      expect(hash).toMatch(/^[0-9a-f]+$/);
    });
  });

  describe('encodeQRPayload', () => {
    it('should encode point type correctly', () => {
      const token = 'abc123def456';
      const payload = encodeQRPayload(QRType.POINT, token);
      expect(payload).toBe('BC|v1|P|abc123def456');
    });

    it('should encode coupon type correctly', () => {
      const token = 'xyz789ghi012';
      const payload = encodeQRPayload(QRType.COUPON, token);
      expect(payload).toBe('BC|v1|C|xyz789ghi012');
    });
  });

  describe('parseQRPayload', () => {
    it('should parse valid point payload', () => {
      const payload = 'BC|v1|P|abc123def456';
      const result = parseQRPayload(payload);
      expect(result).not.toBeNull();
      expect(result?.type).toBe(QRType.POINT);
      expect(result?.token).toBe('abc123def456');
    });

    it('should parse valid coupon payload', () => {
      const payload = 'BC|v1|C|xyz789ghi012';
      const result = parseQRPayload(payload);
      expect(result).not.toBeNull();
      expect(result?.type).toBe(QRType.COUPON);
      expect(result?.token).toBe('xyz789ghi012');
    });

    it('should handle leading/trailing whitespace', () => {
      const payload = '  BC|v1|P|abc123def456  \n';
      const result = parseQRPayload(payload);
      expect(result).not.toBeNull();
      expect(result?.token).toBe('abc123def456');
    });

    it('should reject invalid prefix', () => {
      const payload = 'XY|v1|P|abc123def456';
      const result = parseQRPayload(payload);
      expect(result).toBeNull();
    });

    it('should reject invalid version', () => {
      const payload = 'BC|v2|P|abc123def456';
      const result = parseQRPayload(payload);
      expect(result).toBeNull();
    });

    it('should reject invalid type', () => {
      const payload = 'BC|v1|X|abc123def456';
      const result = parseQRPayload(payload);
      expect(result).toBeNull();
    });

    it('should reject token too short', () => {
      const payload = 'BC|v1|P|short';
      const result = parseQRPayload(payload);
      expect(result).toBeNull();
    });

    it('should reject wrong number of parts', () => {
      const payload = 'BC|v1|P';
      const result = parseQRPayload(payload);
      expect(result).toBeNull();
    });

    it('should reject empty string', () => {
      const result = parseQRPayload('');
      expect(result).toBeNull();
    });
  });
});
