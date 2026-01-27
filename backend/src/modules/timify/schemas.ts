/**
 * Zod schemas for TIMIFY API responses
 * Used to validate and parse TIMIFY responses safely
 */

import { z } from 'zod';

export const timifyCompanySchema = z.object({
  id: z.string(),
  name: z.string(),
  address: z.string().optional(),
  city: z.string().optional(),
  country: z.string().optional(),
  timezone: z.string().optional(),
});

export const timifyServiceSchema = z.object({
  id: z.string(),
  name: z.string(),
  duration: z.number().int().min(0),
  price: z.number().optional(),
  currency: z.string().optional(),
});

export const timifyAvailabilitySlotSchema = z.object({
  start: z.string(),
  end: z.string(),
  resource_id: z.string().optional(),
});

export const timifyAvailabilityResponseSchema = z.object({
  calendar_begin: z.string(),
  calendar_end: z.string(),
  on_days: z.array(z.string()),
  off_days: z.array(z.string()).optional(),
  slots: z.array(timifyAvailabilitySlotSchema).optional(),
});

export const timifyReservationResponseSchema = z.object({
  reservation_id: z.string(),
  secret: z.string(),
  expires_at: z.string(),
});

export const timifyConfirmResponseSchema = z.object({
  appointment_id: z.string().optional(),
  status: z.string(),
});

export const timifyErrorResponseSchema = z.object({
  error: z.string().optional(),
  message: z.string().optional(),
  code: z.string().optional(),
});
