/**
 * Offers routes
 * Public endpoints for viewing offers
 */

import { Router, Request, Response, NextFunction } from 'express';
import { offersService } from '../modules/offers/service';
import { listOffersQuerySchema, offerIdParamSchema } from '../modules/offers/validation';
import { publicReadLimiter } from '../middleware/rateLimit';

const router = Router();

/**
 * @swagger
 * /api/v1/offers:
 * get:
 * summary: Get list of offers
 * tags: [Offers]
 * parameters:
 * - in: query
 * name: salonId
 * schema:
 * type: string
 * format: uuid
 * description: Filter offers by salon ID
 * - in: query
 * name: status
 * schema:
 * type: string
 * enum: [active, all]
 * default: active
 * - in: query
 * name: limit
 * schema:
 * type: integer
 * minimum: 1
 * maximum: 50
 * default: 20
 * - in: query
 * name: cursor
 * schema:
 * type: string
 * responses:
 * 200:
 * description: List of offers
 */
router.get('/', publicReadLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // 1. Extract and validate query parameters, including salonId
    const query = listOffersQuerySchema.parse({
      status: typeof req.query.status === 'string' ? req.query.status : undefined,
      limit: typeof req.query.limit === 'string' ? req.query.limit : undefined,
      cursor: typeof req.query.cursor === 'string' ? req.query.cursor : undefined,
      salonId: typeof req.query.salonId === 'string' ? req.query.salonId : undefined, // ADDED
    });

    // 2. Pass the validated query (containing salonId) to the service
    const result = await offersService.listOffers(query);
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', publicReadLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const params = offerIdParamSchema.parse({ id: req.params.id });
    const offer = await offersService.getOfferById(params.id);
    res.json({ data: offer });
  } catch (error) {
    next(error);
  }
});

export default router;