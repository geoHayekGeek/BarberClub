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
 *   get:
 *     summary: Get list of offers
 *     tags: [Offers]
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [active, all]
 *           default: active
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 50
 *           default: 20
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of offers
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     items:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                             format: uuid
 *                           title:
 *                             type: string
 *                           description:
 *                             type: string
 *                           imageUrl:
 *                             type: string
 *                             nullable: true
 *                           validFrom:
 *                             type: string
 *                             format: date-time
 *                             nullable: true
 *                           validTo:
 *                             type: string
 *                             format: date-time
 *                             nullable: true
 *                     nextCursor:
 *                       type: string
 *                       nullable: true
 *       400:
 *         description: Invalid query parameters
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/', publicReadLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const query = listOffersQuerySchema.parse({
      status: typeof req.query.status === 'string' ? req.query.status : undefined,
      limit: typeof req.query.limit === 'string' ? req.query.limit : undefined,
      cursor: typeof req.query.cursor === 'string' ? req.query.cursor : undefined,
    });

    const result = await offersService.listOffers(query);
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/offers/{id}:
 *   get:
 *     summary: Get offer details
 *     tags: [Offers]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Offer details
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       format: uuid
 *                     title:
 *                       type: string
 *                     description:
 *                       type: string
 *                     imageUrl:
 *                       type: string
 *                       nullable: true
 *                     validFrom:
 *                       type: string
 *                       format: date-time
 *                       nullable: true
 *                     validTo:
 *                       type: string
 *                       format: date-time
 *                       nullable: true
 *       400:
 *         description: Invalid offer ID format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Offer not found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
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
