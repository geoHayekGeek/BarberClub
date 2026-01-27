/**
 * Barbers validation schemas
 */

import { z } from 'zod';

export const barberIdParamSchema = z.object({
  id: z.string().uuid(),
});

export const createBarberSchema = z.object({
  adminSecret: z.string(),
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  bio: z.string().min(1),
  experienceYears: z.number().int().positive().nullable().default(null),
  interests: z.array(z.string()).default([]),
  images: z.array(z.string().url()).default([]),
  salonIds: z.array(z.string().uuid()).min(1),
  isActive: z.boolean().default(true),
});

export const createBarberBodySchema = createBarberSchema.omit({ adminSecret: true });
