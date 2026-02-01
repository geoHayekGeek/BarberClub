/**
 * Offers service
 * Handles offer business logic with a focus on salon linkage, price, and description.
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';

export interface Offer {
  id: string;
  title: string;
  price: number;
  salonId: string;
}

class OffersService {
  /**
   * Retrieves a list of active offers.
   * Supports optional filtering by salonId.
   */
  async listOffers(params: {
    limit: number;
    cursor?: string;
    salonId?: string; // 1. Added optional salonId parameter
  }): Promise<{
    items: Offer[];
    nextCursor: string | null;
  }> {
    const limit = Math.min(params.limit, 50);

    // 2. Dynamically build the where clause
    const whereClause: any = {
      isActive: true,
    };

    // If a salonId is provided, filter the results strictly to that salon
    if (params.salonId) {
      whereClause.salonId = params.salonId;
    }

    const offers = await prisma.offer.findMany({
      where: whereClause,
      orderBy: [
        { createdAt: 'desc' },
        { id: 'desc' },
      ],
      take: limit + 1,
      // Ensure we select the salonId to maintain the link
      select: {
        id: true,
        title: true,
        price: true,
        salonId: true,
        createdAt: true,
      }
    });

    const hasMore = offers.length > limit;
    const items = offers.slice(0, limit);

    const result = items.map((offer) => ({
      id: offer.id,
      title: offer.title,
      price: offer.price,
      salonId: offer.salonId,
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
  }): Promise<Offer> {
    const offer = await prisma.offer.create({
      data: {
        title: data.title,
        price: data.price,
        isActive: data.isActive,
        // Link the offer to the salon using the provided salonId
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
    };
  }
}

export const offersService = new OffersService();