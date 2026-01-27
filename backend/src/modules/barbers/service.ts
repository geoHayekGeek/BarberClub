/**
 * Barbers service
 * Handles barber business logic
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';

export interface BarberListItem {
  id: string;
  firstName: string;
  lastName: string;
  bio: string;
  experienceYears: number | null;
  images: string[];
  salons: Array<{
    id: string;
    name: string;
    city: string;
  }>;
}

export interface BarberDetail extends BarberListItem {
  interests: string[];
}

class BarbersService {
  async listBarbers(): Promise<BarberListItem[]> {
    const barbers = await prisma.barber.findMany({
      where: {
        isActive: true,
      },
      orderBy: {
        firstName: 'asc',
      },
      include: {
        salons: {
          where: {
            salon: {
              isActive: true,
            },
          },
          include: {
            salon: {
              select: {
                id: true,
                name: true,
                city: true,
              },
            },
          },
        },
      },
    });

    return barbers.map((barber) => ({
      id: barber.id,
      firstName: barber.firstName,
      lastName: barber.lastName,
      bio: barber.bio,
      experienceYears: barber.experienceYears,
      images: barber.images,
      salons: barber.salons.map((bs) => ({
        id: bs.salon.id,
        name: bs.salon.name,
        city: bs.salon.city,
      })),
    }));
  }

  async getBarberById(barberId: string): Promise<BarberDetail> {
    const barber = await prisma.barber.findUnique({
      where: { id: barberId },
      include: {
        salons: {
          where: {
            salon: {
              isActive: true,
            },
          },
          include: {
            salon: {
              select: {
                id: true,
                name: true,
                city: true,
              },
            },
          },
        },
      },
    });

    if (!barber) {
      throw new AppError(ErrorCode.BARBER_NOT_FOUND, 'Barber not found', 404);
    }

    return {
      id: barber.id,
      firstName: barber.firstName,
      lastName: barber.lastName,
      bio: barber.bio,
      experienceYears: barber.experienceYears,
      interests: barber.interests,
      images: barber.images,
      salons: barber.salons.map((bs) => ({
        id: bs.salon.id,
        name: bs.salon.name,
        city: bs.salon.city,
      })),
    };
  }

  async createBarber(data: {
    firstName: string;
    lastName: string;
    bio: string;
    experienceYears: number | null;
    interests: string[];
    images: string[];
    salonIds: string[];
    isActive: boolean;
  }): Promise<BarberDetail> {
    // Validate salonIds exist
    const salons = await prisma.salon.findMany({
      where: {
        id: {
          in: data.salonIds,
        },
      },
    });

    if (salons.length !== data.salonIds.length) {
      throw new AppError(
        ErrorCode.VALIDATION_ERROR,
        'One or more salon IDs do not exist',
        400
      );
    }

    const barber = await prisma.barber.create({
      data: {
        firstName: data.firstName,
        lastName: data.lastName,
        bio: data.bio,
        experienceYears: data.experienceYears,
        interests: data.interests,
        images: data.images,
        isActive: data.isActive,
        salons: {
          create: data.salonIds.map((salonId) => ({
            salonId,
          })),
        },
      },
      include: {
        salons: {
          include: {
            salon: {
              select: {
                id: true,
                name: true,
                city: true,
              },
            },
          },
        },
      },
    });

    return {
      id: barber.id,
      firstName: barber.firstName,
      lastName: barber.lastName,
      bio: barber.bio,
      experienceYears: barber.experienceYears,
      interests: barber.interests,
      images: barber.images,
      salons: barber.salons.map((bs) => ({
        id: bs.salon.id,
        name: bs.salon.name,
        city: bs.salon.city,
      })),
    };
  }
}

export const barbersService = new BarbersService();
