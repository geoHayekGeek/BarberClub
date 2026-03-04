/**
 * Client routes
 * Authenticated client-only endpoints (e.g. my offers, activation states).
 */

import { Router, Response, NextFunction } from 'express';
import { clientOffersService } from '../modules/client_offers/service';
import { authenticate, AuthRequest } from '../middleware/auth';

const router = Router();

/**
 * GET /api/v1/client/offers
 * Returns the authenticated user's activated offers (including pending_scan).
 */
router.get('/offers', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      return next(new Error('Unauthorized'));
    }
    const items = await clientOffersService.getMyOffers(req.userId);
    res.json({ data: items });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/v1/client/offers/activation-states
 * Returns { offerId: status } for all offer activations of the user (for feed button states).
 */
router.get('/offers/activation-states', authenticate, async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) {
      return next(new Error('Unauthorized'));
    }
    const states = await clientOffersService.getActivationStateByOffer(req.userId);
    res.json({ data: states });
  } catch (error) {
    next(error);
  }
});

export default router;
