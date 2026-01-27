/**
 * Booking routes
 */

import { Router, Request, Response, NextFunction } from 'express';
import { bookingService } from '../modules/booking/service';
import { availabilityQuerySchema, reserveSchema, confirmSchema, branchIdParamSchema } from '../modules/booking/validation';
import { validate } from '../middleware/validate';
import { authenticate, AuthRequest } from '../middleware/auth';
import { bookingLimiter } from '../middleware/rateLimit';

const router = Router();

/**
 * @swagger
 * /api/v1/booking/branches:
 *   get:
 *     summary: Get list of bookable branches
 *     tags: [Booking]
 *     responses:
 *       200:
 *         description: List of branches
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
 *                       name:
 *                         type: string
 *                       address:
 *                         type: string
 *                         nullable: true
 *                       city:
 *                         type: string
 *                         nullable: true
 *                       country:
 *                         type: string
 *                         nullable: true
 *                       timezone:
 *                         type: string
 *                         nullable: true
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get('/branches', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const branches = await bookingService.getBranches();
    res.json({ data: branches });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/booking/branches/{branchId}/services:
 *   get:
 *     summary: Get services for a branch
 *     tags: [Booking]
 *     parameters:
 *       - in: path
 *         name: branchId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: List of services
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
 *                       name:
 *                         type: string
 *                       durationMinutes:
 *                         type: number
 *                       price:
 *                         type: number
 *                         nullable: true
 *       400:
 *         description: Invalid branch ID format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Branch not found
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
router.get('/branches/:branchId/services', validate(branchIdParamSchema, 'params'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const params = branchIdParamSchema.parse({ branchId: req.params.branchId });
    const services = await bookingService.getBranchServices(params.branchId);
    res.json({ data: services });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/booking/availability:
 *   get:
 *     summary: Get availability for a service
 *     tags: [Booking]
 *     parameters:
 *       - in: query
 *         name: branchId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: serviceId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: startDate
 *         required: true
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: endDate
 *         required: true
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: resourceId
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Availability data
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     calendarBegin:
 *                       type: string
 *                       format: date
 *                     calendarEnd:
 *                       type: string
 *                       format: date
 *                     onDays:
 *                       type: array
 *                       items:
 *                         type: string
 *                         format: date
 *                     offDays:
 *                       type: array
 *                       items:
 *                         type: string
 *                         format: date
 *                     timesByDay:
 *                       type: object
 *                       additionalProperties:
 *                         type: array
 *                         items:
 *                           type: string
 *                           format: time
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
router.get('/availability', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const query = availabilityQuerySchema.parse({
      branchId: typeof req.query.branchId === 'string' ? req.query.branchId : undefined,
      serviceId: typeof req.query.serviceId === 'string' ? req.query.serviceId : undefined,
      startDate: typeof req.query.startDate === 'string' ? req.query.startDate : undefined,
      endDate: typeof req.query.endDate === 'string' ? req.query.endDate : undefined,
      resourceId: typeof req.query.resourceId === 'string' ? req.query.resourceId : undefined,
    });
    const availability = await bookingService.getAvailability(query);
    res.json({ data: availability });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/booking/reserve:
 *   post:
 *     summary: Reserve a booking slot
 *     tags: [Booking]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - branchId
 *               - serviceId
 *               - date
 *               - time
 *             properties:
 *               branchId:
 *                 type: string
 *               serviceId:
 *                 type: string
 *               date:
 *                 type: string
 *                 format: date
 *               time:
 *                 type: string
 *                 format: time
 *               resourceId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Reservation created
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     reservationId:
 *                       type: string
 *                       format: uuid
 *                     expiresAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Invalid request
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       409:
 *         description: Booking slot unavailable
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
router.post('/reserve', bookingLimiter, authenticate, validate(reserveSchema), async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'User ID not found' } });
      return;
    }
    const reservation = await bookingService.reserve({
      userId: req.userId,
      ...req.body,
    });
    res.status(201).json({ data: reservation });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/booking/confirm:
 *   post:
 *     summary: Confirm a reservation
 *     tags: [Booking]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - reservationId
 *             properties:
 *               reservationId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       200:
 *         description: Booking confirmed
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
 *                     userId:
 *                       type: string
 *                       format: uuid
 *                     branchId:
 *                       type: string
 *                     serviceId:
 *                       type: string
 *                     resourceId:
 *                       type: string
 *                       nullable: true
 *                     startDateTime:
 *                       type: string
 *                       format: date-time
 *                     timifyAppointmentId:
 *                       type: string
 *                       nullable: true
 *                     status:
 *                       type: string
 *                       enum: [CONFIRMED, CANCELED]
 *                     createdAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Invalid request or reservation expired/used
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       403:
 *         description: Forbidden
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       404:
 *         description: Reservation not found
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
router.post('/confirm', bookingLimiter, authenticate, validate(confirmSchema), async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'User ID not found' } });
      return;
    }
    const booking = await bookingService.confirm({
      userId: req.userId,
      ...req.body,
    });
    res.json({ data: booking });
  } catch (error) {
    next(error);
  }
});

export default router;
