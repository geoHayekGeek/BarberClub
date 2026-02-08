/**
 * Loyalty routes
 */

import { Router, Request, Response, NextFunction } from 'express';
import { loyaltyService } from '../modules/loyalty/service';
import { authenticate, AuthRequest } from '../middleware/auth';
import { requireUser } from '../middleware/requireRole';
import { AppError, ErrorCode } from '../utils/errors';
import { validate } from '../middleware/validate';
import { qrScanLimiter } from '../middleware/rateLimit';
import { z } from 'zod';

const router = Router();

const scanSchema = z.object({
  qrPayload: z.string().min(1),
});

/**
 * @swagger
 * /api/v1/loyalty/me:
 *   get:
 *     summary: Get current user's loyalty state
 *     tags: [Loyalty]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Loyalty state
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     stamps:
 *                       type: number
 *                     target:
 *                       type: number
 *                     remaining:
 *                       type: number
 *                     eligibleForReward:
 *                       type: boolean
 *       401:
 *         description: Unauthorized
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
router.get('/me', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    }
    const state = await loyaltyService.getState(req.userId);
    res.json({ data: state });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/loyalty/qr:
 *   get:
 *     summary: Generate QR code for loyalty redemption
 *     tags: [Loyalty]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: QR code data
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     qrPayload:
 *                       type: string
 *                       example: "LOYALTY:abc123..."
 *                     expiresAt:
 *                       type: string
 *                       format: date-time
 *       400:
 *         description: Loyalty target not reached
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
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
/** POST /loyalty/qr — V1 minimal: generate QR token for coiffeur to scan (USER only). */
router.post(
  '/qr',
  authenticate,
  requireUser,
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) {
        throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
      }
      const data = await loyaltyService.generateQrToken(req.userId);
      res.json({ data });
    } catch (error) {
      next(error);
    }
  }
);

/** GET /loyalty/qr — legacy: generate reward redemption QR (eligible users). */
router.get('/qr', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    }
    const qrData = await loyaltyService.generateQR(req.userId);
    res.json({ data: qrData });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/loyalty/scan:
 *   post:
 *     summary: Scan and redeem QR code (salon side)
 *     tags: [Loyalty]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - qrPayload
 *             properties:
 *               qrPayload:
 *                 type: string
 *                 example: "LOYALTY:abc123..."
 *     responses:
 *       200:
 *         description: QR code redeemed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     status:
 *                       type: string
 *                       example: "redeemed"
 *                     resetStamps:
 *                       type: boolean
 *       400:
 *         description: Invalid or expired QR code
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       429:
 *         description: Too many requests
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
router.post('/scan', qrScanLimiter, validate(scanSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await loyaltyService.scanQR(req.body.qrPayload);
    res.json({ data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * @swagger
 * /api/v1/loyalty/redeem:
 *   post:
 *     summary: Redeem loyalty reward (legacy endpoint)
 *     tags: [Loyalty]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Reward redeemed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 stamps:
 *                   type: number
 *                 target:
 *                   type: number
 *                 rewardAvailable:
 *                   type: boolean
 *                 remaining:
 *                   type: number
 *       400:
 *         description: Not enough stamps to redeem
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
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post('/redeem', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    }
    const state = await loyaltyService.redeem(req.userId);
    res.json(state);
  } catch (error) {
    next(error);
  }
});

export default router;
