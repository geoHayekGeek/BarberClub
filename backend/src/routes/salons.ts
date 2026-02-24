/**
 * Salons routes
 * Public endpoints for viewing salons and prestations (pricing per salon)
 */

import { Router, Request, Response, NextFunction } from 'express';
import { salonsService } from '../modules/salons/service';
import { salonIdParamSchema } from '../modules/salons/validation';
import { offersService } from '../modules/offers/service';
import { publicReadLimiter } from '../middleware/rateLimit';

const router = Router();

/**
 * @swagger
 * /api/v1/salons:
 *   get:
 *     summary: Get list of active salons (lightweight)
 *     tags: [Salons]
 *     responses:
 *       200:
 *         description: List of salons with id, name, imageUrl only
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [data]
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     required: [id, name]
 *                     properties:
 *                       id:
 *                         type: string
 *                         format: uuid
 *                       name:
 *                         type: string
 *                       imageUrl:
 *                         type: string
 *                         format: uri
 *                         nullable: true
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/', publicReadLimiter, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const salons = await salonsService.listSalons();
    res.json({ data: salons });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/salons/{id}:
 *   get:
 *     summary: Get full salon details
 *     tags: [Salons]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Full salon with description, imageUrl, gallery, address, phone, openingHours (structured), lat/long
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [data]
 *               properties:
 *                 data:
 *                   type: object
 *                   required: [id, name, address, phone, openingHours]
 *                   properties:
 *                     id:
 *                       type: string
 *                       format: uuid
 *                     name:
 *                       type: string
 *                     description:
 *                       type: string
 *                       nullable: true
 *                     imageUrl:
 *                       type: string
 *                       format: uri
 *                       nullable: true
 *                     gallery:
 *                       type: array
 *                       items:
 *                         type: string
 *                         format: uri
 *                     address:
 *                       type: string
 *                     phone:
 *                       type: string
 *                     latitude:
 *                       type: number
 *                       format: float
 *                       nullable: true
 *                     longitude:
 *                       type: number
 *                       format: float
 *                       nullable: true
 *                     openingHours:
 *                       type: object
 *                       description: Structured hours per day (monday..sunday). Each day has open, close (HH:mm) and/or closed boolean. Frontend computes open/closed from current time.
 *                       additionalProperties:
 *                         type: object
 *                         properties:
 *                           open:
 *                             type: string
 *                             example: "09:00"
 *                           close:
 *                             type: string
 *                             example: "19:00"
 *                           closed:
 *                             type: boolean
 *                     timifyUrl:
 *                       type: string
 *                       format: uri
 *                       nullable: true
 *       400:
 *         description: Invalid salon ID format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Salon not found
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
/**
 * Prestations (pricing) for a salon - must be before /:id
 */
router.get('/:id/prestations', publicReadLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const params = salonIdParamSchema.parse({ id: req.params.id });
    const result = await offersService.listOffers({ salonId: params.id, limit: 50 });
    res.json({ data: result.items });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', publicReadLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const params = salonIdParamSchema.parse({ id: req.params.id });
    const salon = await salonsService.getSalonById(params.id);
    res.json({ data: salon });
  } catch (error) {
    next(error);
  }
});

export default router;
