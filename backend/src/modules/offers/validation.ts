/**
 * Offers validation schemas
 */

import { z } from 'zod';

export const listOffersQuerySchema = z.object({
  status: z.enum(['active', 'all']).optional().default('active'),
  limit: z.string().optional().transform((val) => val ? Number(val) : 20).pipe(z.number().int().positive().max(50)),
  cursor: z.string().optional(),
});

export const offerIdParamSchema = z.object({
  id: z.string().uuid(),
});

const createOfferBaseSchema = z.object({
  adminSecret: z.string(),
  title: z.string().min(1),
  description: z.string().min(1),
  imageUrl: z.string().url().nullable().default(null),
  validFrom: z.string().datetime().nullable().default(null),
  validTo: z.string().datetime().nullable().default(null),
  isActive: z.boolean().default(true),
});

export const createOfferSchema = createOfferBaseSchema.refine(
  (data) => {
    if (data.validFrom && data.validTo) {
      return new Date(data.validFrom) <= new Date(data.validTo);
    }
    return true;
  },
  {
    message: 'validFrom must be less than or equal to validTo',
    path: ['validTo'],
  }
);

export const createOfferBodySchema = createOfferBaseSchema.omit({ adminSecret: true }).refine(
  (data) => {
    if (data.validFrom && data.validTo) {
      return new Date(data.validFrom) <= new Date(data.validTo);
    }
    return true;
  },
  {
    message: 'validFrom must be less than or equal to validTo',
    path: ['validTo'],
  }
);
