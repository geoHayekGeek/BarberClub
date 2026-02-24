/**
 * Salons service
 * Handles salon business logic
 */

import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';

export const DEFAULT_OPENING_HOURS = {
  monday: { open: '09:00', close: '19:00', closed: false },
  tuesday: { open: '09:00', close: '19:00', closed: false },
  wednesday: { open: '09:00', close: '19:00', closed: false },
  thursday: { open: '09:00', close: '19:00', closed: false },
  friday: { open: '09:00', close: '19:00', closed: false },
  saturday: { open: '09:00', close: '19:00', closed: false },
  sunday: { closed: true },
} as const;

export type OpeningHoursStructure = typeof DEFAULT_OPENING_HOURS;

export interface SalonListItem {
  id: string;
  name: string;
  city: string;
  imageUrl: string | null;
  timifyUrl: string | null;
}

export interface SalonDetail {
  id: string;
  name: string;
  city: string;
  description: string | null;
  imageUrl: string | null;
  gallery: string[];
  address: string;
  phone: string;
  latitude: number | null;
  longitude: number | null;
  openingHours: OpeningHoursStructure;
  /** Human-readable opening hours from DB (e.g. "Mar–Sam 9h–19h, Dim–Lun fermé") */
  openingHoursText: string;
  timifyUrl?: string | null;
}

function normalizeOpeningHours(raw: unknown): OpeningHoursStructure {
  if (raw && typeof raw === 'object' && !Array.isArray(raw)) {
    return raw as OpeningHoursStructure;
  }
  return DEFAULT_OPENING_HOURS;
}

class SalonsService {
  async listSalons(): Promise<SalonListItem[]> {
    const salons = await prisma.salon.findMany({
      where: { isActive: true },
      orderBy: [{ name: 'asc' }],
      select: {
        id: true,
        name: true,
        city: true,
        imageUrl: true,
        images: true,
        timifyUrl: true,
      },
    });

    return salons.map((s) => ({
      id: s.id,
      name: s.name,
      city: s.city,
      imageUrl: s.imageUrl ?? (s.images.length > 0 ? s.images[0] : null),
      timifyUrl: s.timifyUrl ?? null,
    }));
  }

  async getSalonById(salonId: string): Promise<SalonDetail> {
    const salon = await prisma.salon.findUnique({
      where: { id: salonId },
      select: {
        id: true,
        name: true,
        city: true,
        description: true,
        imageUrl: true,
        images: true,
        gallery: true,
        address: true,
        phone: true,
        latitude: true,
        longitude: true,
        openingHours: true,
        openingHoursStructured: true,
        timifyUrl: true,
      },
    });

    if (!salon) {
      throw new AppError(ErrorCode.SALON_NOT_FOUND, 'Salon not found', 404);
    }

    return {
      id: salon.id,
      name: salon.name,
      city: salon.city,
      description: salon.description,
      imageUrl: salon.imageUrl ?? (salon.images.length > 0 ? salon.images[0] : null),
      gallery: salon.gallery.length > 0 ? salon.gallery : salon.images,
      address: salon.address,
      phone: salon.phone,
      latitude: salon.latitude,
      longitude: salon.longitude,
      openingHours: normalizeOpeningHours(salon.openingHoursStructured),
      openingHoursText: salon.openingHours,
      timifyUrl: salon.timifyUrl,
    };
  }

  async createSalon(data: {
    name: string;
    city: string;
    address: string;
    description?: string | null;
    openingHours: string;
    openingHoursStructured?: unknown;
    images: string[];
    imageUrl?: string | null;
    gallery?: string[];
    phone?: string;
    latitude?: number | null;
    longitude?: number | null;
    isActive: boolean;
    timifyUrl?: string;
  }): Promise<SalonListItem> {
    const salon = await prisma.salon.create({
      data: {
        name: data.name,
        city: data.city,
        address: data.address,
        description: data.description ?? undefined,
        openingHours: data.openingHours,
        openingHoursStructured: data.openingHoursStructured
          ? (data.openingHoursStructured as object)
          : undefined,
        images: data.images,
        imageUrl: data.imageUrl ?? data.images[0] ?? undefined,
        gallery: data.gallery ?? (data.images.length > 1 ? data.images.slice(1) : []),
        phone: data.phone ?? '',
        latitude: data.latitude ?? undefined,
        longitude: data.longitude ?? undefined,
        isActive: data.isActive,
        timifyUrl: data.timifyUrl,
      },
    });

    return {
      id: salon.id,
      name: salon.name,
      city: salon.city,
      imageUrl: salon.imageUrl ?? (salon.images.length > 0 ? salon.images[0] : null),
      timifyUrl: salon.timifyUrl ?? null,
    };
  }
}

export const salonsService = new SalonsService();
