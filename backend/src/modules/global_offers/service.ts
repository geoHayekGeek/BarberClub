/**
 * Global offers service
 * Returns active global promotions (not salon-based)
 */

import prisma from '../../db/client';

export interface GlobalOfferDto {
  id: string;
  title: string;
  description: string | null;
  imageUrl: string | null;
  discount: number | null;
  isActive: boolean;
  createdAt: Date;
}

class GlobalOffersService {
  async listActive(): Promise<GlobalOfferDto[]> {
    const rows = await prisma.globalOffer.findMany({
      where: { isActive: true },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      description: r.description,
      imageUrl: r.imageUrl,
      discount: r.discount,
      isActive: r.isActive,
      createdAt: r.createdAt,
    }));
  }
}

export const globalOffersService = new GlobalOffersService();
