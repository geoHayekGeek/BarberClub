/**
 * Salons routes
 * Public endpoints for viewing salons
 */

import { Router, Request, Response, NextFunction } from 'express';
import { salonsService } from '../modules/salons/service';
import { salonIdParamSchema } from '../modules/salons/validation';
import { publicReadLimiter } from '../middleware/rateLimit';

const router = Router();

/**
 * @swagger
 * /api/v1/salons:
 *   get:
 *     summary: Get list of active salons
 *     tags: [Salons]
 *     responses:
 *       200:
 *         description: List of active salons
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                         format: uuid
 *                       name:
 *                         type: string
 *                       city:
 *                         type: string
 *                       address:
 *                         type: string
 *                       description:
 *                         type: string
 *                       openingHours:
 *                         type: string
 *                       images:
 *                         type: array
 *                         items:
 *                           type: string
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
 *     summary: Get salon details
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
 *         description: Salon details with associated barbers
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
 *                     name:
 *                       type: string
 *                     city:
 *                       type: string
 *                     address:
 *                       type: string
 *                     description:
 *                       type: string
 *                     openingHours:
 *                       type: string
 *                     images:
 *                       type: array
 *                       items:
 *                         type: string
 *                     barbers:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                             format: uuid
 *                           firstName:
 *                             type: string
 *                           lastName:
 *                             type: string
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
