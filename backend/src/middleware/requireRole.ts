/**
 * Role-based access middleware. Must run after authenticate().
 */

import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth';
import { AppError, ErrorCode } from '../utils/errors';
import { UserRole } from '../modules/auth/utils/token';

export function requireRole(role: UserRole) {
  return (req: AuthRequest, _res: Response, next: NextFunction): void => {
    if (req.role !== role) {
      throw new AppError(ErrorCode.FORBIDDEN, 'Forbidden', 403);
    }
    next();
  };
}

export const requireAdmin = requireRole('ADMIN');
export const requireUser = requireRole('USER');
