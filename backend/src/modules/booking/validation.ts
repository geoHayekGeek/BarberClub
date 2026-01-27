/**
 * Booking validation schemas
 */

import { z } from 'zod';

export const availabilityQuerySchema = z.object({
  branchId: z.string().min(1),
  serviceId: z.string().min(1),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  resourceId: z.string().optional(),
});

export const reserveSchema = z.object({
  branchId: z.string().min(1),
  serviceId: z.string().min(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  time: z.string().regex(/^\d{2}:\d{2}$/),
  resourceId: z.string().optional(),
});

export const confirmSchema = z.object({
  reservationId: z.string().uuid(),
});

export const listBookingsQuerySchema = z.object({
  status: z.enum(['upcoming', 'past', 'all']).optional().default('upcoming'),
  limit: z.string().optional().transform((val) => val ? Number(val) : 20).pipe(z.number().int().positive().max(50)),
  cursor: z.string().optional(),
});

export const bookingIdParamSchema = z.object({
  id: z.string().uuid(),
});

export const branchIdParamSchema = z.object({
  branchId: z.string().min(1),
});
