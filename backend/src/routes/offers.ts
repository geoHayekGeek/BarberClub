/**
 * Offers routes
 * Public endpoint for global promotions (active only)
 */

import { Router, Request, Response, NextFunction } from 'express';
import { globalOffersService } from '../modules/global_offers/service';
import { publicReadLimiter } from '../middleware/rateLimit';

const router = Router();

/**
 * @swagger
 * /api/v1/offers:
 *   get:
 *     summary: Get list of active global offers (promotions)
 *     tags: [Offers]
 *     responses:
 *       200:
 *         description: List of active global offers
 */
router.get('/', publicReadLimiter, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const items = await globalOffersService.listActive();
    res.json({ data: items });
  } catch (error) {
    next(error);
  }
});

export default router;