/**
 * User routes
 * Device token for push notifications
 */

import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import prisma from '../db/client';
import { authenticate, AuthRequest } from '../middleware/auth';
import { validate } from '../middleware/validate';

const router = Router();

const deviceTokenSchema = z.object({
  token: z.string().min(1),
});

/** POST /users/device-token — Save FCM token for push notifications (auth required). */
router.post(
  '/device-token',
  authenticate,
  validate(deviceTokenSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const userId = (req as AuthRequest).userId!;
      const { token } = req.body as { token: string };

      await prisma.user.update({
        where: { id: userId },
        data: { fcmToken: token },
      });

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
);

export default router;
