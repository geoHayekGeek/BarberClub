/**
 * Salons validation schemas
 */

import { z } from 'zod';

export const salonIdParamSchema = z.object({
  id: z.string().uuid(),
});

const dayHoursSchema = z.object({
  open: z.string().optional(),
  close: z.string().optional(),
  closed: z.boolean().optional(),
});

export const openingHoursStructureSchema = z.object({
  monday: dayHoursSchema,
  tuesday: dayHoursSchema,
  wednesday: dayHoursSchema,
  thursday: dayHoursSchema,
  friday: dayHoursSchema,
  saturday: dayHoursSchema,
  sunday: dayHoursSchema,
});

export const createSalonSchema = z.object({
  adminSecret: z.string(),
  name: z.string().min(1),
  city: z.string().min(1),
  address: z.string().min(1),
  description: z.string().max(5000).optional(),
  openingHours: z.string().min(1),
  openingHoursStructured: openingHoursStructureSchema.optional(),
  images: z.array(z.string().url()).default([]),
  imageUrl: z.string().url().optional(),
  gallery: z.array(z.string().url()).default([]),
  phone: z.string().optional().default(''),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  isActive: z.boolean().default(true),
  timifyUrl: z.string().url().optional().or(z.literal('')),
});

export const createSalonBodySchema = createSalonSchema.omit({ adminSecret: true });
