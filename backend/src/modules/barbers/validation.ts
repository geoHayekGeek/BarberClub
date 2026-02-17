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
  bio: z.string().max(2000).optional(),
  experienceYears: z.number().int().positive().nullable().default(null),
  interests: z.array(z.string()).default([]),
  images: z.array(z.string().url()).default([]),
  salonIds: z.array(z.string().uuid()).min(1),
  isActive: z.boolean().default(true),
  age: z.number().int().positive().optional(),
  origin: z.string().max(100).optional(),
  videoUrl: z.string().url().optional(),
  imageUrl: z.string().url().optional(),
  gallery: z.array(z.string().url()).default([]),
});

export const createBarberBodySchema = createBarberSchema.omit({ adminSecret: true });
