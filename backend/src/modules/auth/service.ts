/**
 * Authentication service
 * Handles user registration, login, token refresh, and logout
 */

import { Prisma } from '@prisma/client';
import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';
import { hashPassword, verifyPassword } from './utils/password';
import { generateAccessToken, generateRefreshToken, verifyToken, hashToken } from './utils/token';
import { validatePhoneNumber } from './utils/phone';
import { logger } from '../../utils/logger';

export interface RegisterInput {
  email: string;
  phoneNumber: string;
  password: string;
  fullName?: string;
}

export interface LoginInput {
  email?: string;
  phoneNumber?: string;
  password: string;
}

export interface AuthResponse {
  user: {
    id: string;
    email: string;
    phoneNumber: string;
    fullName: string | null;
    createdAt: Date;
  };
  accessToken: string;
  refreshToken: string;
}

export class AuthService {
  async register(input: RegisterInput): Promise<AuthResponse> {
    const normalizedEmail = input.email.toLowerCase().trim();
    const normalizedPhone = validatePhoneNumber(input.phoneNumber);
    const passwordHash = await hashPassword(input.password);

    // Check for existing email and phoneNumber before attempting to create
    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [
          { email: normalizedEmail },
          { phoneNumber: normalizedPhone },
        ],
      },
      select: {
        email: true,
        phoneNumber: true,
      },
    });

    if (existingUser) {
      const fields: Record<string, boolean> = {};
      if (existingUser.email === normalizedEmail) {
        fields.email = true;
      }
      if (existingUser.phoneNumber === normalizedPhone) {
        fields.phoneNumber = true;
      }

      throw new AppError(
        ErrorCode.USER_ALREADY_EXISTS,
        'Email or phone number already in use',
        409,
        fields
      );
    }

    try {
      const user = await prisma.user.create({
        data: {
          email: normalizedEmail,
          phoneNumber: normalizedPhone,
          passwordHash,
          fullName: input.fullName?.trim() || null,
        },
        select: {
          id: true,
          email: true,
          phoneNumber: true,
          fullName: true,
          createdAt: true,
        },
      });

      const accessToken = generateAccessToken(user.id);
      const refreshToken = generateRefreshToken(user.id);
      const refreshTokenHash = hashToken(refreshToken);

      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 30);

      await prisma.refreshToken.create({
        data: {
          userId: user.id,
          tokenHash: refreshTokenHash,
          expiresAt,
        },
      });

      logger.info('User registered', { userId: user.id, email: user.email });

      return {
        user,
        accessToken,
        refreshToken,
      };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2002') {
          const field = error.meta?.target as string[] | undefined;
          const fields: Record<string, boolean> = {};
          
          if (field?.includes('email')) {
            fields.email = true;
          }
          if (field?.includes('phoneNumber')) {
            fields.phoneNumber = true;
          }

          throw new AppError(
            ErrorCode.USER_ALREADY_EXISTS,
            'Email or phone number already in use',
            409,
            fields
          );
        }
      }
      logger.error('Registration error', { error });
      throw new AppError(
        ErrorCode.INTERNAL_ERROR,
        'Failed to register user',
        500
      );
    }
  }

  async login(input: LoginInput): Promise<AuthResponse> {
    let user;

    if (input.email) {
      user = await prisma.user.findUnique({
        where: { email: input.email.toLowerCase().trim() },
      });
    } else if (input.phoneNumber) {
      const normalizedPhone = validatePhoneNumber(input.phoneNumber);
      user = await prisma.user.findUnique({
        where: { phoneNumber: normalizedPhone },
      });
    }

    if (!user) {
      throw new AppError(
        ErrorCode.INVALID_CREDENTIALS,
        'Invalid email/phone or password',
        401
      );
    }

    if (!user.isActive) {
      throw new AppError(
        ErrorCode.FORBIDDEN,
        'Account is inactive',
        403
      );
    }

    const isValidPassword = await verifyPassword(user.passwordHash, input.password);
    if (!isValidPassword) {
      throw new AppError(
        ErrorCode.INVALID_CREDENTIALS,
        'Invalid email/phone or password',
        401
      );
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id);
    const refreshTokenHash = hashToken(refreshToken);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: refreshTokenHash,
        expiresAt,
      },
    });

    logger.info('User logged in', { userId: user.id, email: user.email });

    return {
      user: {
        id: user.id,
        email: user.email,
        phoneNumber: user.phoneNumber,
        fullName: user.fullName,
        createdAt: user.createdAt,
      },
      accessToken,
      refreshToken,
    };
  }

  async refresh(refreshToken: string): Promise<{ accessToken: string; refreshToken: string }> {
    let payload;
    try {
      payload = verifyToken(refreshToken);
    } catch (error) {
      if (error instanceof Error && error.message === 'TOKEN_EXPIRED') {
        throw new AppError(
          ErrorCode.REFRESH_TOKEN_EXPIRED,
          'Refresh token has expired',
          401
        );
      }
      throw new AppError(
        ErrorCode.REFRESH_TOKEN_INVALID,
        'Invalid refresh token',
        401
      );
    }

    if (payload.type !== 'refresh') {
      throw new AppError(
        ErrorCode.REFRESH_TOKEN_INVALID,
        'Invalid token type',
        401
      );
    }

    const tokenHash = hashToken(refreshToken);
    const storedToken = await prisma.refreshToken.findFirst({
      where: {
        tokenHash,
        userId: payload.userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      include: {
        user: true,
      },
    });

    if (!storedToken) {
      throw new AppError(
        ErrorCode.REFRESH_TOKEN_INVALID,
        'Refresh token not found or revoked',
        401
      );
    }

    if (!storedToken.user.isActive) {
      throw new AppError(
        ErrorCode.FORBIDDEN,
        'Account is inactive',
        403
      );
    }

    await prisma.refreshToken.update({
      where: { id: storedToken.id },
      data: { revokedAt: new Date() },
    });

    const newAccessToken = generateAccessToken(payload.userId);
    const newRefreshToken = generateRefreshToken(payload.userId);
    const newRefreshTokenHash = hashToken(newRefreshToken);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await prisma.refreshToken.create({
      data: {
        userId: payload.userId,
        tokenHash: newRefreshTokenHash,
        expiresAt,
      },
    });

    logger.info('Token refreshed', { userId: payload.userId });

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    };
  }

  async logout(refreshToken: string): Promise<void> {
    try {
      const tokenHash = hashToken(refreshToken);
      await prisma.refreshToken.updateMany({
        where: {
          tokenHash,
          revokedAt: null,
        },
        data: {
          revokedAt: new Date(),
        },
      });
    } catch (error) {
      logger.warn('Logout error', { error });
    }
  }

  async getCurrentUser(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        phoneNumber: true,
        fullName: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        lastLoginAt: true,
      },
    });

    if (!user) {
      throw new AppError(ErrorCode.NOT_FOUND, 'User not found', 404);
    }

    if (!user.isActive) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Account is inactive', 403);
    }

    return user;
  }
  // ... existing imports
// Make sure you import the password helpers at the top:

// ... inside AuthService class ...

  /**
   * Update user profile
   */
  async updateProfile(userId: string, data: { email?: string; phoneNumber?: string; fullName?: string }) {
    // 1. Check if email or phone is already taken by ANOTHER user
    if (data.email || data.phoneNumber) {
      const existingUser = await prisma.user.findFirst({
        where: {
          OR: [
            data.email ? { email: data.email } : {},
            data.phoneNumber ? { phoneNumber: data.phoneNumber } : {},
          ],
          NOT: { id: userId }, // Exclude the user currently requesting the update
        },
      });

      if (existingUser) {
        // Use existing code from errors.ts
        throw new AppError(ErrorCode.USER_ALREADY_EXISTS, 'Email ou numéro de téléphone déjà utilisé', 409);
      }
    }

    // 2. Update the user
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        email: data.email,
        phoneNumber: data.phoneNumber,
        fullName: data.fullName,
      },
    });

    // Return user without sensitive data
    const { passwordHash, ...safeUser } = updatedUser;
    return safeUser;
  }

  /**
   * Change password
   */
// backend/src/modules/auth/service.ts

  async changePassword(userId: string, oldPassword: string, newPassword: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    
    if (!user) {
      throw new AppError(ErrorCode.NOT_FOUND, 'Utilisateur introuvable', 404);
    }

    const valid = await verifyPassword(user.passwordHash, oldPassword);
    if (!valid) {
      // CHANGE THIS LINE: 401 -> 400
      throw new AppError(
        ErrorCode.INVALID_CREDENTIALS, 
        'Ancien mot de passe incorrect', 
        400 // <--- CHANGED FROM 401 to 400
      );
    }

    const passwordHash = await hashPassword(newPassword);

    await prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
  }
}

export const authService = new AuthService();
