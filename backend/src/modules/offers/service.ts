/**
 * Offers service
 * Handles offer business logic
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';

export interface Offer {
  id: string;
  title: string;
  description: string;
  imageUrl: string | null;
  validFrom: string | null;
  validTo: string | null;
}

class OffersService {
  async listOffers(params: {
    status: 'active' | 'all';
    limit: number;
    cursor?: string;
  }): Promise<{
    items: Offer[];
    nextCursor: string | null;
  }> {
    const now = new Date();
    const limit = Math.min(params.limit, 50);

    let whereClause: {
      isActive?: boolean;
      AND?: Array<{
        OR?: Array<{ validFrom: null } | { validFrom: { lte: Date } }>;
      } | {
        OR?: Array<{ validTo: null } | { validTo: { gte: Date } }>;
      }>;
    } = {};

    if (params.status === 'active') {
      whereClause.isActive = true;
      whereClause.AND = [
        {
          OR: [
            { validFrom: null },
            { validFrom: { lte: now } },
          ],
        },
        {
          OR: [
            { validTo: null },
            { validTo: { gte: now } },
          ],
        },
      ];
    }

    let cursorWhere: Record<string, unknown> | undefined;
    if (params.cursor) {
      try {
        const [dateStr, id] = params.cursor.split('|');
        const cursorDate = new Date(dateStr);
        const cursorId = id;

        cursorWhere = {
          OR: [
            { createdAt: { lt: cursorDate } },
            {
              createdAt: cursorDate,
              id: { lt: cursorId },
            },
          ],
        };
      } catch {
        throw new AppError(ErrorCode.VALIDATION_ERROR, 'Invalid cursor format', 400);
      }
    }

    const finalWhere: Record<string, unknown> = {
      ...whereClause,
    };

    if (cursorWhere) {
      if (finalWhere.AND) {
        finalWhere.AND = [
          ...(Array.isArray(finalWhere.AND) ? finalWhere.AND : [finalWhere.AND]),
          cursorWhere,
        ];
      } else {
        finalWhere.AND = [cursorWhere];
      }
    }

    const offers = await prisma.offer.findMany({
      where: finalWhere as {
        isActive?: boolean;
        AND?: Array<Record<string, unknown>>;
      },
      orderBy: [
        { createdAt: 'desc' },
        { id: 'desc' },
      ],
      take: limit + 1,
    });

    const hasMore = offers.length > limit;
    const items = offers.slice(0, limit);

    const result = items.map((offer) => ({
      id: offer.id,
      title: offer.title,
      description: offer.description,
      imageUrl: offer.imageUrl,
      validFrom: offer.validFrom ? offer.validFrom.toISOString() : null,
      validTo: offer.validTo ? offer.validTo.toISOString() : null,
    }));

    const nextCursor = hasMore && items.length > 0
      ? `${items[items.length - 1].createdAt.toISOString()}|${items[items.length - 1].id}`
      : null;

    return {
      items: result,
      nextCursor,
    };
  }

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
      description: offer.description,
      imageUrl: offer.imageUrl,
      validFrom: offer.validFrom ? offer.validFrom.toISOString() : null,
      validTo: offer.validTo ? offer.validTo.toISOString() : null,
    };
  }

  async createOffer(data: {
    title: string;
    description: string;
    imageUrl: string | null;
    validFrom: string | null;
    validTo: string | null;
    isActive: boolean;
  }): Promise<Offer> {
    // Validate date logic
    if (data.validFrom && data.validTo) {
      const from = new Date(data.validFrom);
      const to = new Date(data.validTo);
      if (from > to) {
        throw new AppError(
          ErrorCode.VALIDATION_ERROR,
          'validFrom must be less than or equal to validTo',
          400
        );
      }
    }

    const offer = await prisma.offer.create({
      data: {
        title: data.title,
        description: data.description,
        imageUrl: data.imageUrl,
        validFrom: data.validFrom ? new Date(data.validFrom) : null,
        validTo: data.validTo ? new Date(data.validTo) : null,
        isActive: data.isActive,
      },
    });

    return {
      id: offer.id,
      title: offer.title,
      description: offer.description,
      imageUrl: offer.imageUrl,
      validFrom: offer.validFrom ? offer.validFrom.toISOString() : null,
      validTo: offer.validTo ? offer.validTo.toISOString() : null,
    };
  }
}

export const offersService = new OffersService();
