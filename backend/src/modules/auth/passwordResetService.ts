/**
 * Password reset service
 * Handles forgot password and reset password functionality
 */

import crypto from 'crypto';
import { Prisma } from '@prisma/client';
import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';
import { hashPassword } from './utils/password';
import { hashToken } from './utils/token';
import { emailProvider } from '../notifications';
import { logger } from '../../utils/logger';
import config from '../../config';

/** Escape URL for use in HTML href (e.g. & to &amp;) so link is valid. */
function escapeUrlForHtml(url: string): string {
  return url.replace(/&/g, '&amp;');
}

/** Escape string for safe display inside HTML (e.g. fallback URL text). */
function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

/** Build standards-compliant HTML email so the reset link is clickable (e.g. in Gmail). */
function buildPasswordResetEmailHtml(redirectUrl: string): string {
  const hrefUrl = escapeUrlForHtml(redirectUrl);
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Password Reset Request</title>
</head>
<body style="margin:0;padding:16px;font-family:sans-serif;font-size:16px;line-height:1.5;">
  <h1 style="font-size:20px;margin-top:0;">Password Reset Request</h1>
  <p>You requested to reset your password.</p>
  <p>Open this link on your phone in the Barber Club app. Do not open it in a computer browser.</p>
  <p>
    <a href="${hrefUrl}" style="display:inline-block;padding:12px 20px;background:#1967d2;color:#fff;text-decoration:none;border-radius:6px;font-weight:bold;">Reset my password</a>
  </p>
  <p>This link will expire in 30 minutes.</p>
  <p>If you did not request this, please ignore this email.</p>
  <p style="margin-top:24px;padding-top:16px;border-top:1px solid #eee;font-size:14px;color:#666;">
    If the button does not work, copy and paste this link:<br>
    <span style="word-break:break-all;">${escapeHtml(redirectUrl)}</span>
  </p>
</body>
</html>`;
}

function buildPasswordResetEmailText(redirectUrl: string, deepLink: string): string {
  return `Password Reset Request

You requested to reset your password.

Open this link on your phone in the Barber Club app. Do not open it in a computer browser.

Reset my password: ${redirectUrl}

This link will expire in 30 minutes.

If you did not request this, please ignore this email.

If the button does not work, copy and paste this link:
${redirectUrl}

Or use this deep link directly:
${deepLink}`;
}

export class PasswordResetService {
  async forgotPassword(email: string): Promise<void> {
    const normalizedEmail = email.toLowerCase().trim();

    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (!user || !user.isActive) {
      return;
    }

    const token = crypto.randomBytes(32).toString('hex');
    const tokenHash = hashToken(token);
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 30);

    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });

    // Build HTTPS redirect URL that will redirect to deep link
    // This makes the link clickable in email clients and web browsers
    const backendPublicUrl = config.BACKEND_PUBLIC_URL || `http://localhost:${config.PORT}`;
    const redirectUrl = `${backendPublicUrl}/api/v1/auth/reset-password-redirect?token=${encodeURIComponent(token)}&email=${encodeURIComponent(normalizedEmail)}`;
    
    // Deep link for fallback (direct barberclub:// link)
    const deepLink = `barberclub://reset-password?token=${token}&email=${encodeURIComponent(normalizedEmail)}`;

    const html = buildPasswordResetEmailHtml(redirectUrl);
    const text = buildPasswordResetEmailText(redirectUrl, deepLink);

    await emailProvider.sendEmail({
      to: normalizedEmail,
      subject: 'Password Reset Request',
      html,
      text,
    });

    logger.info('Password reset email sent', { userId: user.id, email: normalizedEmail });
  }

  async resetPassword(
    email: string,
    token: string,
    newPassword: string
  ): Promise<void> {
    const normalizedEmail = email.toLowerCase().trim();
    const tokenHash = hashToken(token);

    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (!user || !user.isActive) {
      throw new AppError(
        ErrorCode.INVALID_CREDENTIALS,
        'Invalid email or token',
        401
      );
    }

    const resetToken = await prisma.passwordResetToken.findFirst({
      where: {
        tokenHash,
        userId: user.id,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
    });

    if (!resetToken) {
      throw new AppError(
        ErrorCode.TOKEN_INVALID,
        'Invalid or expired reset token',
        401
      );
    }

    const passwordHash = await hashPassword(newPassword);

    try {
      await prisma.$transaction(async (tx) => {
        await tx.passwordResetToken.update({
          where: { id: resetToken.id },
          data: { usedAt: new Date() },
        });

        await tx.user.update({
          where: { id: user.id },
          data: { passwordHash },
        });

        await tx.refreshToken.updateMany({
          where: {
            userId: user.id,
            revokedAt: null,
          },
          data: {
            revokedAt: new Date(),
          },
        });
      });

      logger.info('Password reset successful', { userId: user.id, email: normalizedEmail });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2025') {
          throw new AppError(
            ErrorCode.TOKEN_INVALID,
            'Invalid or expired reset token',
            401
          );
        }
      }
      throw error;
    }
  }
}

export const passwordResetService = new PasswordResetService();
