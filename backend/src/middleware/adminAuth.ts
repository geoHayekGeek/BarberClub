/**
 * Admin authentication middleware
 * Validates admin secret from request body
 */

import { Request, Response, NextFunction } from 'express';
import config from '../config';
import { AppError, ErrorCode } from '../utils/errors';

export function adminAuth(req: Request, _res: Response, next: NextFunction): void {
  const { adminSecret } = req.body;

  if (!adminSecret || typeof adminSecret !== 'string') {
    throw new AppError(
      ErrorCode.ADMIN_FORBIDDEN,
      'Invalid admin secret',
      403
    );
  }

  if (!config.ADMIN_SECRET || adminSecret !== config.ADMIN_SECRET) {
    throw new AppError(
      ErrorCode.ADMIN_FORBIDDEN,
      'Invalid admin secret',
      403
    );
  }

  // Remove adminSecret from body to prevent logging/leakage
  delete req.body.adminSecret;

  next();
}
