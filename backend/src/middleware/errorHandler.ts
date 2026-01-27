/**
 * Centralized error handling middleware
 */

import { Request, Response, NextFunction } from 'express';
import { formatError } from '../utils/errors';
import { logger } from '../utils/logger';

export function errorHandler(
  error: unknown,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const { statusCode, response } = formatError(error);

  if (statusCode >= 500) {
    logger.error('Unhandled error', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      path: req.path,
      method: req.method,
    });
  }

  res.status(statusCode).json(response);
}
