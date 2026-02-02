/**
 * Password reset service
 * OTP-based flow: email contains 6-digit code, user enters in-app
 * No deep links or URL redirects
 */

import crypto from 'crypto';
import { Prisma } from '@prisma/client';
import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';
import { hashPassword } from './utils/password';
import { hashToken } from './utils/token';
import { emailProvider } from '../notifications';
import { logger } from '../../utils/logger';

/** Resend cooldown in seconds - do not send new code within this window */
const RESEND_COOLDOWN_SECONDS = process.env.NODE_ENV === 'test' ? 0 : 60;

/** Code expiration in minutes */
const CODE_EXPIRY_MINUTES = 10;

/** Max failed attempts per code before lockout */
const MAX_ATTEMPTS = 5;

/** Escape string for safe display inside HTML */
function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function buildPasswordResetEmailHtml(code: string): string {
  const safeCode = escapeHtml(code);
  return `<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Réinitialisation de mot de passe</title>
</head>
<body style="margin:0;padding:16px;font-family:sans-serif;font-size:16px;line-height:1.5;">
  <h1 style="font-size:20px;margin-top:0;">Réinitialisation de mot de passe</h1>
  <p>Voici votre code : <strong style="font-size:24px;letter-spacing:4px;">${safeCode}</strong></p>
  <p>Ce code expire dans ${CODE_EXPIRY_MINUTES} minutes.</p>
  <p>Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail.</p>
</body>
</html>`;
}

function buildPasswordResetEmailText(code: string): string {
  return `Réinitialisation de mot de passe

Voici votre code : ${code}

Ce code expire dans ${CODE_EXPIRY_MINUTES} minutes.

Si vous n'êtes pas à l'origine de cette demande, ignorez cet e-mail.`;
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

    // Per-email cooldown: do not send if last code was sent < 60 seconds ago
    const lastCode = await prisma.passwordResetCode.findFirst({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
    });
    if (lastCode) {
      const cooldownMs = RESEND_COOLDOWN_SECONDS * 1000;
      if (Date.now() - lastCode.createdAt.getTime() < cooldownMs) {
        return;
      }
    }

    // Invalidate previous active codes for this user
    await prisma.passwordResetCode.updateMany({
      where: {
        userId: user.id,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      data: { usedAt: new Date() },
    });

    // Generate 6-digit code (000000-999999)
    const codeNum = crypto.randomInt(0, 1000000);
    const code = codeNum.toString().padStart(6, '0');
    const codeHash = hashToken(code);

    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + CODE_EXPIRY_MINUTES);

    await prisma.passwordResetCode.create({
      data: {
        userId: user.id,
        codeHash,
        attempts: 0,
        expiresAt,
      },
    });

    const html = buildPasswordResetEmailHtml(code);
    const text = buildPasswordResetEmailText(code);

    await emailProvider.sendEmail({
      to: normalizedEmail,
      subject: 'Réinitialisation de mot de passe',
      html,
      text,
    });

    logger.info('Password reset code sent', { userId: user.id, email: normalizedEmail });
  }

  async resetPassword(
    email: string,
    code: string,
    newPassword: string
  ): Promise<void> {
    const normalizedEmail = email.toLowerCase().trim();
    const codeHash = hashToken(code);

    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (!user || !user.isActive) {
      throw new AppError(ErrorCode.CODE_INVALID, 'Invalid or expired code', 401);
    }

    const resetCode = await prisma.passwordResetCode.findFirst({
      where: {
        userId: user.id,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!resetCode) {
      throw new AppError(ErrorCode.CODE_EXPIRED, 'Code expired or invalid', 401);
    }

    if (resetCode.attempts >= MAX_ATTEMPTS) {
      await prisma.passwordResetCode.update({
        where: { id: resetCode.id },
        data: { usedAt: new Date() },
      });
      throw new AppError(
        ErrorCode.CODE_TOO_MANY_ATTEMPTS,
        'Too many failed attempts. Request a new code.',
        429
      );
    }

    // Timing-safe comparison (both hashes are 64-char hex from sha256)
    const expectedHash = resetCode.codeHash;
    const providedHash = codeHash;
    const expectedBuf = Buffer.from(expectedHash, 'hex');
    const providedBuf = Buffer.from(providedHash, 'hex');
    if (
      expectedBuf.length !== providedBuf.length ||
      !crypto.timingSafeEqual(expectedBuf, providedBuf)
    ) {
      await prisma.passwordResetCode.update({
        where: { id: resetCode.id },
        data: { attempts: resetCode.attempts + 1 },
      });
      throw new AppError(ErrorCode.CODE_INVALID, 'Invalid or expired code', 401);
    }

    const passwordHash = await hashPassword(newPassword);

    try {
      await prisma.$transaction(async (tx) => {
        await tx.passwordResetCode.update({
          where: { id: resetCode.id },
          data: { usedAt: new Date() },
        });

        await tx.user.update({
          where: { id: user.id },
          data: { passwordHash },
        });

        await tx.refreshToken.updateMany({
          where: { userId: user.id, revokedAt: null },
          data: { revokedAt: new Date() },
        });
      });

      logger.info('Password reset successful', { userId: user.id, email: normalizedEmail });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
        throw new AppError(ErrorCode.CODE_INVALID, 'Invalid or expired code', 401);
      }
      throw error;
    }
  }
}

export const passwordResetService = new PasswordResetService();
