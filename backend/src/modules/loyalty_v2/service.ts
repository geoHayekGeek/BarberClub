/**
 * Loyalty v2 service: points-as-currency, appointment-based ranks, rewards catalog, transactions.
 */

import prisma from '../../db/client';
import { getMessaging } from '../../config/firebase';
import { AppError, ErrorCode } from '../../utils/errors';
import { logger } from '../../utils/logger';
import config from '../../config';
import { generateToken, hashToken, encodeQRPayload, QRType } from '../../utils/qr';
import {
  getCheapestRewardCost,
  getNextRank,
  getRankDefinition,
  getRankFromAppointments,
  getRankProgress,
  getRankScale,
  type LoyaltyRankTheme,
  type LoyaltyTierName,
} from './tiers';
import { assertAdminHasAccessToSalon } from '../admin/salonAccess';
import { pointsFromPrice } from './points';

const INVALID_QR_MESSAGE = 'QR code invalide';

const VOUCHER_QR_TTL_SECONDS = 30 * 24 * 60 * 60; // 30 days
const NEAR_REWARD_THRESHOLD = 20;

export interface LoyaltyMeResponse {
  currentBalance: number;
  lifetimeEarned: number;
  lifetimeAppointments: number;
  tier: LoyaltyTierName;
  rank: LoyaltyTierName;
  enrolledAt: string;
  member: {
    id: string;
    memberCode: string;
    fullName: string;
    avatarUrl: string | null;
  };
  nextTier: {
    name: LoyaltyTierName;
    requiredAppointments: number;
    remainingAppointments: number;
    remainingPoints: number;
  } | null;
  nextRank: {
    name: LoyaltyTierName;
    requiredAppointments: number;
    remainingAppointments: number;
  } | null;
  theme: LoyaltyRankTheme;
  themeVariables: {
    '--accent': string;
    '--accent-2': string;
    '--glow': string;
    '--ink': string;
  };
  memberPosition: {
    label: string;
    points: number;
  };
  rankProgress: number;
  rankScale: LoyaltyRankScaleDto[];
  rewards: LoyaltyRewardMilestoneDto[];
  rewardMilestones: LoyaltyRewardMilestoneDto[];
  pointsRule: {
    spendAmount: number;
    spendCurrency: 'EUR';
    pointsEarned: number;
  };
}

export interface LoyaltyRewardDto {
  id: string;
  slug: string | null;
  name: string;
  costPoints: number;
  description: string | null;
  imageUrl: string | null;
  isActive: boolean;
  sortOrder: number;
}

export interface LoyaltyRewardMilestoneDto extends LoyaltyRewardDto {
  isReached: boolean;
  canRedeem: boolean;
  isLocked: boolean;
  pointsRemaining: number;
  remainingLabel: string;
  positionLabel: string;
}

export interface LoyaltyRankScaleDto {
  name: LoyaltyTierName;
  requiredAppointments: number;
  theme: LoyaltyRankTheme;
  isCurrent: boolean;
  isReached: boolean;
  remainingAppointments: number;
}

export interface LoyaltyTransactionDto {
  id: string;
  type: string;
  points: number;
  appointmentCount: number;
  description: string;
  createdAt: string;
}

export interface AdminEarnResponse {
  pointsEarned: number;
  newBalance: number;
  newLifetime: number;
  newLifetimeAppointments: number;
  newTier: LoyaltyTierName;
  newRank: LoyaltyTierName;
}

export interface CompletedBookingEarnResponse {
  pointsEarned: number;
  newBalance: number;
  newLifetime: number;
  newLifetimeAppointments: number;
  newTier: LoyaltyTierName;
  newRank: LoyaltyTierName;
}

export interface CompletedBookingEarnInput {
  appUserId: string;
  websiteBookingId: string;
  websiteClientId: string;
  serviceName: string;
  bookingPrice: number;
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

function formatMemberCode(userId: string): string {
  return `BC-${userId.replace(/-/g, '').slice(0, 8).toUpperCase()}`;
}

function toRewardDto(row: {
  id: string;
  slug: string | null;
  name: string;
  costPoints: number;
  description: string | null;
  imageUrl: string | null;
  isActive: boolean;
  sortOrder: number;
}): LoyaltyRewardDto {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    costPoints: row.costPoints,
    description: row.description,
    imageUrl: row.imageUrl,
    isActive: row.isActive,
    sortOrder: row.sortOrder,
  };
}

function toRewardMilestone(row: ReturnType<typeof toRewardDto>, currentBalance: number): LoyaltyRewardMilestoneDto {
  const pointsRemaining = Math.max(0, row.costPoints - currentBalance);
  const isReached = pointsRemaining === 0;

  return {
    ...row,
    isReached,
    canRedeem: isReached,
    isLocked: !isReached,
    pointsRemaining,
    remainingLabel: isReached ? 'Ready to redeem' : `${pointsRemaining} pts remaining`,
    positionLabel: `You \u00B7 ${currentBalance} pts`,
  };
}

export async function getLoyaltyState(userId: string): Promise<LoyaltyMeResponse> {
  await ensureLoyaltyAccount(userId);
  const [account, rewardRows] = await Promise.all([
    prisma.loyaltyAccount.findUnique({
      where: { userId },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
    }),
    prisma.loyaltyReward.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { costPoints: 'asc' }, { createdAt: 'asc' }],
    }),
  ]);

  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);

  const rank = getRankFromAppointments(account.lifetimeAppointments);
  const rankDefinition = getRankDefinition(rank);
  const nextRank = getNextRank(account.lifetimeAppointments);
  const rewardMilestones = rewardRows
    .map(toRewardDto)
    .map((reward) => toRewardMilestone(reward, account.currentBalance));

  return {
    currentBalance: account.currentBalance,
    lifetimeEarned: account.lifetimeEarned,
    lifetimeAppointments: account.lifetimeAppointments,
    tier: rank,
    rank,
    enrolledAt: account.enrolledAt.toISOString(),
    member: {
      id: account.user.id,
      memberCode: formatMemberCode(account.user.id),
      fullName: account.user.fullName?.trim() || account.user.email,
      avatarUrl: account.user.avatarUrl,
    },
    nextTier: nextRank
      ? {
          name: nextRank.name,
          requiredAppointments: nextRank.requiredAppointments,
          remainingAppointments: nextRank.remainingAppointments,
          // Backward-compatible alias for the current mobile parser.
          remainingPoints: nextRank.remainingAppointments,
        }
      : null,
    nextRank,
    theme: rankDefinition.theme,
    themeVariables: {
      '--accent': rankDefinition.theme.accent,
      '--accent-2': rankDefinition.theme.accent2,
      '--glow': rankDefinition.theme.glow,
      '--ink': rankDefinition.theme.ink,
    },
    memberPosition: {
      label: `You \u00B7 ${account.currentBalance} pts`,
      points: account.currentBalance,
    },
    rankProgress: getRankProgress(account.lifetimeAppointments),
    rankScale: getRankScale(account.lifetimeAppointments),
    rewards: rewardMilestones,
    rewardMilestones,
    pointsRule: {
      spendAmount: 1,
      spendCurrency: 'EUR',
      pointsEarned: 1,
    },
  };
}

export async function getPrivateClubState(userId: string): Promise<LoyaltyMeResponse> {
  return getLoyaltyState(userId);
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
    orderBy: [{ sortOrder: 'asc' }, { costPoints: 'asc' }, { createdAt: 'asc' }],
  });
  return rows.map(toRewardDto);
}

export interface RedeemRewardResult {
  redemptionId: string;
  rewardName: string;
  qrPayload: string;
  newBalance: number;
}

export async function redeemReward(userId: string, rewardId: string): Promise<RedeemRewardResult> {
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
  const token = generateToken();
  const tokenHash = hashToken(token);
  const qrExpiresAt = new Date(Date.now() + VOUCHER_QR_TTL_SECONDS * 1000);

  const result = await prisma.$transaction(async (tx) => {
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
        qrTokenHash: tokenHash,
        qrExpiresAt,
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
    return {
      newBalance: acc.currentBalance,
      redemptionId: redemption.id,
      rewardName: reward.name,
      pointsSpent: reward.costPoints,
    };
  });

  const qrPayload = encodeQRPayload(QRType.VOUCHER, token);
  return {
    redemptionId: result.redemptionId,
    rewardName: result.rewardName,
    qrPayload,
    newBalance: result.newBalance,
  };
}

/** Fallback: regenerate voucher QR for a PENDING redemption (e.g. "Afficher QR" in Mes bons). Only allowed if qrUsedAt is null. */
export async function generateVoucherQr(
  userId: string,
  redemptionId: string
): Promise<{ qrPayload: string; expiresAt: string }> {
  await ensureLoyaltyAccount(userId);
  const account = await prisma.loyaltyAccount.findUnique({ where: { userId } });
  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);
  const redemption = await prisma.loyaltyRedemptionVoucher.findFirst({
    where: { id: redemptionId, accountId: account.id, status: 'PENDING', qrUsedAt: null },
  });
  if (!redemption) throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'Bon invalide ou déjà utilisé', 404);
  const token = generateToken();
  const tokenHash = hashToken(token);
  const expiresAt = new Date(Date.now() + VOUCHER_QR_TTL_SECONDS * 1000);
  await prisma.loyaltyRedemptionVoucher.update({
    where: { id: redemptionId },
    data: { qrTokenHash: tokenHash, qrExpiresAt: expiresAt },
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
    appointmentCount: r.appointmentCount,
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

/** Cancel a PENDING redemption: restore points, set status CANCELLED, add ADJUST transaction. Only if qrUsedAt is null. */
export async function cancelRedemption(userId: string, redemptionId: string): Promise<{ newBalance: number }> {
  await ensureLoyaltyAccount(userId);
  const account = await prisma.loyaltyAccount.findUnique({ where: { userId } });
  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);
  const redemption = await prisma.loyaltyRedemptionVoucher.findFirst({
    where: { id: redemptionId, accountId: account.id, status: 'PENDING', qrUsedAt: null },
    include: { reward: true },
  });
  if (!redemption) throw new AppError(ErrorCode.NOT_FOUND, 'Redemption introuvable ou non annulable', 404);

  const result = await prisma.$transaction(async (tx) => {
    await tx.loyaltyRedemptionVoucher.update({
      where: { id: redemptionId },
      data: { status: 'CANCELLED' },
    });
    const acc = await tx.loyaltyAccount.update({
      where: { id: account.id },
      data: { currentBalance: { increment: redemption.pointsSpent } },
      select: { currentBalance: true },
    });
    await tx.loyaltyTransaction.create({
      data: {
        accountId: account.id,
        type: 'ADJUST',
        points: redemption.pointsSpent,
        description: 'Annulation récompense',
        referenceId: redemptionId,
      },
    });
    return acc.currentBalance;
  });

  return { newBalance: result };
}

/** Admin: earn points by scanning user earn QR after selecting a service. */
export async function adminEarnPoints(
  qrPayload: string,
  serviceId: string,
  adminId?: string
): Promise<AdminEarnResponse> {
  const trimmed = (qrPayload ?? '').trim();
  const parts = trimmed.split('|');
  if (parts.length !== 4) {
    logger.warn('LOYALTY_EARN invalid_format', { payloadLength: trimmed.length });
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MESSAGE, 400);
  }
  const [prefix, version, type, rawToken] = parts;
  if (prefix !== 'BC' || version !== 'v1' || type !== QRType.EARN) {
    logger.warn('LOYALTY_EARN invalid_prefix_version_type', { prefix, version, type });
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MESSAGE, 400);
  }
  if (!rawToken || rawToken.length < 16) {
    logger.warn('LOYALTY_EARN token_too_short');
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MESSAGE, 400);
  }
  const tokenHash = hashToken(rawToken);
  const tokenRecord = await prisma.loyaltyAccountQrToken.findFirst({
    where: { tokenHash },
    include: { account: { include: { user: true } } },
  });
  if (!tokenRecord) {
    logger.warn('LOYALTY_EARN token_not_found');
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MESSAGE, 400);
  }
  if (tokenRecord.usedAt) {
    logger.warn('LOYALTY_EARN token_used', { accountId: tokenRecord.accountId });
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MESSAGE, 400);
  }
  if (tokenRecord.expiresAt <= new Date()) {
    logger.warn('LOYALTY_EARN token_expired', { accountId: tokenRecord.accountId });
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MESSAGE, 400);
  }
  const offer = await prisma.offer.findFirst({
    where: { id: serviceId, isActive: true },
    select: { id: true, title: true, price: true, salonId: true },
  });
  if (!offer) throw new AppError(ErrorCode.OFFER_NOT_FOUND, 'Service introuvable', 404);
  if (adminId) {
    await assertAdminHasAccessToSalon(adminId, offer.salonId);
  }
  if (!Number.isFinite(offer.price) || offer.price < 0) {
    throw new AppError(ErrorCode.VALIDATION_ERROR, 'Montant invalide pour ce service', 400);
  }
  const pointsEarned = pointsFromPrice(offer.price);

  if (adminId) logger.info('LOYALTY_EARN admin_earn', { adminId, accountId: tokenRecord.accountId, serviceId, pointsEarned });

  const accountId = tokenRecord.accountId;
  const previousTier = getRankFromAppointments(tokenRecord.account.lifetimeAppointments);

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
        lifetimeAppointments: { increment: 1 },
      },
      select: { currentBalance: true, lifetimeEarned: true, lifetimeAppointments: true },
    });
    await tx.loyaltyTransaction.create({
      data: {
        accountId,
        type: 'EARN',
        points: pointsEarned,
        appointmentCount: 1,
        description: offer.title,
        referenceId: serviceId,
        adminId,
      },
    });
    return acc;
  });

  const account = await prisma.loyaltyAccount.findUnique({
    where: { id: accountId },
    select: { currentBalance: true, lifetimeEarned: true, lifetimeAppointments: true },
  });
  if (!account) throw new AppError(ErrorCode.INTERNAL_ERROR, 'Account not found', 500);
  const newTier = getRankFromAppointments(account.lifetimeAppointments);
  const user = tokenRecord.account.user;
  const fcmToken = user?.fcmToken;

  if (fcmToken) {
    try {
      const messaging = getMessaging();
      if (messaging) {
        if (pointsEarned > 0) {
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
        }
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
        if (pointsEarned > 0) {
          const rewards = await prisma.loyaltyReward.findMany({
            where: { isActive: true },
            select: { costPoints: true },
          });
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
      } else {
        logger.warn('Firebase messaging not initialized; skipping LOYALTY_EARN push');
      }
    } catch (err) {
      logger.warn('FCM push failed LOYALTY_EARN', { accountId, error: err instanceof Error ? err.message : err });
    }
  }

  return {
    pointsEarned,
    newBalance: account.currentBalance,
    newLifetime: account.lifetimeEarned,
    newLifetimeAppointments: account.lifetimeAppointments,
    newTier,
    newRank: newTier,
  };
}

const INVALID_QR_MSG = 'QR code invalide';

/** Admin: validate voucher QR and mark redemption as USED. Returns rewardName, userName, newBalance. Sends FCM LOYALTY_REDEEM. */
export async function adminRedeemVoucher(qrPayload: string): Promise<{
  success: boolean;
  rewardName: string;
  userName: string;
  newBalance: number;
}> {
  const trimmed = (qrPayload ?? '').trim();
  const parts = trimmed.split('|');
  if (parts.length !== 4 || parts[0] !== 'BC' || parts[1] !== 'v1' || parts[2] !== QRType.VOUCHER || !parts[3] || parts[3].length < 16) {
    logger.warn('VOUCHER_REDEEM invalid_format', { payloadLength: trimmed.length });
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MSG, 400);
  }
  const tokenHash = hashToken(parts[3]);
  const redemption = await prisma.loyaltyRedemptionVoucher.findFirst({
    where: { qrTokenHash: tokenHash },
    include: { account: { include: { user: true } }, reward: true },
  });
  if (!redemption) {
    logger.warn('VOUCHER_REDEEM not_found');
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MSG, 400);
  }
  if (redemption.qrExpiresAt && redemption.qrExpiresAt <= new Date()) {
    logger.warn('VOUCHER_REDEEM expired', { redemptionId: redemption.id });
    throw new AppError(ErrorCode.VOUCHER_EXPIRED, 'Bon expiré', 400);
  }
  if (redemption.qrUsedAt || redemption.status === 'USED') {
    logger.warn('VOUCHER_REDEEM already_used', { redemptionId: redemption.id });
    throw new AppError(ErrorCode.VOUCHER_ALREADY_USED, 'Bon déjà utilisé', 400);
  }
  if (redemption.status !== 'PENDING') {
    throw new AppError(ErrorCode.INVALID_QR, INVALID_QR_MSG, 400);
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
  const user = redemption.account.user;
  const fcmToken = user?.fcmToken;
  if (fcmToken) {
    try {
      const messaging = getMessaging();
      if (messaging) {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: 'Récompense validée',
            body: `${redemption.reward.name}. Solde restant : ${newBalance} pts`,
          },
          data: {
            type: 'LOYALTY_REDEEM',
            rewardName: redemption.reward.name,
            newBalance: String(newBalance),
          },
        });
      } else {
        logger.warn('Firebase messaging not initialized; skipping LOYALTY_REDEEM push');
      }
    } catch (err) {
      logger.warn('FCM push failed LOYALTY_REDEEM', { error: err instanceof Error ? err.message : err });
    }
  }

  const userName = user?.fullName?.trim() || user?.email || 'Client';
  return { success: true, rewardName: redemption.reward.name, userName, newBalance };
}
