/**
 * Loyalty routes (legacy stamps/coupons + v2 points/tiers/rewards)
 */

import { Router, Request, Response, NextFunction } from 'express';
import { loyaltyService } from '../modules/loyalty/service';
import * as loyaltyV2 from '../modules/loyalty_v2/service';
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

const redeemV2Schema = z.object({
  rewardId: z.string().uuid(),
});

const transactionsQuerySchema = z.object({
  limit: z.string().optional().transform((s) => (s ? Math.min(parseInt(s, 10) || 20, 50) : 20)),
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

router.get('/coupons', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    }
    const coupons = await loyaltyService.getCoupons(req.userId);
    res.json({ data: coupons });
  } catch (error) {
    next(error);
  }
});

router.post('/coupons/:id/qr', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    }
    const couponId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await loyaltyService.generateCouponQr(req.userId, couponId);
    res.json({ data });
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
    if (req.body?.rewardId) {
      const result = await loyaltyV2.redeemReward(req.userId, req.body.rewardId);
      res.json({ data: result });
      return;
    }
    const state = await loyaltyService.redeem(req.userId);
    res.json(state);
  } catch (error) {
    next(error);
  }
});

// ---- Loyalty v2 (points, tiers, rewards) ----
/** GET /loyalty/v2/me — current balance, lifetimeEarned, tier, nextTier */
router.get('/v2/me', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    const state = await loyaltyV2.getLoyaltyState(req.userId);
    res.json({ data: state });
  } catch (error) {
    next(error);
  }
});

/** POST /loyalty/v2/qr — generate earn QR (BC|v1|E|token) for admin to scan after selecting service */
router.post(
  '/v2/qr',
  authenticate,
  requireUser,
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
      const data = await loyaltyV2.generateEarnQr(req.userId);
      res.json({ data });
    } catch (error) {
      next(error);
    }
  }
);

/** GET /loyalty/rewards — active rewards catalog */
router.get('/rewards', authenticate, async (_req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const items = await loyaltyV2.listActiveRewards();
    res.json({ data: items });
  } catch (error) {
    next(error);
  }
});

/** POST /loyalty/redeem — v2: body { rewardId } (see above; same route handles legacy if no body) */
router.post(
  '/rewards/redeem',
  authenticate,
  validate(redeemV2Schema),
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
      const result = await loyaltyV2.redeemReward(req.userId, req.body.rewardId);
      res.json({ data: result });
    } catch (error) {
      next(error);
    }
  }
);

/** POST /loyalty/redemptions/:id/qr — generate voucher QR for a PENDING redemption */
router.post(
  '/redemptions/:id/qr',
  authenticate,
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
      const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      const data = await loyaltyV2.generateVoucherQr(req.userId, id);
      res.json({ data });
    } catch (error) {
      next(error);
    }
  }
);

/** GET /loyalty/redemptions — list user's redemptions (vouchers) */
router.get('/redemptions', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    const items = await loyaltyV2.listRedemptions(req.userId);
    res.json({ data: items });
  } catch (error) {
    next(error);
  }
});

/** GET /loyalty/transactions — recent transactions */
router.get('/transactions', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
    const limit = transactionsQuerySchema.parse(req.query).limit ?? 20;
    const items = await loyaltyV2.listTransactions(req.userId, limit);
    res.json({ data: items });
  } catch (error) {
    next(error);
  }
});

export default router;
