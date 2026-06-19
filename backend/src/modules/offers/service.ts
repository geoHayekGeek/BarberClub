/**
 * Offers service
 * Handles offer business logic with a focus on salon linkage, price, description, and ordering.
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';

export interface Offer {
  id: string;
  title: string;
  price: number;
  salonId: string;
  orderIndex: number; // 1. Added orderIndex to the TypeScript interface
}

class OffersService {
  /**
   * Retrieves a list of active offers.
   * Supports optional filtering by salonId.
   */
  async listOffers(params: {
    limit: number;
    cursor?: string;
    salonId?: string;
  }): Promise<{
    items: Offer[];
    nextCursor: string | null;
  }> {
    const limit = Math.min(params.limit, 50);

    const whereClause: any = {
      isActive: true,
    };

    if (params.salonId) {
      whereClause.salonId = params.salonId;
    }

    const offers = await prisma.offer.findMany({
      where: whereClause,
      // 2. Changed sorting to use orderIndex first!
      orderBy: [
        { orderIndex: 'asc' },
        { createdAt: 'desc' },
      ],
      take: limit + 1,
      // 3. Added orderIndex to the select block so the DB doesn't hide it
      select: {
        id: true,
        title: true,
        price: true,
        salonId: true,
        createdAt: true,
        orderIndex: true, 
      }
    });

    const hasMore = offers.length > limit;
    const items = offers.slice(0, limit);

    // 4. Mapped the orderIndex into the final result sent to Flutter
    const result = items.map((offer) => ({
      id: offer.id,
      title: offer.title,
      price: offer.price,
      salonId: offer.salonId,
      orderIndex: offer.orderIndex ?? 99, 
    }));

    const nextCursor = hasMore && items.length > 0
      ? `${items[items.length - 1].createdAt.toISOString()}|${items[items.length - 1].id}`
      : null;

    return {
      items: result,
      nextCursor,
    };
  }

  /**
   * Fetches a single offer by its unique ID.
   */
  async getOfferById(offerId: string): Promise<Offer> {
    const offer = await prisma.offer.findUnique({
      where: { id: offerId },
    });

    if (!offer) {
      throw new AppError(ErrorCode.OFFER_NOT_FOUND, 'Offer not found', 404);
    }

    return {
      id: offer.id,
      title: offer.title,
      price: offer.price,
      salonId: offer.salonId,
      orderIndex: offer.orderIndex ?? 99,
    };
  }

  /**
   * Creates a new offer linked to a specific salon via salonId.
   */
  async createOffer(data: {
    title: string;
    price: number;
    salonId: string;
    isActive: boolean;
    orderIndex?: number;
  }): Promise<Offer> {
    const offer = await prisma.offer.create({
      data: {
        title: data.title,
        price: data.price,
        isActive: data.isActive,
        orderIndex: data.orderIndex ?? 99,
        salon: {
          connect: { id: data.salonId }
        }
      },
    });

    return {
      id: offer.id,
      title: offer.title,
      price: offer.price,
      salonId: offer.salonId,
      orderIndex: offer.orderIndex,
    };
  }
}

export const offersService = new OffersService();