/**
 * Loyalty v2 service: points-as-currency, tiers, rewards catalog, transactions.
 */

import prisma from '../../db/client';
import { getMessaging } from '../../config/firebase';
import { AppError, ErrorCode } from '../../utils/errors';
import { logger } from '../../utils/logger';
import config from '../../config';
import { generateToken, hashToken, encodeQRPayload, parseQRPayload, QRType } from '../../utils/qr';
import { getTierFromLifetime, getNextTier, getCheapestRewardCost, type LoyaltyTierName } from './tiers';

const VOUCHER_QR_TTL_SECONDS = 30 * 24 * 60 * 60; // 30 days
const NEAR_REWARD_THRESHOLD = 20;

export interface LoyaltyMeResponse {
  currentBalance: number;
  lifetimeEarned: number;
  tier: LoyaltyTierName;
  enrolledAt: string;
  nextTier: { name: LoyaltyTierName; remainingPoints: number } | null;
}

export interface LoyaltyRewardDto {
  id: string;
  name: string;
  costPoints: number;
  description: string | null;
  imageUrl: string | null;
  isActive: boolean;
}

export interface LoyaltyTransactionDto {
  id: string;
  type: string;
  points: number;
  description: string;
  createdAt: string;
}

export interface AdminEarnResponse {
  pointsEarned: number;
  newBalance: number;
  newLifetime: number;
  newTier: LoyaltyTierName;
}

export async function ensureLoyaltyAccount(userId: string): Promise<{ id: string }> {
  const existing = await prisma.loyaltyAccount.findUnique({
    where: { userId },
    select: { id: true },
  });
  if (existing) return existing;
  const created = await prisma.loyaltyAccount.create({
    data: { userId },
    select: { id: true },
  });
  logger.info('LoyaltyAccount created', { userId, accountId: created.id });
  return created;
}

export async function getLoyaltyState(userId: string): Promise<LoyaltyMeResponse> {
  await ensureLoyaltyAccount(userId);
  const account = await prisma.loyaltyAccount.findUnique({
    where: { userId },
  });
  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);
  const tier = getTierFromLifetime(account.lifetimeEarned);
  const nextTier = getNextTier(account.lifetimeEarned);
  return {
    currentBalance: account.currentBalance,
    lifetimeEarned: account.lifetimeEarned,
    tier,
    enrolledAt: account.enrolledAt.toISOString(),
    nextTier: nextTier ? { name: nextTier.name, remainingPoints: nextTier.remainingPoints } : null,
  };
}

export async function generateEarnQr(userId: string): Promise<{ qrPayload: string; expiresAt: string }> {
  const { id: accountId } = await ensureLoyaltyAccount(userId);
  const token = generateToken();
  const tokenHash = hashToken(token);
  const expiresAt = new Date(Date.now() + config.LOYALTY_QR_TTL_SECONDS * 1000);
  await prisma.loyaltyAccountQrToken.create({
    data: { accountId, tokenHash, expiresAt },
  });
  const qrPayload = encodeQRPayload(QRType.EARN, token);
  return { qrPayload, expiresAt: expiresAt.toISOString() };
}

export async function listActiveRewards(): Promise<LoyaltyRewardDto[]> {
  const rows = await prisma.loyaltyReward.findMany({
    where: { isActive: true },
    orderBy: { costPoints: 'asc' },
  });
  return rows.map((r) => ({
    id: r.id,
    name: r.name,
    costPoints: r.costPoints,
    description: r.description,
    imageUrl: r.imageUrl,
    isActive: r.isActive,
  }));
}

export async function redeemReward(userId: string, rewardId: string): Promise<{
  redemptionId: string;
  rewardName: string;
  pointsSpent: number;
  newBalance: number;
}> {
  await ensureLoyaltyAccount(userId);
  const account = await prisma.loyaltyAccount.findUnique({ where: { userId } });
  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);
  const reward = await prisma.loyaltyReward.findFirst({
    where: { id: rewardId, isActive: true },
  });
  if (!reward) throw new AppError(ErrorCode.NOT_FOUND, 'Reward not found or inactive', 404);
  if (account.currentBalance < reward.costPoints) {
    throw new AppError(ErrorCode.INSUFFICIENT_POINTS, 'Points insuffisants', 400);
  }
  const updated = await prisma.$transaction(async (tx) => {
    const acc = await tx.loyaltyAccount.update({
      where: { id: account.id },
      data: { currentBalance: { decrement: reward.costPoints } },
      select: { currentBalance: true },
    });
    const redemption = await tx.loyaltyRedemptionVoucher.create({
      data: {
        accountId: account.id,
        rewardId: reward.id,
        pointsSpent: reward.costPoints,
        status: 'PENDING',
      },
    });
    await tx.loyaltyTransaction.create({
      data: {
        accountId: account.id,
        type: 'REDEEM',
        points: -reward.costPoints,
        description: reward.name,
        referenceId: redemption.id,
      },
    });
    return { newBalance: acc.currentBalance, redemptionId: redemption.id, rewardName: reward.name, pointsSpent: reward.costPoints };
  });
  return {
    redemptionId: updated.redemptionId,
    rewardName: updated.rewardName,
    pointsSpent: updated.pointsSpent,
    newBalance: updated.newBalance,
  };
}

export async function generateVoucherQr(
  userId: string,
  redemptionId: string
): Promise<{ qrPayload: string; expiresAt: string }> {
  await ensureLoyaltyAccount(userId);
  const account = await prisma.loyaltyAccount.findUnique({ where: { userId } });
  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);
  const redemption = await prisma.loyaltyRedemptionVoucher.findFirst({
    where: { id: redemptionId, accountId: account.id, status: 'PENDING' },
  });
  if (!redemption) throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'Bon invalide ou déjà utilisé', 404);
  const token = generateToken();
  const tokenHash = hashToken(token);
  const expiresAt = new Date(Date.now() + VOUCHER_QR_TTL_SECONDS * 1000);
  await prisma.loyaltyRedemptionVoucher.update({
    where: { id: redemptionId },
    data: { qrTokenHash: tokenHash, qrExpiresAt: expiresAt, qrUsedAt: null },
  });
  const qrPayload = encodeQRPayload(QRType.VOUCHER, token);
  return { qrPayload, expiresAt: expiresAt.toISOString() };
}

export async function listTransactions(userId: string, limit: number): Promise<LoyaltyTransactionDto[]> {
  await ensureLoyaltyAccount(userId);
  const account = await prisma.loyaltyAccount.findUnique({ where: { userId } });
  if (!account) return [];
  const rows = await prisma.loyaltyTransaction.findMany({
    where: { accountId: account.id },
    orderBy: { createdAt: 'desc' },
    take: Math.min(limit, 50),
  });
  return rows.map((r) => ({
    id: r.id,
    type: r.type,
    points: r.points,
    description: r.description,
    createdAt: r.createdAt.toISOString(),
  }));
}

export async function listRedemptions(userId: string): Promise<
  { id: string; rewardName: string; pointsSpent: number; status: string; redeemedAt: string; usedAt: string | null }[]
> {
  await ensureLoyaltyAccount(userId);
  const account = await prisma.loyaltyAccount.findUnique({ where: { userId } });
  if (!account) return [];
  const rows = await prisma.loyaltyRedemptionVoucher.findMany({
    where: { accountId: account.id },
    include: { reward: true },
    orderBy: { redeemedAt: 'desc' },
  });
  return rows.map((r) => ({
    id: r.id,
    rewardName: r.reward.name,
    pointsSpent: r.pointsSpent,
    status: r.status,
    redeemedAt: r.redeemedAt.toISOString(),
    usedAt: r.usedAt?.toISOString() ?? null,
  }));
}

/** Admin: earn points by scanning user earn QR after selecting a service. */
export async function adminEarnPoints(qrPayload: string, serviceId: string): Promise<AdminEarnResponse> {
  const parsed = parseQRPayload(qrPayload);
  if (!parsed || parsed.type !== QRType.EARN) {
    logger.warn('LOYALTY_EARN invalid_format', { payloadLength: qrPayload.length });
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }
  const tokenHash = hashToken(parsed.token);
  const tokenRecord = await prisma.loyaltyAccountQrToken.findFirst({
    where: { tokenHash },
    include: { account: { include: { user: true } } },
  });
  if (!tokenRecord) {
    logger.warn('LOYALTY_EARN token_not_found');
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }
  if (tokenRecord.usedAt) {
    logger.warn('LOYALTY_EARN token_used', { accountId: tokenRecord.accountId });
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }
  if (tokenRecord.expiresAt <= new Date()) {
    logger.warn('LOYALTY_EARN token_expired', { accountId: tokenRecord.accountId });
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }
  const offer = await prisma.offer.findFirst({
    where: { id: serviceId, isActive: true },
  });
  if (!offer) throw new AppError(ErrorCode.OFFER_NOT_FOUND, 'Service introuvable', 404);
  // 1 point per euro. DB may store price in euros (e.g. 25) or cents (e.g. 2500).
  const pointsEarned = offer.price < 100 ? offer.price : Math.floor(offer.price / 100);
  if (pointsEarned <= 0) throw new AppError(ErrorCode.VALIDATION_ERROR, 'Montant invalide pour ce service', 400);

  const accountId = tokenRecord.accountId;
  const previousTier = getTierFromLifetime(tokenRecord.account.lifetimeEarned);

  await prisma.$transaction(async (tx) => {
    await tx.loyaltyAccountQrToken.update({
      where: { id: tokenRecord.id },
      data: { usedAt: new Date() },
    });
    const acc = await tx.loyaltyAccount.update({
      where: { id: accountId },
      data: {
        currentBalance: { increment: pointsEarned },
        lifetimeEarned: { increment: pointsEarned },
      },
      select: { currentBalance: true, lifetimeEarned: true },
    });
    await tx.loyaltyTransaction.create({
      data: {
        accountId,
        type: 'EARN',
        points: pointsEarned,
        description: offer.title,
        referenceId: serviceId,
      },
    });
    return acc;
  });

  const account = await prisma.loyaltyAccount.findUnique({
    where: { id: accountId },
    select: { currentBalance: true, lifetimeEarned: true },
  });
  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);
  const newTier = getTierFromLifetime(account.lifetimeEarned);
  const user = tokenRecord.account.user;
  const fcmToken = user?.fcmToken;

  if (fcmToken) {
    try {
      const messaging = getMessaging();
      if (messaging) {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: 'Points fidélité',
            body: `+${pointsEarned} points. Solde: ${account.currentBalance} pts`,
          },
          data: {
            type: 'LOYALTY_EARN',
            pointsEarned: String(pointsEarned),
            newBalance: String(account.currentBalance),
          },
        });
        if (newTier !== previousTier) {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: 'Nouveau statut',
              body: `Vous êtes passé ${newTier}`,
            },
            data: { type: 'LOYALTY_TIER', tier: newTier },
          });
        }
        const rewards = await prisma.loyaltyReward.findMany({ where: { isActive: true }, select: { costPoints: true } });
        const cheapest = getCheapestRewardCost(rewards);
        if (cheapest != null) {
          const gap = cheapest - account.currentBalance;
          if (gap > 0 && gap <= NEAR_REWARD_THRESHOLD) {
            await messaging.send({
              token: fcmToken,
              notification: {
                title: 'Bientôt une récompense',
                body: `Plus que ${gap} points pour une récompense`,
              },
              data: { type: 'LOYALTY_NEAR_REWARD' },
            });
          }
        }
      }
    } catch (err) {
      logger.warn('FCM push failed LOYALTY_EARN', { accountId, error: err instanceof Error ? err.message : err });
    }
  }

  return {
    pointsEarned,
    newBalance: account.currentBalance,
    newLifetime: account.lifetimeEarned,
    newTier,
  };
}

/** Admin: validate voucher QR and mark redemption as USED. */
export async function adminRedeemVoucher(qrPayload: string): Promise<{ success: boolean; rewardName: string; newBalance: number }> {
  const parsed = parseQRPayload(qrPayload);
  if (!parsed || parsed.type !== QRType.VOUCHER) {
    logger.warn('VOUCHER_REDEEM invalid_format', { payloadLength: qrPayload.length });
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }
  const tokenHash = hashToken(parsed.token);
  const redemption = await prisma.loyaltyRedemptionVoucher.findFirst({
    where: { qrTokenHash: tokenHash, status: 'PENDING' },
    include: { account: { include: { user: true } }, reward: true },
  });
  if (!redemption) {
    logger.warn('VOUCHER_REDEEM not_found');
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }
  if (redemption.qrExpiresAt && redemption.qrExpiresAt <= new Date()) {
    logger.warn('VOUCHER_REDEEM expired', { redemptionId: redemption.id });
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }
  if (redemption.qrUsedAt) {
    logger.warn('VOUCHER_REDEEM already_used', { redemptionId: redemption.id });
    throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR code invalide', 400);
  }

  await prisma.loyaltyRedemptionVoucher.update({
    where: { id: redemption.id },
    data: { status: 'USED', usedAt: new Date(), qrUsedAt: new Date() },
  });

  const account = await prisma.loyaltyAccount.findUnique({
    where: { id: redemption.accountId },
    select: { currentBalance: true },
  });
  const newBalance = account?.currentBalance ?? 0;
  const fcmToken = redemption.account.user?.fcmToken;
  if (fcmToken) {
    try {
      const messaging = getMessaging();
      if (messaging) {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: 'Bon utilisé',
            body: `${redemption.reward.name} a été validé. Solde: ${newBalance} pts`,
          },
          data: {
            type: 'LOYALTY_REDEEMED',
            rewardName: redemption.reward.name,
            newBalance: String(newBalance),
          },
        });
      }
    } catch (err) {
      logger.warn('FCM push failed LOYALTY_REDEEMED', { error: err instanceof Error ? err.message : err });
    }
  }

  return { success: true, rewardName: redemption.reward.name, newBalance };
}
