/**
 * Admin routes
 * Write endpoints for manual administration (NOT for mobile app)
 */

import { Router, Request, Response, NextFunction } from 'express';
import { adminAuth } from '../middleware/adminAuth';
import { authenticate } from '../middleware/auth';
import { requireAdmin } from '../middleware/requireRole';
import { adminLimiter, adminLoyaltyScanLimiter, adminLoyaltyEarnLimiter } from '../middleware/rateLimit';
import { validate } from '../middleware/validate';
import { salonsService } from '../modules/salons/service';
import { barbersService } from '../modules/barbers/service';
import { offersService } from '../modules/offers/service';
import { loyaltyService } from '../modules/loyalty/service';
import * as loyaltyV2 from '../modules/loyalty_v2/service';
import { parseQRPayload, QRType } from '../utils/qr';
import { createSalonBodySchema } from '../modules/salons/validation';
import { createBarberBodySchema } from '../modules/barbers/validation';
import { createOfferBodySchema } from '../modules/offers/validation';
import { z } from 'zod';

const router = Router();

const loyaltyScanSchema = z.object({
  qrPayload: z.string().min(1).optional(),
  token: z.string().min(1).optional(),
}).refine(
  (data) => data.qrPayload || data.token,
  { message: 'Either qrPayload or token must be provided' }
);

const loyaltyEarnSchema = z.object({
  qrPayload: z.string().min(1),
  serviceId: z.string().uuid(),
});

/**
 * @swagger
 * /api/v1/admin/salons:
 *   post:
 *     summary: Create a new salon (admin only)
 *     tags: [Admin]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - adminSecret
 *               - name
 *               - city
 *               - address
 *               - description
 *               - openingHours
 *             properties:
 *               adminSecret:
 *                 type: string
 *               name:
 *                 type: string
 *               city:
 *                 type: string
 *               address:
 *                 type: string
 *               description:
 *                 type: string
 *               openingHours:
 *                 type: string
 *               images:
 *                 type: array
 *                 items:
 *                   type: string
 *                 default: []
 *               isActive:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Salon created successfully
 *       400:
 *         description: Validation error
 *       403:
 *         description: Invalid admin secret
 */
router.post(
  '/salons',
  adminLimiter,
  adminAuth,
  validate(createSalonBodySchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const salon = await salonsService.createSalon({
        name: req.body.name,
        city: req.body.city,
        address: req.body.address,
        description: req.body.description,
        openingHours: req.body.openingHours,
        openingHoursStructured: req.body.openingHoursStructured,
        images: req.body.images || [],
        imageUrl: req.body.imageUrl,
        gallery: req.body.gallery,
        phone: req.body.phone,
        latitude: req.body.latitude,
        longitude: req.body.longitude,
        isActive: req.body.isActive !== undefined ? req.body.isActive : true,
        timifyUrl: req.body.timifyUrl,
      });
      res.status(201).json({ data: salon });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/admin/barbers:
 *   post:
 *     summary: Create a new barber (admin only)
 *     tags: [Admin]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - adminSecret
 *               - firstName
 *               - lastName
 *               - bio
 *               - salonIds
 *             properties:
 *               adminSecret:
 *                 type: string
 *               firstName:
 *                 type: string
 *               lastName:
 *                 type: string
 *               bio:
 *                 type: string
 *               experienceYears:
 *                 type: integer
 *                 nullable: true
 *               interests:
 *                 type: array
 *                 items:
 *                   type: string
 *                 default: []
 *               images:
 *                 type: array
 *                 items:
 *                   type: string
 *                 default: []
 *               salonIds:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: uuid
 *               isActive:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Barber created successfully
 *       400:
 *         description: Validation error
 *       403:
 *         description: Invalid admin secret
 */
router.post(
  '/barbers',
  adminLimiter,
  adminAuth,
  validate(createBarberBodySchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const barber = await barbersService.createBarber({
        firstName: req.body.firstName,
        lastName: req.body.lastName,
        displayName: req.body.displayName,
        bio: req.body.bio,
        experienceYears: req.body.experienceYears ?? null,
        interests: req.body.interests || [],
        images: req.body.images || [],
        salonIds: req.body.salonIds,
        isActive: req.body.isActive !== undefined ? req.body.isActive : true,
        age: req.body.age,
        origin: req.body.origin,
        videoUrl: req.body.videoUrl,
        imageUrl: req.body.imageUrl,
        gallery: req.body.gallery,
      });
      res.status(201).json({ data: barber });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/admin/offers:
 *   post:
 *     summary: Create a new offer (admin only)
 *     tags: [Admin]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - adminSecret
 *               - title
 *               - description
 *             properties:
 *               adminSecret:
 *                 type: string
 *               title:
 *                 type: string
 *               description:
 *                 type: string
 *               imageUrl:
 *                 type: string
 *                 nullable: true
 *               validFrom:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *               validTo:
 *                 type: string
 *                 format: date-time
 *                 nullable: true
 *               isActive:
 *                 type: boolean
 *                 default: true
 *     responses:
 *       201:
 *         description: Offer created successfully
 *       400:
 *         description: Validation error
 *       403:
 *         description: Invalid admin secret
 */
router.post(
  '/offers',
  adminLimiter,
  adminAuth,
  validate(createOfferBodySchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const offer = await offersService.createOffer({
        title: req.body.title,
        price: req.body.price,
        salonId: req.body.salonId,
        isActive: req.body.isActive !== undefined ? req.body.isActive : true,
      });
      res.status(201).json({ data: offer });
    } catch (error) {
      next(error);
    }
  }
);

/** GET /admin/services — List offers (prestations) for admin to select before scanning earn QR. */
router.get(
  '/services',
  authenticate,
  requireAdmin,
  async (_req: Request, res: Response, next: NextFunction) => {
    try {
      const { items } = await offersService.listOffers({ limit: 100 });
      const data = items.map((o) => ({
        id: o.id,
        name: o.title,
        priceCents: o.price < 100 ? o.price * 100 : o.price,
        pointsEarned: o.price < 100 ? o.price : Math.floor(o.price / 100),
      }));
      res.json({ data });
    } catch (error) {
      next(error);
    }
  }
);

/** POST /admin/loyalty/earn — V2: admin selected service then scans user earn QR; user gets points (1 pt/eur). */
router.post(
  '/loyalty/earn',
  authenticate,
  requireAdmin,
  adminLoyaltyEarnLimiter,
  validate(loyaltyEarnSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { qrPayload, serviceId } = req.body;
      const result = await loyaltyV2.adminEarnPoints(qrPayload, serviceId);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  }
);

/** POST /admin/loyalty/scan — Admin scans user QR token, increments loyalty point (JWT + role ADMIN). Max 1 scan per 5 seconds. */
router.post(
  '/loyalty/scan',
  authenticate,
  requireAdmin,
  adminLoyaltyScanLimiter,
  validate(loyaltyScanSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const payload = req.body.qrPayload || req.body.token;
      const result = await loyaltyService.scanQrTokenByAdmin(payload);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  }
);

/** POST /admin/loyalty/redeem — Voucher (V) or legacy coupon (C). */
router.post(
  '/loyalty/redeem',
  authenticate,
  requireAdmin,
  validate(loyaltyScanSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const payload = req.body.qrPayload || req.body.token;
      const parsed = parseQRPayload(payload);
      if (parsed?.type === QRType.VOUCHER) {
        const result = await loyaltyV2.adminRedeemVoucher(payload);
        res.status(200).json({ data: result });
        return;
      }
      const result = await loyaltyService.redeemCoupon(payload);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  }
);

export default router;
