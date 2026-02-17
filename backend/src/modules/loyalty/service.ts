/**
 * Loyalty service
 * Handles loyalty card business logic and QR code redemption
 */

import { randomBytes } from 'crypto';
import prisma from '../../db/client';
import { getMessaging } from '../../config/firebase';
import { AppError, ErrorCode } from '../../utils/errors';
import { logger } from '../../utils/logger';
import config from '../../config';
import { generateToken, hashToken, encodeQRPayload, parseQRPayload, QRType } from '../../utils/qr';

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

  async generateCouponQr(userId: string, couponId: string): Promise<{ qrPayload: string; expiresAt: string }> {
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

    const token = generateToken();
    const tokenHash = this.hashToken(token);
    const expiresAt = new Date(Date.now() + config.LOYALTY_QR_TTL_SECONDS * 1000);

    await prisma.loyaltyCoupon.update({
      where: { id: couponId },
      data: {
        qrTokenHash: tokenHash,
        qrExpiresAt: expiresAt,
        qrUsedAt: null,
      },
    });

    const qrPayload = encodeQRPayload(QRType.COUPON, token);

    logger.info('Coupon QR generated', {
      userId,
      couponId,
      expiresAt: expiresAt.toISOString(),
    });

    return {
      qrPayload,
      expiresAt: expiresAt.toISOString(),
    };
  }

  async redeemCoupon(qrPayload: string): Promise<{ success: boolean }> {
    const parsed = parseQRPayload(qrPayload);

    if (!parsed || parsed.type !== QRType.COUPON) {
      logger.warn('COUPON_REDEEM invalid_format', { payloadLength: qrPayload.length });
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
        400
      );
    }

    const tokenHash = this.hashToken(parsed.token);

    const coupon = await prisma.loyaltyCoupon.findFirst({
      where: {
        qrTokenHash: tokenHash,
        redeemedAt: null,
      },
    });

    if (!coupon) {
      logger.warn('COUPON_REDEEM token_not_found_or_used');
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
        400
      );
    }

    if (!coupon.qrExpiresAt || coupon.qrExpiresAt <= new Date()) {
      logger.warn('COUPON_REDEEM token_expired', { userId: coupon.userId });
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
        400
      );
    }

    if (coupon.qrUsedAt) {
      logger.warn('COUPON_REDEEM qr_already_used', { userId: coupon.userId });
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
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

  async redeem(userId: string): Promise<{ success: boolean }> {
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

    logger.info('Loyalty reward redeemed', {
      userId,
      oldStamps: stamps,
      newStamps,
    });

    return { success: true };
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
    return hashToken(token);
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
  async generateQrToken(userId: string): Promise<{ qrPayload: string; expiresAt: string }> {
    const token = generateToken();
    const tokenHash = this.hashToken(token);
    const expiresAt = new Date(Date.now() + config.LOYALTY_QR_TTL_SECONDS * 1000);

    await prisma.loyaltyQrToken.create({
      data: {
        userId,
        tokenHash,
        expiresAt,
      },
    });

    const qrPayload = encodeQRPayload(QRType.POINT, token);

    logger.info('Loyalty QR token generated', {
      userId,
      expiresAt: expiresAt.toISOString(),
    });

    return {
      qrPayload,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /** V1 minimal flow: admin scans QR token, validate and increment user.loyaltyPoints. */
  async scanQrTokenByAdmin(qrPayload: string): Promise<{ success: boolean; rewardEarned: boolean }> {
    const parsed = parseQRPayload(qrPayload);

    if (!parsed || parsed.type !== QRType.POINT) {
      logger.warn('LOYALTY_SCAN invalid_format', { payloadLength: qrPayload.length });
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
        400
      );
    }

    const tokenHash = this.hashToken(parsed.token);

    const record = await prisma.loyaltyQrToken.findFirst({
      where: { tokenHash },
      include: { user: true },
    });

    if (!record) {
      logger.warn('LOYALTY_SCAN token_not_found');
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
        400
      );
    }

    if (record.usedAt) {
      logger.warn('LOYALTY_SCAN token_used', { userId: record.userId });
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
        400
      );
    }

    if (record.expiresAt <= new Date()) {
      logger.warn('LOYALTY_SCAN token_expired', { userId: record.userId });
      throw new AppError(
        ErrorCode.INVALID_OR_EXPIRED_QR,
        'QR code invalide',
        400
      );
    }

    let rewardEarned = false;
    let newPoints = 0;

    await prisma.$transaction(async (tx) => {
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
    logger.info('FCM notification check', {
      userId: record.userId,
      hasFcmToken: !!fcmToken,
      rewardEarned,
    });

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

          logger.info('Sending FCM notification', {
            userId: record.userId,
            type: notificationData.type,
            title: notificationData.title,
          });

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
        } else {
          logger.warn('Firebase messaging not initialized');
        }
      } catch (err) {
        logger.warn('FCM push failed', {
          userId: record.userId,
          error: err instanceof Error ? err.message : err,
        });
      }
    } else {
      logger.info('No FCM token for user, skip push', { userId: record.userId });
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
