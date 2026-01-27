/**
 * Authentication middleware
 * Validates JWT access tokens
 */

import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../modules/auth/utils/token';
import { AppError, ErrorCode } from '../utils/errors';

export interface AuthRequest extends Request {
  userId?: string;
}

export function authenticate(req: AuthRequest, _res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new AppError(
      ErrorCode.UNAUTHORIZED,
      'Missing or invalid authorization header',
      401
    );
  }

  const token = authHeader.substring(7);

  try {
    const payload = verifyToken(token);
    
    if (payload.type !== 'access') {
      throw new AppError(
        ErrorCode.TOKEN_INVALID,
        'Invalid token type',
        401
      );
    }

    req.userId = payload.userId;
    next();
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    if (error instanceof Error && error.message === 'TOKEN_EXPIRED') {
      throw new AppError(ErrorCode.TOKEN_EXPIRED, 'Access token has expired', 401);
    }
    throw new AppError(ErrorCode.TOKEN_INVALID, 'Invalid access token', 401);
  }
}
