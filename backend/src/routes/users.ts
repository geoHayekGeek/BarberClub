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

      // #region agent log
      import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'users.ts:26',message:'Received device-token request',data:{userId:userId,tokenLength:token.length,tokenPreview:token.substring(0,20)},timestamp:Date.now(),hypothesisId:'B'})+'\n')).catch(()=>{});
      // #endregion

      await prisma.user.update({
        where: { id: userId },
        data: { fcmToken: token },
      });

      // #region agent log
      import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'users.ts:32',message:'FCM token saved to DB SUCCESS',data:{userId:userId},timestamp:Date.now(),hypothesisId:'B'})+'\n')).catch(()=>{});
      // #endregion

      res.status(204).send();
    } catch (error) {
      // #region agent log
      import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'users.ts:35',message:'device-token save FAILED',data:{error:error instanceof Error?error.message:String(error)},timestamp:Date.now(),hypothesisId:'B'})+'\n')).catch(()=>{});
      // #endregion
      next(error);
    }
  }
);

export default router;
