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
 *     parameters:
 *       - in: query
 *         name: salonId
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Filter by salon ID (optional)
 *     responses:
 *       200:
 *         description: List of active barbers (light payload, no bio/gallery)
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
 *                     required: [id, name, role]
 *                     properties:
 *                       id:
 *                         type: string
 *                         format: uuid
 *                       name:
 *                         type: string
 *                       role:
 *                         type: string
 *                         example: BARBER
 *                       age:
 *                         type: integer
 *                         nullable: true
 *                       origin:
 *                         type: string
 *                         nullable: true
 *                       imageUrl:
 *                         type: string
 *                         format: uri
 *                         nullable: true
 *                       salon:
 *                         type: object
 *                         nullable: true
 *                         properties:
 *                           id:
 *                             type: string
 *                             format: uuid
 *                           name:
 *                             type: string
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/', publicReadLimiter, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const salonId = req.query.salonId as string | undefined;
    // eslint-disable-next-line no-console
    console.log('Barbers list - salonId filter:', salonId);
    const barbers = await barbersService.listBarbers(salonId);
    // eslint-disable-next-line no-console
    console.log('Barbers count:', barbers.length);
    res.json({ data: barbers });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/barbers/{id}:
 *   get:
 *     summary: Get barber details (full object for detail screen)
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
 *         description: Full barber details including bio, videoUrl, gallery, salon
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [data]
 *               properties:
 *                 data:
 *                   type: object
 *                   required: [id, name, role]
 *                   properties:
 *                     id:
 *                       type: string
 *                       format: uuid
 *                     name:
 *                       type: string
 *                     role:
 *                       type: string
 *                       example: BARBER
 *                     age:
 *                       type: integer
 *                       nullable: true
 *                     origin:
 *                       type: string
 *                       nullable: true
 *                     bio:
 *                       type: string
 *                       nullable: true
 *                     videoUrl:
 *                       type: string
 *                       format: uri
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
 *                     salon:
 *                       type: object
 *                       nullable: true
 *                       properties:
 *                         id:
 *                           type: string
 *                           format: uuid
 *                         name:
 *                           type: string
 *                         address:
 *                           type: string
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
