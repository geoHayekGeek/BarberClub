/**
 * Client offers service
 * Handles client-side promotions: feed, request-activation (QR), validation by barber, my offers, flash timeout.
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';
import { ClientOfferType, OfferActivationStatus } from '@prisma/client';
import { generateToken, hashToken, encodeQRPayload, parseQRPayload, QRType } from '../../utils/qr';

const FLASH_RESERVATION_HOURS = 2;

export interface RequestActivationResult {
  activationId: string;
  qrPayload: string;
}

export interface ValidateOfferQrResult {
  offerName: string;
  clientName: string;
  activationId: string;
}

export interface OfferFeedItem {
  id: string;
  type: string;
  title: string;
  description: string | null;
  discountType: string;
  discountValue: number;
  startsAt: string;
  endsAt: string | null;
  maxSpots: number | null;
  spotsTaken: number;
  imageUrl: string | null;
  applicableServices: string[];
}

export interface ActivationResult {
  id: string;
  offerId: string;
  clientId: string;
  status: string;
  activatedAt: string;
  expiresAt: string | null;
}

export interface MyOfferItem {
  activationId: string;
  status: string;
  activatedAt: string;
  expiresAt: string | null;
  offer: {
    id: string;
    type: string;
    title: string;
    description: string | null;
    discountValue: number;
    endsAt: string | null;
  };
}

class ClientOffersService {
  /**
   * GET /api/v1/offers - Public offers feed (non-expired, excluding welcome).
   * Includes offers that are currently valid (startsAt <= now) and offers scheduled for later (startsAt > now).
   * The app splits into "Offres en cours" vs "Offres à venir". Expired offers (endsAt <= now) are excluded.
   */
  async getActiveOffers(): Promise<OfferFeedItem[]> {
    const now = new Date();
    const offers = await prisma.clientOffer.findMany({
      where: {
        type: { not: 'welcome' },
        isActive: true,
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
      },
      orderBy: [{ startsAt: 'asc' }, { type: 'asc' }],
    });
    return offers.map((o) => ({
      id: o.id,
      type: o.type,
      title: o.title,
      description: o.description,
      discountType: o.discountType,
      discountValue: o.discountValue,
      startsAt: o.startsAt.toISOString(),
      endsAt: o.endsAt?.toISOString() ?? null,
      maxSpots: o.maxSpots,
      spotsTaken: o.spotsTaken,
      imageUrl: o.imageUrl,
      applicableServices: o.applicableServices,
    }));
  }

  /**
   * POST /api/offers/:id/request-activation
   * Creates activation with status = pending_scan, stores qrTokenHash, returns activationId + qrPayload.
   * User shows QR to barber; barber scans and backend sets status = activated via validateOfferQr.
   */
  async requestActivation(offerId: string, clientId: string): Promise<RequestActivationResult> {
    const now = new Date();
    const offer = await prisma.clientOffer.findUnique({
      where: { id: offerId },
    });
    if (!offer) {
      throw new AppError(ErrorCode.OFFER_NOT_FOUND, 'Offer not found', 404);
    }
    if (!offer.isActive) {
      throw new AppError(ErrorCode.OFFER_NOT_ACTIVE, 'Offer is not active', 400);
    }
    if (offer.startsAt > now) {
      throw new AppError(ErrorCode.OFFER_NOT_ACTIVE, 'Offer has not started yet', 400);
    }
    if (offer.endsAt && offer.endsAt <= now) {
      throw new AppError(ErrorCode.OFFER_EXPIRED, 'Offer has expired', 400);
    }

    const existingPending = await prisma.offerActivation.findFirst({
      where: {
        offerId,
        clientId,
        status: OfferActivationStatus.pending_scan,
        qrUsedAt: null,
      },
    });
    if (existingPending) {
      throw new AppError(ErrorCode.OFFER_ALREADY_ACTIVATED, 'Activation already requested. En attente validation.', 400);
    }

    const existingActivated = await prisma.offerActivation.findFirst({
      where: {
        offerId,
        clientId,
        status: { in: [OfferActivationStatus.activated, OfferActivationStatus.used] },
      },
    });
    if (existingActivated) {
      throw new AppError(ErrorCode.OFFER_ALREADY_ACTIVATED, 'You have already activated this offer', 400);
    }

    if (offer.type === ClientOfferType.flash) {
      const spotsLeft = (offer.maxSpots ?? 0) - offer.spotsTaken;
      if (offer.maxSpots != null && spotsLeft <= 0) {
        throw new AppError(ErrorCode.OFFER_MAX_SPOTS_REACHED, 'No spots left for this offer', 400);
      }
    }

    let expiresAt: Date | null = null;
    if (offer.type === ClientOfferType.flash) {
      expiresAt = new Date(now.getTime() + FLASH_RESERVATION_HOURS * 60 * 60 * 1000);
    }

    if (offer.type === ClientOfferType.flash) {
      await prisma.clientOffer.update({
        where: { id: offerId },
        data: { spotsTaken: { increment: 1 } },
      });
    }

    const rawToken = generateToken();
    const tokenHash = hashToken(rawToken);
    const qrPayload = encodeQRPayload(QRType.OFFER, rawToken);

    const activation = await prisma.offerActivation.create({
      data: {
        offerId,
        clientId,
        status: OfferActivationStatus.pending_scan,
        activatedAt: now,
        expiresAt,
        qrTokenHash: tokenHash,
      },
    });

    return {
      activationId: activation.id,
      qrPayload,
    };
  }

  /**
   * POST /api/admin/offers/validate
   * Barber scans QR; validate token, set status = activated, qrUsedAt = now.
   */
  async validateOfferQr(qrPayload: string): Promise<ValidateOfferQrResult> {
    const parsed = parseQRPayload(qrPayload);
    if (!parsed || parsed.type !== QRType.OFFER) {
      throw new AppError(ErrorCode.INVALID_QR, 'Invalid offer QR payload', 400);
    }
    const tokenHash = hashToken(parsed.token);

    const activation = await prisma.offerActivation.findFirst({
      where: {
        qrTokenHash: tokenHash,
        status: OfferActivationStatus.pending_scan,
        qrUsedAt: null,
      },
      include: { offer: true, client: true },
    });
    if (!activation) {
      throw new AppError(ErrorCode.INVALID_OR_EXPIRED_QR, 'QR already used or invalid', 400);
    }

    await prisma.offerActivation.update({
      where: { id: activation.id },
      data: {
        status: OfferActivationStatus.activated,
        qrUsedAt: new Date(),
      },
    });

    return {
      offerName: activation.offer.title,
      clientName: activation.client.fullName ?? activation.client.email,
      activationId: activation.id,
    };
  }

  /**
   * DELETE /api/offers/activations/:activationId
   * Cancel a pending_scan activation when user exits QR screen without barber scan.
   * Only allowed for the owning client; sets status = cancelled. For flash, decrements spotsTaken.
   */
  async cancelActivation(activationId: string, clientId: string): Promise<void> {
    const activation = await prisma.offerActivation.findFirst({
      where: { id: activationId, clientId },
      include: { offer: true },
    });
    if (!activation || activation.status !== OfferActivationStatus.pending_scan) {
      throw new AppError(ErrorCode.OFFER_NOT_FOUND, 'Activation not found or already used', 404);
    }
    await prisma.$transaction([
      prisma.offerActivation.update({
        where: { id: activationId },
        data: { status: OfferActivationStatus.cancelled },
      }),
      ...(activation.offer.type === ClientOfferType.flash
        ? [
            prisma.clientOffer.update({
              where: { id: activation.offerId },
              data: { spotsTaken: { decrement: 1 } },
            }),
          ]
        : []),
    ]);
  }

  /**
   * DELETE /api/offers/:offerId/activation
   * Cancel current user's pending_scan activation for this offer (e.g. when user exits QR without scan).
   * Prefer this when client has offerId; avoids relying on activationId in route state.
   */
  async cancelPendingActivationByOfferId(offerId: string, clientId: string): Promise<void> {
    const activation = await prisma.offerActivation.findFirst({
      where: {
        offerId,
        clientId,
        status: OfferActivationStatus.pending_scan,
        qrUsedAt: null,
      },
      include: { offer: true },
    });
    if (!activation) return;
    await prisma.$transaction([
      prisma.offerActivation.update({
        where: { id: activation.id },
        data: { status: OfferActivationStatus.cancelled },
      }),
      ...(activation.offer.type === ClientOfferType.flash
        ? [
            prisma.clientOffer.update({
              where: { id: offerId },
              data: { spotsTaken: { decrement: 1 } },
            }),
          ]
        : []),
    ]);
  }

  /**
   * POST /api/offers/:id/activate (legacy/direct - no longer used by client; kept for reference).
   * EVENT: one activation per user before expiration.
   * FLASH: reserve spot; if maxSpots reached reject; expiresAt = now + 2h.
   */
  async activateOffer(offerId: string, clientId: string): Promise<ActivationResult> {
    const now = new Date();
    const offer = await prisma.clientOffer.findUnique({
      where: { id: offerId },
    });
    if (!offer) {
      throw new AppError(ErrorCode.OFFER_NOT_FOUND, 'Offer not found', 404);
    }
    if (!offer.isActive) {
      throw new AppError(ErrorCode.OFFER_NOT_ACTIVE, 'Offer is not active', 400);
    }
    if (offer.startsAt > now) {
      throw new AppError(ErrorCode.OFFER_NOT_ACTIVE, 'Offer has not started yet', 400);
    }
    if (offer.endsAt && offer.endsAt <= now) {
      throw new AppError(ErrorCode.OFFER_EXPIRED, 'Offer has expired', 400);
    }

    if (offer.type === ClientOfferType.flash) {
      const spotsLeft = (offer.maxSpots ?? 0) - offer.spotsTaken;
      if (offer.maxSpots != null && spotsLeft <= 0) {
        throw new AppError(ErrorCode.OFFER_MAX_SPOTS_REACHED, 'No spots left for this offer', 400);
      }
    }

    if (offer.type === ClientOfferType.event) {
      const existing = await prisma.offerActivation.findFirst({
        where: {
          offerId,
          clientId,
          status: { in: [OfferActivationStatus.activated, OfferActivationStatus.used] },
        },
      });
      if (existing) {
        throw new AppError(ErrorCode.OFFER_ALREADY_ACTIVATED, 'You have already activated this offer', 400);
      }
    }

    let expiresAt: Date | null = null;
    if (offer.type === ClientOfferType.flash) {
      expiresAt = new Date(now.getTime() + FLASH_RESERVATION_HOURS * 60 * 60 * 1000);
    }

    if (offer.type === ClientOfferType.flash) {
      await prisma.clientOffer.update({
        where: { id: offerId },
        data: { spotsTaken: { increment: 1 } },
      });
    }

    const activation = await prisma.offerActivation.create({
      data: {
        offerId,
        clientId,
        status: OfferActivationStatus.activated,
        activatedAt: now,
        expiresAt,
      },
    });

    return {
      id: activation.id,
      offerId: activation.offerId,
      clientId: activation.clientId,
      status: activation.status,
      activatedAt: activation.activatedAt.toISOString(),
      expiresAt: activation.expiresAt?.toISOString() ?? null,
    };
  }

  /**
   * GET /api/client/offers - User's activated offers.
   * Welcome offer only shown when user has zero completed bookings.
   */
  async getMyOffers(clientId: string): Promise<MyOfferItem[]> {
    const completedBookingsCount = await prisma.booking.count({
      where: {
        userId: clientId,
        startDateTime: { lt: new Date() },
      },
    });
    const activations = await prisma.offerActivation.findMany({
      where: { clientId },
      include: { offer: true },
      orderBy: { activatedAt: 'desc' },
    });
    // One row per offer: keep only the most recent activation per offerId (list is already ordered by activatedAt desc)
    const seenOfferIds = new Set<string>();
    const uniqueActivations = activations.filter((a) => {
      if (seenOfferIds.has(a.offerId)) return false;
      seenOfferIds.add(a.offerId);
      return true;
    });
    const filtered =
      completedBookingsCount > 0
        ? uniqueActivations.filter((a) => a.offer.type !== 'welcome')
        : uniqueActivations;
    return filtered.map((a) => ({
      activationId: a.id,
      status: a.status,
      activatedAt: a.activatedAt.toISOString(),
      expiresAt: a.expiresAt?.toISOString() ?? null,
      offer: {
        id: a.offer.id,
        type: a.offer.type,
        title: a.offer.title,
        description: a.offer.description,
        discountValue: a.offer.discountValue,
        endsAt: a.offer.endsAt?.toISOString() ?? null,
      },
    }));
  }

  /**
   * Check if user has activated a given offer (for En cours UI "Activée" state).
   */
  async getActivatedOfferIds(clientId: string): Promise<Set<string>> {
    const activations = await prisma.offerActivation.findMany({
      where: { clientId, status: OfferActivationStatus.activated },
      select: { offerId: true },
    });
    return new Set(activations.map((a) => a.offerId));
  }

  /**
   * Get activation status per offer for the client (for En cours button states).
   * Returns { offerId: status } where status is pending_scan | activated | used | expired | cancelled.
   */
  async getActivationStateByOffer(clientId: string): Promise<Record<string, string>> {
    const activations = await prisma.offerActivation.findMany({
      where: { clientId },
      select: { offerId: true, status: true },
    });
    const map: Record<string, string> = {};
    for (const a of activations) {
      map[a.offerId] = a.status;
    }
    return map;
  }

  /**
   * Check if user has already activated an offer (for EVENT: once per user).
   */
  async hasActivatedOffer(offerId: string, clientId: string): Promise<boolean> {
    const existing = await prisma.offerActivation.findFirst({
      where: {
        offerId,
        clientId,
        status: { in: [OfferActivationStatus.activated, OfferActivationStatus.used] },
      },
    });
    return !!existing;
  }

  /**
   * Expire flash activations that passed expiresAt and decrement spotsTaken.
   */
  async expireFlashActivations(): Promise<number> {
    const now = new Date();
    const expired = await prisma.offerActivation.findMany({
      where: {
        status: OfferActivationStatus.activated,
        expiresAt: { lt: now },
        offer: { type: 'flash' },
      },
      include: { offer: true },
    });
    let count = 0;
    for (const act of expired) {
      await prisma.$transaction([
        prisma.offerActivation.update({
          where: { id: act.id },
          data: { status: OfferActivationStatus.expired },
        }),
        prisma.clientOffer.update({
          where: { id: act.offerId },
          data: { spotsTaken: { decrement: 1 } },
        }),
      ]);
      count++;
    }
    return count;
  }

  /**
   * Auto-activate welcome offer for a newly registered user.
   * Expires 30 days after registration. Only one welcome offer activation per user.
   */
  async activateWelcomeOfferForNewUser(clientId: string): Promise<void> {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    const welcomeOffer = await prisma.clientOffer.findFirst({
      where: {
        type: 'welcome',
        isActive: true,
        startsAt: { lte: now },
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
      },
    });
    if (!welcomeOffer) return;
    await prisma.offerActivation.create({
      data: {
        offerId: welcomeOffer.id,
        clientId,
        status: OfferActivationStatus.activated,
        activatedAt: now,
        expiresAt,
      },
    });
  }

  /**
   * Get activation by id (for checkout price calculation).
   */
  async getActivation(activationId: string, clientId: string) {
    return prisma.offerActivation.findFirst({
      where: { id: activationId, clientId, status: OfferActivationStatus.activated },
      include: { offer: true },
    });
  }

  /**
   * Mark activation as used and link booking.
   */
  async markActivationUsed(activationId: string, bookingId: string): Promise<void> {
    await prisma.offerActivation.update({
      where: { id: activationId },
      data: { status: OfferActivationStatus.used, usedAt: new Date(), bookingId },
    });
  }

  /**
   * Calculate final price for a booking when applying an offer.
   * Returns { originalPrice, finalPrice, offerActivationId }.
   * If activationId is provided and valid, applies discount; otherwise finalPrice = originalPrice.
   * Loyalty points must be earned on finalPrice. Offers cannot be combined with loyalty redemption.
   */
  async calculateBookingPrice(params: {
    servicePrice: number;
    serviceId: string;
    clientId: string;
    activationId?: string | null;
  }): Promise<{ originalPrice: number; finalPrice: number; offerActivationId: string | null }> {
    const originalPrice = params.servicePrice;
    if (!params.activationId) {
      return {
        originalPrice,
        finalPrice: originalPrice,
        offerActivationId: null as string | null,
      };
    }
    const activation = await this.getActivation(params.activationId, params.clientId);
    if (!activation) {
      return {
        originalPrice,
        finalPrice: originalPrice,
        offerActivationId: null as string | null,
      };
    }
    const offer = activation.offer;
    const applicable =
      offer.applicableServices.length === 0 ||
      offer.applicableServices.includes(params.serviceId);
    if (!applicable) {
      return {
        originalPrice,
        finalPrice: originalPrice,
        offerActivationId: null as string | null,
      };
    }
    let discount = 0;
    if (offer.discountType === 'percentage') {
      discount = Math.round((originalPrice * offer.discountValue) / 100);
    } else if (offer.discountType === 'fixed') {
      discount = Math.min(offer.discountValue, originalPrice);
    } else if (offer.discountType === 'free_service') {
      discount = originalPrice;
    }
    const finalPrice = Math.max(0, originalPrice - discount);
    return {
      originalPrice,
      finalPrice,
      offerActivationId: activation.id,
    };
  }
}

export const clientOffersService = new ClientOffersService();
