/**
 * Development-only routes
 * For local testing and inspection
 */

import { Router, Request, Response } from 'express';
import { devEmailProvider } from '../modules/notifications';
import config from '../config';

const router = Router();

if (config.NODE_ENV === 'development' || config.NODE_ENV === 'test') {
  /**
   * @swagger
   * /api/v1/dev/emails:
   *   get:
   *     summary: Get all sent emails (development only)
   *     tags: [Dev]
   *     description: Returns all emails sent via DevEmailProvider. Only available in development/test.
   *     responses:
   *       200:
   *         description: List of sent emails
   *         content:
   *           application/json:
   *             schema:
   *               type: object
   *               properties:
   *                 emails:
   *                   type: array
   *                   items:
   *                     type: object
   */
  router.get('/emails', (_req: Request, res: Response) => {
    const emails = devEmailProvider.getEmails();
    res.status(200).json({ emails });
  });

  /**
   * @swagger
   * /api/v1/dev/emails:
   *   delete:
   *     summary: Clear all sent emails (development only)
   *     tags: [Dev]
   *     description: Clears the in-memory email store. Only available in development/test.
   *     responses:
   *       200:
   *         description: Emails cleared
   */
  router.delete('/emails', (_req: Request, res: Response) => {
    devEmailProvider.clearEmails();
    res.status(200).json({ message: 'Emails cleared' });
  });
}

export default router;
