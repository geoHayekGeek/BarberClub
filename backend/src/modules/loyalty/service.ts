/**
 * Loyalty service
 * Handles loyalty card business logic and QR code redemption
 */

import { randomBytes, createHash } from 'crypto';
import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';
import { logger } from '../../utils/logger';
import config from '../../config';

export interface LoyaltyStateResponse {
  stamps: number;
  target: number;
  remaining: number;
  eligibleForReward: boolean;
}

export interface QRCodeResponse {
  qrPayload: string;
  expiresAt: string;
}

export interface ScanResponse {
  status: string;
  resetStamps: boolean;
}

class LoyaltyService {
  async getState(userId: string): Promise<LoyaltyStateResponse> {
    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    const stamps = loyaltyState?.stamps ?? 0;
    const target = config.LOYALTY_TARGET;
    const eligibleForReward = stamps >= target;
    const remaining = Math.max(0, target - stamps);

    return {
      stamps,
      target,
      eligibleForReward,
      remaining,
    };
  }

  async redeem(userId: string): Promise<LoyaltyStateResponse> {
    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    const stamps = loyaltyState?.stamps ?? 0;
    const target = config.LOYALTY_TARGET;

    if (stamps < target) {
      throw new AppError(
        ErrorCode.BOOKING_VALIDATION_ERROR,
        'Not enough stamps to redeem reward',
        400
      );
    }

    const newStamps = stamps - target;

    const updated = await prisma.loyaltyState.upsert({
      where: { userId },
      update: {
        stamps: newStamps,
      },
      create: {
        userId,
        stamps: newStamps,
      },
    });

    logger.info('Loyalty reward redeemed', {
      userId,
      oldStamps: stamps,
      newStamps: updated.stamps,
    });

    return {
      stamps: updated.stamps,
      target,
      eligibleForReward: updated.stamps >= target,
      remaining: Math.max(0, target - updated.stamps),
    };
  }

  async incrementStamps(userId: string): Promise<void> {
    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    const currentStamps = loyaltyState?.stamps ?? 0;
    const newStamps = currentStamps + 1;

    await prisma.loyaltyState.upsert({
      where: { userId },
      update: {
        stamps: newStamps,
      },
      create: {
        userId,
        stamps: newStamps,
      },
    });

    logger.info('Loyalty stamps incremented', {
      userId,
      oldStamps: currentStamps,
      newStamps,
    });
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  async generateQR(userId: string): Promise<QRCodeResponse> {
    const loyaltyState = await prisma.loyaltyState.findUnique({
      where: { userId },
    });

    const stamps = loyaltyState?.stamps ?? 0;
    const target = config.LOYALTY_TARGET;

    if (stamps < target) {
      throw new AppError(
        ErrorCode.LOYALTY_NOT_READY,
        'Loyalty target not reached',
        400
      );
    }

    const rawToken = randomBytes(32).toString('hex');
    const tokenHash = this.hashToken(rawToken);
    const expiresAt = new Date(Date.now() + config.LOYALTY_QR_TTL_SECONDS * 1000);

    await prisma.$transaction(async (tx) => {
      await tx.loyaltyRedemptionToken.updateMany({
        where: {
          userId,
          usedAt: null,
          expiresAt: {
            gt: new Date(),
          },
        },
        data: {
          usedAt: new Date(),
        },
      });

      await tx.loyaltyRedemptionToken.create({
        data: {
          userId,
          tokenHash,
          expiresAt,
        },
      });

      logger.info('QR code generated', {
        userId,
        expiresAt: expiresAt.toISOString(),
      });
    });

    const qrPayload = `LOYALTY:${rawToken}`;

    return {
      qrPayload,
      expiresAt: expiresAt.toISOString(),
    };
  }

  async scanQR(qrPayload: string): Promise<ScanResponse> {
    if (!qrPayload.startsWith('LOYALTY:')) {
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code is invalid or expired',
        400
      );
    }

    const rawToken = qrPayload.substring(8);
    const tokenHash = this.hashToken(rawToken);

    const token = await prisma.loyaltyRedemptionToken.findFirst({
      where: {
        tokenHash,
        usedAt: null,
        expiresAt: {
          gt: new Date(),
        },
      },
    });

    if (!token) {
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code is invalid or expired',
        400
      );
    }

    const result = await prisma.$transaction(async (tx) => {
      const existingToken = await tx.loyaltyRedemptionToken.findUnique({
        where: { id: token.id },
      });

      if (!existingToken || existingToken.usedAt || existingToken.expiresAt <= new Date()) {
        throw new AppError(
          ErrorCode.INVALID_OR_EXPIRED_QR,
          'QR code is invalid or expired',
          400
        );
      }

      await tx.loyaltyRedemptionToken.update({
        where: { id: token.id },
        data: { usedAt: new Date() },
      });

      const loyaltyState = await tx.loyaltyState.findUnique({
        where: { userId: token.userId },
      });

      const previousStamps = loyaltyState?.stamps ?? 0;

      await tx.loyaltyRedemption.create({
        data: {
          userId: token.userId,
          previousStamps,
        },
      });

      await tx.loyaltyState.update({
        where: { userId: token.userId },
        data: {
          stamps: 0,
        },
      });

      logger.info('Loyalty QR code redeemed', {
        userId: token.userId,
        previousStamps,
        tokenId: token.id,
      });

      return { resetStamps: true };
    });

    return {
      status: 'redeemed',
      resetStamps: result.resetStamps,
    };
  }
}

export const loyaltyService = new LoyaltyService();
