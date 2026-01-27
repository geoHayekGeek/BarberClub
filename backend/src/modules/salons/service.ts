/**
 * Salons service
 * Handles salon business logic
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';

export interface SalonListItem {
  id: string;
  name: string;
  city: string;
  address: string;
  description: string;
  openingHours: string;
  images: string[];
}

export interface SalonDetail extends SalonListItem {
  barbers: Array<{
    id: string;
    firstName: string;
    lastName: string;
  }>;
}

class SalonsService {
  async listSalons(): Promise<SalonListItem[]> {
    const salons = await prisma.salon.findMany({
      where: {
        isActive: true,
      },
      orderBy: [
        { city: 'asc' },
        { name: 'asc' },
      ],
    });

    return salons.map((salon) => ({
      id: salon.id,
      name: salon.name,
      city: salon.city,
      address: salon.address,
      description: salon.description,
      openingHours: salon.openingHours,
      images: salon.images,
    }));
  }

  async getSalonById(salonId: string): Promise<SalonDetail> {
    const salon = await prisma.salon.findUnique({
      where: { id: salonId },
      include: {
        barbers: {
          where: {
            barber: {
              isActive: true,
            },
          },
          include: {
            barber: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
              },
            },
          },
        },
      },
    });

    if (!salon) {
      throw new AppError(ErrorCode.SALON_NOT_FOUND, 'Salon not found', 404);
    }

    return {
      id: salon.id,
      name: salon.name,
      city: salon.city,
      address: salon.address,
      description: salon.description,
      openingHours: salon.openingHours,
      images: salon.images,
      barbers: salon.barbers.map((bs) => ({
        id: bs.barber.id,
        firstName: bs.barber.firstName,
        lastName: bs.barber.lastName,
      })),
    };
  }

  async createSalon(data: {
    name: string;
    city: string;
    address: string;
    description: string;
    openingHours: string;
    images: string[];
    isActive: boolean;
  }): Promise<SalonListItem> {
    const salon = await prisma.salon.create({
      data: {
        name: data.name,
        city: data.city,
        address: data.address,
        description: data.description,
        openingHours: data.openingHours,
        images: data.images,
        isActive: data.isActive,
      },
    });

    return {
      id: salon.id,
      name: salon.name,
      city: salon.city,
      address: salon.address,
      description: salon.description,
      openingHours: salon.openingHours,
      images: salon.images,
    };
  }
}

export const salonsService = new SalonsService();
