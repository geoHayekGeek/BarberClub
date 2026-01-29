/**
 * Authentication routes
 */

import { Router, Request, Response, NextFunction } from 'express';
import { authService } from '../modules/auth/service';
import { passwordResetService } from '../modules/auth/passwordResetService';
import { registerSchema, loginSchema, refreshSchema, forgotPasswordSchema, resetPasswordSchema } from '../modules/auth/validation';
import { validate } from '../middleware/validate';
import { authenticate, AuthRequest } from '../middleware/auth';
import { AppError, ErrorCode } from '../utils/errors';
import { authLimiter, passwordResetLimiter } from '../middleware/rateLimit';

const router = Router();

/**
 * @swagger
 * /api/v1/auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - phoneNumber
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 description: Unique email address (case-insensitive)
 *               phoneNumber:
 *                 type: string
 *                 description: Unique phone number in E.164 format (e.g., +1234567890)
 *               password:
 *                 type: string
 *                 minLength: 8
 *               fullName:
 *                 type: string
 *     responses:
 *       201:
 *         description: User registered successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   type: object
 *                 accessToken:
 *                   type: string
 *                 refreshToken:
 *                   type: string
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       409:
 *         description: Email or phone number already registered
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 error:
 *                   type: object
 *                   properties:
 *                     code:
 *                       type: string
 *                       example: USER_ALREADY_EXISTS
 *                     message:
 *                       type: string
 *                       example: Email or phone number already in use
 *                     fields:
 *                       type: object
 *                       properties:
 *                         email:
 *                           type: boolean
 *                         phoneNumber:
 *                           type: boolean
 */
router.post(
  '/register',
  authLimiter,
  validate(registerSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await authService.register(req.body);
      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/auth/login:
 *   post:
 *     summary: Login with email or phone number
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               phoneNumber:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   type: object
 *                 accessToken:
 *                   type: string
 *                 refreshToken:
 *                   type: string
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Invalid credentials
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post(
  '/login',
  authLimiter,
  validate(loginSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await authService.login(req.body);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/auth/refresh:
 *   post:
 *     summary: Refresh access token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Tokens refreshed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 accessToken:
 *                   type: string
 *                 refreshToken:
 *                   type: string
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Invalid or expired refresh token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post(
  '/refresh',
  validate(refreshSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await authService.refresh(req.body.refreshToken);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/auth/logout:
 *   post:
 *     summary: Logout and revoke refresh token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - refreshToken
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Logged out successfully
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post(
  '/logout',
  validate(refreshSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      await authService.logout(req.body.refreshToken);
      res.status(200).json({ message: 'Logged out successfully' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/auth/me:
 *   get:
 *     summary: Get current user profile
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   type: object
 *       401:
 *         description: Unauthorized
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.get(
  '/me',
  authenticate,
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      if (!req.userId) {
        throw new AppError(ErrorCode.UNAUTHORIZED, 'User ID not found', 401);
      }
      const user = await authService.getCurrentUser(req.userId);
      res.status(200).json({ user });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/auth/forgot-password:
 *   post:
 *     summary: Request password reset
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *     responses:
 *       200:
 *         description: If the email exists, a password reset link has been sent
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 */
router.post(
  '/forgot-password',
  passwordResetLimiter,
  validate(forgotPasswordSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      await passwordResetService.forgotPassword(req.body.email);
      res.status(200).json({
        message: 'If the email exists, a password reset link has been sent',
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @swagger
 * /api/v1/auth/reset-password:
 *   post:
 *     summary: Reset password with token
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - token
 *               - newPassword
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               token:
 *                 type: string
 *               newPassword:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password reset successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *       400:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 *       401:
 *         description: Invalid or expired token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/ErrorResponse'
 */
router.post(
  '/reset-password',
  passwordResetLimiter,
  validate(resetPasswordSchema),
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      await passwordResetService.resetPassword(
        req.body.email,
        req.body.token,
        req.body.newPassword
      );
      res.status(200).json({ message: 'Password reset successfully' });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * Redirect route for password reset deep links
 * Serves an HTML page that redirects to barberclub:// deep link
 * This makes the link clickable in email clients and web browsers
 */
router.get('/reset-password-redirect', (req: Request, res: Response) => {
  const { token, email } = req.query;

  if (!token || !email || typeof token !== 'string' || typeof email !== 'string') {
    res.status(400).send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Invalid Reset Link</title>
      </head>
      <body style="margin:0;padding:16px;font-family:sans-serif;">
        <h1>Invalid Reset Link</h1>
        <p>The password reset link is missing required parameters.</p>
      </body>
      </html>
    `);
    return;
  }

  const deepLink = `barberclub://reset-password?token=${encodeURIComponent(token)}&email=${encodeURIComponent(email)}`;
  const safeToken = token.replace(/[<>&"']/g, (c) => {
    const map: Record<string, string> = { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' };
    return map[c] || c;
  });
  const safeEmail = email.replace(/[<>&"']/g, (c) => {
    const map: Record<string, string> = { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' };
    return map[c] || c;
  });

  const escapedDeepLink = deepLink.replace(/&/g, '&amp;');
  
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Opening Barber Club App...</title>
      <meta http-equiv="refresh" content="0;url=${escapedDeepLink}">
      <script>
        // Try immediate redirect
        try {
          window.location.href = ${JSON.stringify(deepLink)};
        } catch (e) {
          // If that fails, try using a link click
          setTimeout(function() {
            var link = document.createElement('a');
            link.href = ${JSON.stringify(deepLink)};
            link.click();
          }, 100);
        }
        
        // Show fallback after 2 seconds if still on page
        setTimeout(function() {
          document.getElementById('fallback').style.display = 'block';
        }, 2000);
      </script>
    </head>
    <body style="margin:0;padding:16px;font-family:sans-serif;text-align:center;">
      <h1>Opening Barber Club App...</h1>
      <p>If the app doesn't open automatically, tap the link below:</p>
      <p><a href="${escapedDeepLink}" style="display:inline-block;padding:12px 20px;background:#1967d2;color:#fff;text-decoration:none;border-radius:6px;font-weight:bold;">Open in Barber Club App</a></p>
      <div id="fallback" style="display:none;margin-top:24px;padding-top:16px;border-top:1px solid #eee;">
        <p style="font-size:14px;color:#666;">If the app didn't open, make sure you have the Barber Club app installed and try tapping the button above.</p>
        <p style="font-size:12px;color:#999;word-break:break-all;">Deep link: ${safeToken.substring(0, 20)}...&email=${safeEmail}</p>
      </div>
    </body>
    </html>
  `);
});

export default router;
