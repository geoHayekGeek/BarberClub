/**
 * 404 Not Found handler
 */

import { Request, Response, NextFunction } from 'express';
import { AppError, ErrorCode } from '../utils/errors';

export function notFoundHandler(
  req: Request,
  _res: Response,
  next: NextFunction
): void {
  next(new AppError(ErrorCode.NOT_FOUND, `Route ${req.method} ${req.path} not found`, 404));
}
