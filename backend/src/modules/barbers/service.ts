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
  displayName: string;
  bio: string;
  experienceYears: number | null;
  level: string;
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
  async listBarbers(salonId?: string): Promise<BarberListItem[]> {
    const barbers = await prisma.barber.findMany({
      where: {
        isActive: true,
        ...(salonId
          ? {
              salons: {
                some: { salonId },
              },
            }
          : {}),
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
      displayName: barber.displayName ?? barber.firstName,
      bio: barber.bio,
      experienceYears: barber.experienceYears,
      level: barber.level,
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
      displayName: barber.displayName ?? barber.firstName,
      bio: barber.bio,
      experienceYears: barber.experienceYears,
      level: barber.level,
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
    displayName?: string;
    bio: string;
    experienceYears: number | null;
    level?: string;
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
        displayName: data.displayName ?? undefined,
        bio: data.bio,
        experienceYears: data.experienceYears,
        level: data.level ?? 'senior',
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
      displayName: barber.displayName ?? barber.firstName,
      bio: barber.bio,
      experienceYears: barber.experienceYears,
      level: barber.level,
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
