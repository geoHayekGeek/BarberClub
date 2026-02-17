/**
 * Barbers service
 * Handles barber business logic
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';

export interface BarberListSalon {
  id: string;
  name: string;
}

export interface BarberListItem {
  id: string;
  name: string;
  role: string;
  age: number | null;
  origin: string | null;
  imageUrl: string | null;
  salon: BarberListSalon | null;
}

export interface BarberDetailSalon {
  id: string;
  name: string;
  address: string;
}

export interface BarberDetail {
  id: string;
  name: string;
  role: string;
  age: number | null;
  origin: string | null;
  bio: string | null;
  videoUrl: string | null;
  imageUrl: string | null;
  gallery: string[];
  salon: BarberDetailSalon | null;
}

function barberName(barber: { firstName: string; lastName: string; displayName: string | null }): string {
  const full = `${barber.firstName} ${barber.lastName}`.trim();
  return (barber.displayName ?? full) || barber.firstName;
}

function primarySalonFromBarber(barber: {
  salon: { id: string; name: string; address?: string } | null;
  salons: Array<{ salon: { id: string; name: string; address?: string } }>;
}): { id: string; name: string; address?: string } | null {
  if (barber.salon) return barber.salon;
  const first = barber.salons[0]?.salon;
  return first ?? null;
}

class BarbersService {
  async listBarbers(salonId?: string): Promise<BarberListItem[]> {
    const barbers = await prisma.barber.findMany({
      where: {
        isActive: true,
        ...(salonId
          ? {
              OR: [
                { salonId },
                { salons: { some: { salonId } } },
              ],
            }
          : {}),
      },
      orderBy: { firstName: 'asc' },
      include: {
        salon: {
          select: { id: true, name: true },
        },
        salons: {
          where: { salon: { isActive: true } },
          include: {
            salon: {
              select: { id: true, name: true },
            },
          },
        },
      },
    });

    return barbers.map((barber) => {
      const salon = primarySalonFromBarber(barber);
      return {
        id: barber.id,
        name: barberName(barber),
        role: barber.role,
        age: barber.age,
        origin: barber.origin,
        imageUrl: barber.imageUrl ?? barber.images[0] ?? null,
        salon: salon ? { id: salon.id, name: salon.name } : null,
      };
    });
  }

  async getBarberById(barberId: string): Promise<BarberDetail> {
    const barber = await prisma.barber.findUnique({
      where: { id: barberId },
      include: {
        salon: {
          select: { id: true, name: true, address: true },
        },
        salons: {
          where: { salon: { isActive: true } },
          include: {
            salon: {
              select: { id: true, name: true, address: true },
            },
          },
        },
      },
    });

    if (!barber) {
      throw new AppError(ErrorCode.BARBER_NOT_FOUND, 'Barber not found', 404);
    }

    const salon = primarySalonFromBarber(barber);
    const gallery = barber.gallery.length > 0 ? barber.gallery : barber.images.slice(1);

    return {
      id: barber.id,
      name: barberName(barber),
      role: barber.role,
      age: barber.age,
      origin: barber.origin,
      bio: barber.bio,
      videoUrl: barber.videoUrl,
      imageUrl: barber.imageUrl ?? barber.images[0] ?? null,
      gallery,
      salon: salon ? { id: salon.id, name: salon.name, address: salon.address ?? '' } : null,
    };
  }

  async createBarber(data: {
    firstName: string;
    lastName: string;
    displayName?: string;
    bio?: string | null;
    experienceYears: number | null;
    level?: string;
    interests: string[];
    images: string[];
    salonIds: string[];
    isActive: boolean;
    age?: number | null;
    origin?: string | null;
    videoUrl?: string | null;
    imageUrl?: string | null;
    gallery?: string[];
  }): Promise<BarberDetail> {
    const uniqueSalonIds = [...new Set(data.salonIds)];

    const salons = await prisma.salon.findMany({
      where: { id: { in: uniqueSalonIds } },
    });

    if (salons.length !== uniqueSalonIds.length) {
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
        bio: data.bio ?? undefined,
        experienceYears: data.experienceYears,
        level: data.level ?? 'senior',
        interests: data.interests,
        images: data.images,
        isActive: data.isActive,
        salonId: uniqueSalonIds[0] ?? undefined,
        age: data.age ?? undefined,
        origin: data.origin ?? undefined,
        videoUrl: data.videoUrl ?? undefined,
        imageUrl: data.imageUrl ?? undefined,
        gallery: data.gallery ?? [],
        salons: {
          create: uniqueSalonIds.map((salonId) => ({ salonId })),
        },
      },
      include: {
        salon: {
          select: { id: true, name: true, address: true },
        },
        salons: {
          include: {
            salon: {
              select: { id: true, name: true, address: true },
            },
          },
        },
      },
    });

    const salon = primarySalonFromBarber(barber);
    const gallery = barber.gallery.length > 0 ? barber.gallery : barber.images.slice(1);

    return {
      id: barber.id,
      name: barberName(barber),
      role: barber.role,
      age: barber.age,
      origin: barber.origin,
      bio: barber.bio,
      videoUrl: barber.videoUrl,
      imageUrl: barber.imageUrl ?? barber.images[0] ?? null,
      gallery,
      salon: salon ? { id: salon.id, name: salon.name, address: salon.address ?? '' } : null,
    };
  }
}

export const barbersService = new BarbersService();
