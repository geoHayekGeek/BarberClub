/**
 * Salons validation schemas
 */

import { z } from 'zod';

export const salonIdParamSchema = z.object({
  id: z.string().uuid(),
});

export const createSalonSchema = z.object({
  adminSecret: z.string(),
  name: z.string().min(1),
  city: z.string().min(1),
  address: z.string().min(1),
  description: z.string().min(1),
  openingHours: z.string().min(1),
  images: z.array(z.string().url()).default([]),
  isActive: z.boolean().default(true),
});

export const createSalonBodySchema = createSalonSchema.omit({ adminSecret: true });
