/**
 * Authentication service
 * Handles user registration, login, token refresh, and logout
 */

import { Prisma } from '@prisma/client';
import prisma from '../../db/client';
import { getWebsiteClient } from '../../db/websiteClient';
import { AppError, ErrorCode } from '../../utils/errors';
import {
  hashPassword,
  hashWebsitePassword,
  isBcryptHash,
  verifyPasswordAgainstAnyHash,
} from './utils/password';
import { generateAccessToken, generateRefreshToken, verifyToken, hashToken } from './utils/token';
import { validatePhoneNumber } from './utils/phone';
import { logger } from '../../utils/logger';
import { clientOffersService } from '../client_offers/service';

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
    avatarUrl: string | null;
    role: 'USER' | 'ADMIN';
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
    const websitePasswordHash = await hashWebsitePassword(input.password);

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
          websitePasswordHash,
          fullName: input.fullName?.trim() || null,
        },
        select: {
          id: true,
          email: true,
          phoneNumber: true,
          fullName: true,
          avatarUrl: true,
          role: true,
          createdAt: true,
        },
      });

      const role = user.role ?? 'USER';
      const accessToken = generateAccessToken(user.id, role);
      const refreshToken = generateRefreshToken(user.id, role);
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

      try {
        await clientOffersService.activateWelcomeOfferForNewUser(user.id);
      } catch (err) {
        logger.warn('Welcome offer activation skipped', { userId: user.id, error: err });
      }

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
        select: { id: true, email: true, phoneNumber: true, fullName: true, avatarUrl: true, role: true, createdAt: true, isActive: true, passwordHash: true, websitePasswordHash: true },
      });
    } else if (input.phoneNumber) {
      const normalizedPhone = validatePhoneNumber(input.phoneNumber);
      user = await prisma.user.findUnique({
        where: { phoneNumber: normalizedPhone },
        select: { id: true, email: true, phoneNumber: true, fullName: true, avatarUrl: true, role: true, createdAt: true, isActive: true, passwordHash: true, websitePasswordHash: true },
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

    const isValidPassword = await verifyPasswordAgainstAnyHash(input.password, [
      user.passwordHash,
      user.websitePasswordHash,
    ]);
    if (!isValidPassword) {
      throw new AppError(
        ErrorCode.INVALID_CREDENTIALS,
        'Invalid email/phone or password',
        401
      );
    }

    const updateData: Prisma.UserUpdateInput = {
      lastLoginAt: new Date(),
    };
    if (!user.websitePasswordHash) {
      updateData.websitePasswordHash = isBcryptHash(user.passwordHash)
        ? user.passwordHash
        : await hashWebsitePassword(input.password);
    }

    await prisma.user.update({
      where: { id: user.id },
      data: updateData,
    });

    const role = (user.role === 'ADMIN' ? 'ADMIN' : 'USER') as 'USER' | 'ADMIN';
    const accessToken = generateAccessToken(user.id, role);
    const refreshToken = generateRefreshToken(user.id, role);
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
        avatarUrl: user.avatarUrl,
        role: role,
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

    const role = (storedToken.user.role === 'ADMIN' ? 'ADMIN' : 'USER') as 'USER' | 'ADMIN';
    const newAccessToken = generateAccessToken(payload.userId, role);
    const newRefreshToken = generateRefreshToken(payload.userId, role);
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
        avatarUrl: true,
        role: true,
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

  /**
   * Update user profile
   */
  async updateProfile(userId: string, data: { email?: string; phoneNumber?: string; fullName?: string }) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, isActive: true },
    });

    if (!user) {
      throw new AppError(ErrorCode.NOT_FOUND, 'User not found', 404);
    }

    if (!user.isActive) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Account is inactive', 403);
    }

    const normalizedEmail = data.email?.toLowerCase().trim();
    const normalizedPhone = data.phoneNumber ? validatePhoneNumber(data.phoneNumber) : undefined;

    const conflictConditions: Prisma.UserWhereInput[] = [];
    if (normalizedEmail) {
      conflictConditions.push({ email: normalizedEmail });
    }
    if (normalizedPhone) {
      conflictConditions.push({ phoneNumber: normalizedPhone });
    }

    if (conflictConditions.length > 0) {
      const existingUser = await prisma.user.findFirst({
        where: {
          OR: conflictConditions,
          NOT: { id: userId },
        },
        select: {
          email: true,
          phoneNumber: true,
        },
      });

      if (existingUser) {
        const fields: Record<string, boolean> = {};
        if (normalizedEmail && existingUser.email === normalizedEmail) {
          fields.email = true;
        }
        if (normalizedPhone && existingUser.phoneNumber === normalizedPhone) {
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

    const updateData: Prisma.UserUpdateInput = {};
    if (normalizedEmail !== undefined) {
      updateData.email = normalizedEmail;
    }
    if (normalizedPhone !== undefined) {
      updateData.phoneNumber = normalizedPhone;
    }
    if (data.fullName !== undefined) {
      const trimmedName = data.fullName.trim();
      updateData.fullName = trimmedName.length > 0 ? trimmedName : null;
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: updateData,
      select: {
        id: true,
        email: true,
        phoneNumber: true,
        fullName: true,
        avatarUrl: true,
        role: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        lastLoginAt: true,
      },
    });

    return updatedUser;
  }

  /**
   * Update user avatar URL.
   */
  async updateAvatarUrl(userId: string, avatarUrl: string | null) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, isActive: true },
    });

    if (!user) {
      throw new AppError(ErrorCode.NOT_FOUND, 'User not found', 404);
    }

    if (!user.isActive) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Account is inactive', 403);
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: { avatarUrl },
      select: {
        id: true,
        email: true,
        phoneNumber: true,
        fullName: true,
        avatarUrl: true,
        role: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        lastLoginAt: true,
      },
    });

    return updatedUser;
  }

  /**
   * Change account password and revoke active refresh tokens.
   */
  async changePassword(userId: string, oldPassword: string, newPassword: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true, websitePasswordHash: true, isActive: true },
    });

    if (!user) {
      throw new AppError(ErrorCode.NOT_FOUND, 'User not found', 404);
    }

    if (!user.isActive) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Account is inactive', 403);
    }

    const valid = await verifyPasswordAgainstAnyHash(oldPassword, [
      user.passwordHash,
      user.websitePasswordHash,
    ]);
    if (!valid) {
      throw new AppError(
        ErrorCode.INVALID_CREDENTIALS,
        'Current password is incorrect',
        401
      );
    }

    const passwordHash = await hashPassword(newPassword);
    const websitePasswordHash = await hashWebsitePassword(newPassword);
    const now = new Date();

    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: { passwordHash, websitePasswordHash },
      }),
      prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: now },
      }),
    ]);

    logger.info('Password changed', { userId });
  }

  /**
   * Permanently delete the authenticated account and all cascade-related data.
   */
  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        passwordHash: true,
        websitePasswordHash: true,
        isActive: true,
        isSuperAdmin: true,
      },
    });

    if (!user) {
      throw new AppError(ErrorCode.NOT_FOUND, 'User not found', 404);
    }

    if (!user.isActive) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Account is inactive', 403);
    }

    if (user.isSuperAdmin) {
      throw new AppError(
        ErrorCode.FORBIDDEN,
        'Super admin accounts cannot be deleted via this endpoint',
        403
      );
    }

    const isValidPassword = await verifyPasswordAgainstAnyHash(password, [
      user.passwordHash,
      user.websitePasswordHash,
    ]);
    if (!isValidPassword) {
      throw new AppError(
        ErrorCode.INVALID_CREDENTIALS,
        'Current password is incorrect',
        401
      );
    }

    const websiteClientDb = getWebsiteClient();
    const syncLink = websiteClientDb
      ? await prisma.userSyncLink.findUnique({
          where: { appUserId: userId },
          select: { websiteClientId: true },
        })
      : null;

    await prisma.$transaction(async (tx) => {
      await tx.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });

      await tx.user.delete({
        where: { id: userId },
      });
    });

    if (websiteClientDb && syncLink?.websiteClientId) {
      try {
        await websiteClientDb.$executeRaw(Prisma.sql`
          UPDATE clients
          SET deleted_at = NOW(),
              has_account = false,
              password_hash = NULL
          WHERE id = CAST(${syncLink.websiteClientId} AS UUID)
        `);
      } catch (error) {
        logger.warn('Website delete sync failed', {
          userId,
          websiteClientId: syncLink.websiteClientId,
          error: error instanceof Error ? error.message : error,
        });
      }
    }

    logger.info('Account deleted', { userId, email: user.email });
  }
}

export const authService = new AuthService();
