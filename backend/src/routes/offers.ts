/**
 * Offers routes
 * Client-side promotions: feed (active offers), activate, and my offers (under /client).
 */

import { Router, Request, Response, NextFunction } from 'express';
import { clientOffersService } from '../modules/client_offers/service';
import { publicReadLimiter } from '../middleware/rateLimit';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();

/**
 * GET /api/v1/offers
 * Active offers feed: isActive, startsAt <= now, not expired.
 */
router.get('/', publicReadLimiter, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const items = await clientOffersService.getActiveOffers();
    res.json({ data: items });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/v1/offers/:id/request-activation
 * Create pending_scan activation and return activationId + qrPayload for barber scan.
 */
router.post(
  '/:id/request-activation',
  authenticate,
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) {
        return next(new Error('Unauthorized'));
      }
      const offerId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
      if (!offerId) {
        return next(new Error('Offer ID required'));
      }
      const result = await clientOffersService.requestActivation(offerId, req.userId);
      res.status(201).json({ data: result });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/v1/offers/activations/:activationId
 * Cancel pending_scan activation when user exits QR screen without barber scan.
 */
router.delete(
  '/activations/:activationId',
  authenticate,
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) return next(new Error('Unauthorized'));
      const activationId = Array.isArray(req.params.activationId) ? req.params.activationId[0] : req.params.activationId;
      if (!activationId) return next(new Error('Activation ID required'));
      await clientOffersService.cancelActivation(activationId, req.userId);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
);

/**
 * DELETE /api/v1/offers/:offerId/activation
 * Cancel current user's pending_scan for this offer (by offerId; used when exiting QR screen).
 */
router.delete(
  '/:offerId/activation',
  authenticate,
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) return next(new Error('Unauthorized'));
      const offerId = Array.isArray(req.params.offerId) ? req.params.offerId[0] : req.params.offerId;
      if (!offerId) return next(new Error('Offer ID required'));
      await clientOffersService.cancelPendingActivationByOfferId(offerId, req.userId);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
);

export default router;
