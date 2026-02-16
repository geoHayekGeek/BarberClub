/**
 * Loyalty service
 * Handles loyalty card business logic and QR code redemption
 */

import { randomBytes, createHash } from 'crypto';
import prisma from '../../db/client';
import { getMessaging } from '../../config/firebase';
import { AppError, ErrorCode } from '../../utils/errors';
import { logger } from '../../utils/logger';
import config from '../../config';

export interface LoyaltyStateResponse {
  points: number;
  target: number;
  availableCoupons: number;
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
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { loyaltyPoints: true },
    });
    
    const availableCouponsCount = await prisma.loyaltyCoupon.count({
      where: {
        userId,
        redeemedAt: null,
      },
    });

    return {
      points: user?.loyaltyPoints ?? 0,
      target: config.LOYALTY_TARGET,
      availableCoupons: availableCouponsCount,
    };
  }

  async getCoupons(userId: string) {
    return prisma.loyaltyCoupon.findMany({
      where: {
        userId,
        redeemedAt: null,
      },
      select: {
        id: true,
        createdAt: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async generateCouponQr(userId: string, couponId: string): Promise<{ token: string; expiresAt: string }> {
    const coupon = await prisma.loyaltyCoupon.findFirst({
      where: {
        id: couponId,
        userId,
        redeemedAt: null,
      },
    });

    if (!coupon) {
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'Coupon introuvable ou déjà utilisé',
        404
      );
    }

    const raw = randomBytes(16).toString('hex');
    const payload = `COUPON_QR:${raw}`;
    const tokenHash = this.hashToken(payload);
    const expiresAt = new Date(Date.now() + config.LOYALTY_QR_TTL_SECONDS * 1000);

    await prisma.loyaltyCoupon.update({
      where: { id: couponId },
      data: {
        qrTokenHash: tokenHash,
        qrExpiresAt: expiresAt,
        qrUsedAt: null,
      },
    });

    logger.info('Coupon QR generated', {
      userId,
      couponId,
      expiresAt: expiresAt.toISOString(),
    });

    return {
      token: payload,
      expiresAt: expiresAt.toISOString(),
    };
  }

  async redeemCoupon(token: string): Promise<{ success: boolean }> {
    const tokenHash = this.hashToken(token);

    const coupon = await prisma.loyaltyCoupon.findFirst({
      where: {
        qrTokenHash: tokenHash,
        redeemedAt: null,
      },
    });

    if (!coupon) {
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide ou déjà utilisé',
        400
      );
    }

    if (!coupon.qrExpiresAt || coupon.qrExpiresAt <= new Date()) {
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code expiré',
        400
      );
    }

    if (coupon.qrUsedAt) {
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code déjà utilisé',
        400
      );
    }

    await prisma.loyaltyCoupon.update({
      where: { id: coupon.id },
      data: {
        redeemedAt: new Date(),
        qrUsedAt: new Date(),
      },
    });

    logger.info('Coupon redeemed', {
      userId: coupon.userId,
      couponId: coupon.id,
    });

    return { success: true };
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

  /** V1 minimal flow: generate short-lived QR token for loyalty point scan (USER only). */
  async generateQrToken(userId: string): Promise<{ token: string; expiresAt: string }> {
    const raw = randomBytes(8).toString('hex');
    const payload = `LOYALTY_QR:${raw}`;
    const tokenHash = this.hashToken(payload);
    const expiresAt = new Date(Date.now() + 2 * 60 * 1000); // 2 minutes

    await prisma.loyaltyQrToken.create({
      data: {
        userId,
        tokenHash,
        expiresAt,
      },
    });

    logger.info('Loyalty QR token generated', {
      userId,
      expiresAt: expiresAt.toISOString(),
      tokenForTesting: process.env.NODE_ENV !== 'production' ? payload : undefined,
    });
    return {
      token: payload,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /** V1 minimal flow: admin scans QR token, validate and increment user.loyaltyPoints. */
  async scanQrTokenByAdmin(token: string): Promise<{ success: boolean; rewardEarned: boolean }> {
    const tokenHash = this.hashToken(token);

    const record = await prisma.loyaltyQrToken.findFirst({
      where: { tokenHash },
      include: { user: true },
    });

    if (!record || record.usedAt || record.expiresAt <= new Date()) {
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code is invalid or expired',
        400
      );
    }

    let rewardEarned = false;
    let newPoints = 0;

    await prisma.$transaction(async (tx) => {
      const current = await tx.loyaltyQrToken.findUnique({
        where: { id: record.id },
      });
      if (!current || current.usedAt || current.expiresAt <= new Date()) {
        throw new AppError(
          ErrorCode.INVALID_OR_EXPIRED_QR,
          'QR code is invalid or expired',
          400
        );
      }
      
      await tx.loyaltyQrToken.update({
        where: { id: record.id },
        data: { usedAt: new Date() },
      });

      const updatedUser = await tx.user.update({
        where: { id: record.userId },
        data: { loyaltyPoints: { increment: 1 } },
        select: { loyaltyPoints: true },
      });

      newPoints = updatedUser.loyaltyPoints;

      if (newPoints >= config.LOYALTY_TARGET) {
        await tx.loyaltyCoupon.create({
          data: {
            userId: record.userId,
          },
        });

        await tx.user.update({
          where: { id: record.userId },
          data: { loyaltyPoints: 0 },
        });

        rewardEarned = true;
        newPoints = 0;
      }
    });

    logger.info('Loyalty QR token scanned', {
      userId: record.userId,
      newPoints,
      rewardEarned,
    });

    const fcmToken = record.user?.fcmToken;
    if (fcmToken) {
      try {
        const messaging = getMessaging();
        if (messaging) {
          const notificationData = rewardEarned
            ? {
                title: 'Récompense débloquée',
                body: 'Votre coupe offerte est disponible.',
                type: 'LOYALTY_REWARD',
              }
            : {
                title: 'Point fidélité ajouté',
                body: 'Votre carte fidélité a été mise à jour.',
                type: 'LOYALTY_POINT',
              };

          await messaging.send({
            token: fcmToken,
            notification: {
              title: notificationData.title,
              body: notificationData.body,
            },
            data: {
              type: notificationData.type,
            },
          });
          
          logger.info('FCM push sent', {
            userId: record.userId,
            type: notificationData.type,
          });
        }
      } catch (err) {
        logger.warn('FCM push failed', {
          userId: record.userId,
          error: err instanceof Error ? err.message : err,
        });
      }
    }

    return { success: true, rewardEarned };
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
