/**
 * Booking service
 * Handles booking business logic and TIMIFY integration
 */

import prisma from '../../db/client';
import { timifyClient } from '../timify';
import { AppError, ErrorCode } from '../../utils/errors';
import { logger } from '../../utils/logger';
import config from '../../config';
import type { TimifyRegion } from '../timify/types';

export interface Branch {
  id: string;
  name: string;
  address?: string;
  city?: string;
  country?: string;
  timezone?: string;
}

export interface Service {
  id: string;
  name: string;
  durationMinutes: number;
  price?: number;
}

export interface Availability {
  calendarBegin: string;
  calendarEnd: string;
  onDays: string[];
  offDays: string[];
  timesByDay?: Record<string, string[]>;
}

export interface Reservation {
  reservationId: string;
  expiresAt: string;
}

export interface Booking {
  id: string;
  userId: string;
  branchId: string;
  serviceId: string;
  startDateTime: Date;
  timifyAppointmentId?: string;
  status: string;
  createdAt: Date;
}

class BookingService {
  async getBranches(): Promise<Branch[]> {
    try {
      const companies = await timifyClient.getCompanies();

      const companyIds = process.env.TIMIFY_COMPANY_IDS;
      if (companyIds) {
        const allowedIds = companyIds.split(',').map((id) => id.trim());
        return companies.filter((company) => allowedIds.includes(company.id));
      }

      return companies;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error('Failed to fetch branches', { error });
      throw new AppError(ErrorCode.BOOKING_PROVIDER_ERROR, 'Failed to fetch branches');
    }
  }

  async getBranchServices(branchId: string): Promise<Service[]> {
    try {
      const services = await timifyClient.getServices(branchId);
      return services
        .filter((service) => service.duration > 0)
        .map((service) => ({
          id: service.id,
          name: service.name,
          durationMinutes: service.duration,
          price: service.price,
        }));
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error('Failed to fetch services', { error, branchId });
      throw new AppError(ErrorCode.BOOKING_PROVIDER_ERROR, 'Failed to fetch services');
    }
  }

  async getAvailability(params: {
    branchId: string;
    serviceId: string;
    startDate: string;
    endDate: string;
    resourceId?: string;
  }): Promise<Availability> {
    try {
      const availability = await timifyClient.getAvailabilities({
        company_id: params.branchId,
        service_id: params.serviceId,
        start_date: params.startDate,
        end_date: params.endDate,
        resource_id: params.resourceId,
      });

      return availability;
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error('Failed to fetch availability', { error, params });
      throw new AppError(ErrorCode.BOOKING_PROVIDER_ERROR, 'Failed to fetch availability');
    }
  }

  async reserve(params: {
    userId: string;
    branchId: string;
    serviceId: string;
    date: string;
    time: string;
    resourceId?: string;
  }): Promise<Reservation> {
    try {
      const timifyResponse = await timifyClient.createReservation({
        company_id: params.branchId,
        service_id: params.serviceId,
        date: params.date,
        time: params.time,
        resource_id: params.resourceId,
      });

      const expiresAt = new Date(timifyResponse.expires_at);

      const reservation = await prisma.timifyReservation.create({
        data: {
          userId: params.userId,
          branchId: params.branchId,
          serviceId: params.serviceId,
          resourceId: params.resourceId || null,
          reservedDate: params.date,
          reservedTime: params.time,
          timifyReservationId: timifyResponse.reservation_id,
          timifySecret: timifyResponse.secret,
          expiresAt,
        },
      });

      logger.info('Reservation created', {
        reservationId: reservation.id,
        userId: params.userId,
        branchId: params.branchId,
      });

      return {
        reservationId: reservation.id,
        expiresAt: expiresAt.toISOString(),
      };
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error('Failed to create reservation', { error, params });
      throw new AppError(ErrorCode.BOOKING_PROVIDER_ERROR, 'Failed to create reservation');
    }
  }

  async confirm(params: {
    userId: string;
    reservationId: string;
  }): Promise<Booking> {
    const reservation = await prisma.timifyReservation.findUnique({
      where: { id: params.reservationId },
    });

    if (!reservation) {
      throw new AppError(ErrorCode.NOT_FOUND, 'Reservation not found', 404);
    }

    if (reservation.userId !== params.userId) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Reservation does not belong to user', 403);
    }

    if (reservation.usedAt) {
      throw new AppError(ErrorCode.BOOKING_VALIDATION_ERROR, 'Reservation already used', 400);
    }

    if (new Date() > reservation.expiresAt) {
      throw new AppError(ErrorCode.BOOKING_VALIDATION_ERROR, 'Reservation expired', 400);
    }

    try {
      const confirmResponse = await timifyClient.confirmAppointment({
        company_id: reservation.branchId,
        reservation_id: reservation.timifyReservationId,
        secret: reservation.timifySecret,
        external_customer_id: params.userId,
        is_course: false,
        region: config.TIMIFY_REGION as TimifyRegion,
      });

      const [hours, minutes] = reservation.reservedTime.split(':').map(Number);
      const startDateTime = new Date(`${reservation.reservedDate}T${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`);

      const booking = await prisma.$transaction(async (tx) => {
        const booking = await tx.booking.create({
          data: {
            userId: params.userId,
            branchId: reservation.branchId,
            serviceId: reservation.serviceId,
            resourceId: reservation.resourceId || null,
            startDateTime,
            timifyAppointmentId: confirmResponse.appointment_id || null,
            status: 'CONFIRMED',
          },
        });

        await tx.timifyReservation.update({
          where: { id: params.reservationId },
          data: { usedAt: new Date() },
        });

        const loyaltyState = await tx.loyaltyState.findUnique({
          where: { userId: params.userId },
        });

        const currentStamps = loyaltyState?.stamps ?? 0;
        const newStamps = currentStamps + 1;

        await tx.loyaltyState.upsert({
          where: { userId: params.userId },
          update: {
            stamps: newStamps,
          },
          create: {
            userId: params.userId,
            stamps: newStamps,
          },
        });

        return booking;
      });

      logger.info('Booking confirmed', {
        bookingId: booking.id,
        userId: params.userId,
        reservationId: params.reservationId,
      });

      return {
        id: booking.id,
        userId: booking.userId,
        branchId: booking.branchId,
        serviceId: booking.serviceId,
        startDateTime: booking.startDateTime,
        timifyAppointmentId: booking.timifyAppointmentId || undefined,
        status: booking.status,
        createdAt: booking.createdAt,
      };
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error('Failed to confirm booking', { error, params });
      throw new AppError(ErrorCode.BOOKING_PROVIDER_ERROR, 'Failed to confirm booking');
    }
  }

  private async getBranchCache(branchId: string): Promise<Branch | null> {
    const cached = await prisma.branchCache.findUnique({
      where: { id: branchId },
    });

    if (cached) {
      return {
        id: cached.id,
        name: cached.name,
        address: cached.address || undefined,
        city: cached.city || undefined,
        country: cached.country || undefined,
        timezone: cached.timezone || undefined,
      };
    }

    try {
      const companies = await timifyClient.getCompanies();
      const company = companies.find((c) => c.id === branchId);

      if (company) {
        await prisma.branchCache.upsert({
          where: { id: branchId },
          update: {
            name: company.name,
            address: company.address || null,
            city: company.city || null,
            country: company.country || null,
            timezone: company.timezone || null,
          },
          create: {
            id: branchId,
            name: company.name,
            address: company.address || null,
            city: company.city || null,
            country: company.country || null,
            timezone: company.timezone || null,
          },
        });

        return {
          id: company.id,
          name: company.name,
          address: company.address,
          city: company.city,
          country: company.country,
          timezone: company.timezone,
        };
      }
    } catch (error) {
      logger.warn('Failed to fetch branch from TIMIFY for cache', { branchId, error });
    }

    return null;
  }

  private async getServiceCache(branchId: string, serviceId: string): Promise<Service | null> {
    try {
      const services = await timifyClient.getServices(branchId);
      const service = services.find((s) => s.id === serviceId);

      if (service) {
        return {
          id: service.id,
          name: service.name,
          durationMinutes: service.duration,
          price: service.price,
        };
      }
    } catch (error) {
      logger.warn('Failed to fetch service from TIMIFY', { branchId, serviceId, error });
    }

    return null;
  }

  async listBookings(params: {
    userId: string;
    status: 'upcoming' | 'past' | 'all';
    limit: number;
    cursor?: string;
  }): Promise<{
    items: Array<{
      id: string;
      startDateTime: string;
      status: string;
      branch: { id: string; name?: string; city?: string };
      service: { id: string; name?: string };
    }>;
    nextCursor: string | null;
  }> {
    const now = new Date();
    const limit = Math.min(params.limit, 50);

    let whereClause: {
      userId: string;
      OR?: Array<{ status: string } | { startDateTime: { lt: Date } }>;
      status?: string;
      startDateTime?: { gte?: Date };
    } = {
      userId: params.userId,
    };

    if (params.status === 'upcoming') {
      whereClause.status = 'CONFIRMED';
      whereClause.startDateTime = { gte: now };
    } else if (params.status === 'past') {
      whereClause.OR = [
        { startDateTime: { lt: now } },
        { status: 'CANCELED' },
      ];
    }

    const orderBy: Array<{ startDateTime: 'asc' | 'desc' } | { id: 'asc' | 'desc' }> =
      params.status === 'upcoming'
        ? [{ startDateTime: 'asc' }, { id: 'asc' }]
        : [{ startDateTime: 'desc' }, { id: 'desc' }];

    let cursorWhere: Record<string, unknown> | undefined;
    if (params.cursor) {
      try {
        const [dateStr, id] = params.cursor.split('|');
        const cursorDate = new Date(dateStr);
        const cursorId = id;

        if (params.status === 'upcoming') {
          cursorWhere = {
            OR: [
              { startDateTime: { gt: cursorDate } },
              {
                startDateTime: cursorDate,
                id: { gt: cursorId },
              },
            ],
          };
        } else {
          cursorWhere = {
            OR: [
              { startDateTime: { lt: cursorDate } },
              {
                startDateTime: cursorDate,
                id: { lt: cursorId },
              },
            ],
          };
        }
      } catch {
        throw new AppError(ErrorCode.VALIDATION_ERROR, 'Invalid cursor format', 400);
      }
    }

    const finalWhere: Record<string, unknown> = {
      ...whereClause,
    };

    if (cursorWhere) {
      if (finalWhere.OR) {
        finalWhere.AND = [
          { OR: finalWhere.OR },
          cursorWhere,
        ];
        delete finalWhere.OR;
      } else {
        finalWhere.AND = [cursorWhere];
      }
    }

    const bookings = await prisma.booking.findMany({
      where: finalWhere as {
        userId: string;
        status?: string;
        startDateTime?: { gte?: Date };
        OR?: Array<{ status: string } | { startDateTime: { lt: Date } }>;
        AND?: Array<Record<string, unknown>>;
      },
      orderBy,
      take: limit + 1,
    });

    const hasMore = bookings.length > limit;
    const items = bookings.slice(0, limit);

    const branchIds = [...new Set(items.map((b) => b.branchId))];
    const branchCacheMap = new Map<string, Branch | null>();

    for (const branchId of branchIds) {
      const branch = await this.getBranchCache(branchId);
      branchCacheMap.set(branchId, branch);
    }

    const serviceMap = new Map<string, Service | null>();
    for (const booking of items) {
      const key = `${booking.branchId}:${booking.serviceId}`;
      if (!serviceMap.has(key)) {
        const service = await this.getServiceCache(booking.branchId, booking.serviceId);
        serviceMap.set(key, service);
      }
    }

    const result = items.map((booking) => {
      const branch = branchCacheMap.get(booking.branchId);
      const service = serviceMap.get(`${booking.branchId}:${booking.serviceId}`);

      return {
        id: booking.id,
        startDateTime: booking.startDateTime.toISOString(),
        status: booking.status,
        branch: branch
          ? {
              id: branch.id,
              name: branch.name,
              city: branch.city,
            }
          : { id: booking.branchId },
        service: service
          ? {
              id: service.id,
              name: service.name,
            }
          : { id: booking.serviceId },
      };
    });

    const nextCursor = hasMore && items.length > 0
      ? `${items[items.length - 1].startDateTime.toISOString()}|${items[items.length - 1].id}`
      : null;

    return {
      items: result,
      nextCursor,
    };
  }

  async getBookingById(params: { userId: string; bookingId: string }): Promise<{
    id: string;
    startDateTime: string;
    status: string;
    branch: { id: string; name?: string; address?: string; city?: string; timezone?: string };
    service: { id: string; name?: string; durationMinutes?: number };
    timifyAppointmentId?: string;
  }> {
    const booking = await prisma.booking.findUnique({
      where: { id: params.bookingId },
    });

    if (!booking) {
      throw new AppError(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found', 404);
    }

    if (booking.userId !== params.userId) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Booking does not belong to user', 403);
    }

    const branch = await this.getBranchCache(booking.branchId);
    const service = await this.getServiceCache(booking.branchId, booking.serviceId);

    return {
      id: booking.id,
      startDateTime: booking.startDateTime.toISOString(),
      status: booking.status,
      branch: branch
        ? {
            id: branch.id,
            name: branch.name,
            address: branch.address,
            city: branch.city,
            timezone: branch.timezone,
          }
        : { id: booking.branchId },
      service: service
        ? {
            id: service.id,
            name: service.name,
            durationMinutes: service.durationMinutes,
          }
        : { id: booking.serviceId },
      timifyAppointmentId: booking.timifyAppointmentId || undefined,
    };
  }

  async cancelBooking(params: { userId: string; bookingId: string }): Promise<{ status: string }> {
    const booking = await prisma.booking.findUnique({
      where: { id: params.bookingId },
    });

    if (!booking) {
      throw new AppError(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found', 404);
    }

    if (booking.userId !== params.userId) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Booking does not belong to user', 403);
    }

    if (booking.status === 'CANCELED') {
      throw new AppError(ErrorCode.BOOKING_NOT_CANCELABLE, 'Booking is already canceled', 400);
    }

    if (booking.status !== 'CONFIRMED') {
      throw new AppError(ErrorCode.BOOKING_NOT_CANCELABLE, 'Only confirmed bookings can be canceled', 400);
    }

    const now = new Date();
    if (booking.startDateTime <= now) {
      throw new AppError(ErrorCode.BOOKING_NOT_CANCELABLE, 'Cannot cancel past bookings', 400);
    }

    const cutoffMinutes = Number(process.env.BOOKING_CANCEL_CUTOFF_MINUTES) || config.BOOKING_CANCEL_CUTOFF_MINUTES;
    const cutoffTime = new Date(booking.startDateTime.getTime() - cutoffMinutes * 60 * 1000);

    if (now >= cutoffTime) {
      throw new AppError(
        ErrorCode.BOOKING_NOT_CANCELABLE,
        `Booking cannot be canceled less than ${cutoffMinutes} minutes before start time`,
        400
      );
    }

    const enableLocalCancel = process.env.ENABLE_LOCAL_CANCEL === 'true';
    if (!enableLocalCancel) {
      throw new AppError(ErrorCode.CANCEL_NOT_AVAILABLE, 'Cancellation is not available', 400);
    }

    await prisma.booking.update({
      where: { id: params.bookingId },
      data: { status: 'CANCELED' },
    });

    logger.info('Booking canceled', {
      bookingId: params.bookingId,
      userId: params.userId,
    });

    return { status: 'CANCELED' };
  }
}

export const bookingService = new BookingService();
