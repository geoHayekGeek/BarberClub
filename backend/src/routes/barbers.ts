/**
 * Barbers routes
 * Public endpoints for viewing barbers
 */

import { Router, Request, Response, NextFunction } from 'express';
import { barbersService } from '../modules/barbers/service';
import { barberIdParamSchema } from '../modules/barbers/validation';
import { publicReadLimiter } from '../middleware/rateLimit';

const router = Router();

/**
 * @swagger
 * /api/v1/barbers:
 *   get:
 *     summary: Get list of active barbers
 *     tags: [Barbers]
 *     responses:
 *       200:
 *         description: List of active barbers
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
 *                       firstName:
 *                         type: string
 *                       lastName:
 *                         type: string
 *                       bio:
 *                         type: string
 *                       experienceYears:
 *                         type: integer
 *                         nullable: true
 *                       images:
 *                         type: array
 *                         items:
 *                           type: string
 *                       salons:
 *                         type: array
 *                         items:
 *                           type: object
 *                           properties:
 *                             id:
 *                               type: string
 *                               format: uuid
 *                             name:
 *                               type: string
 *                             city:
 *                               type: string
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/', publicReadLimiter, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const barbers = await barbersService.listBarbers();
    res.json({ data: barbers });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/barbers/{id}:
 *   get:
 *     summary: Get barber details
 *     tags: [Barbers]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Barber details with associated salons
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
 *                     firstName:
 *                       type: string
 *                     lastName:
 *                       type: string
 *                     bio:
 *                       type: string
 *                     experienceYears:
 *                       type: integer
 *                       nullable: true
 *                     interests:
 *                       type: array
 *                       items:
 *                         type: string
 *                     images:
 *                       type: array
 *                       items:
 *                         type: string
 *                     salons:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           id:
 *                             type: string
 *                             format: uuid
 *                           name:
 *                             type: string
 *                           city:
 *                             type: string
 *       400:
 *         description: Invalid barber ID format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Barber not found
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
    const params = barberIdParamSchema.parse({ id: req.params.id });
    const barber = await barbersService.getBarberById(params.id);
    res.json({ data: barber });
  } catch (error) {
    next(error);
  }
});

export default router;
