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

    // Use deep link format for mobile app: barberclub://reset-password?token=XXX&email=YYY
    const resetUrl = `barberclub://reset-password?token=${token}&email=${encodeURIComponent(normalizedEmail)}`;

    await emailProvider.sendEmail({
      to: normalizedEmail,
      subject: 'Reset Your Password',
      html: `
        <h1>Password Reset Request</h1>
        <p>You requested to reset your password. Click the link below to reset it:</p>
        <p><a href="${resetUrl}">${resetUrl}</a></p>
        <p>This link will expire in 30 minutes.</p>
        <p>If you did not request this, please ignore this email.</p>
      `,
      text: `
        Password Reset Request
        
        You requested to reset your password. Click the following link to reset it:
        ${resetUrl}
        
        This link will expire in 30 minutes.
        
        If you did not request this, please ignore this email.
      `,
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
