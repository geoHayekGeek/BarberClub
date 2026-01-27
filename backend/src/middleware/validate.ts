/**
 * Request validation middleware using Zod
 */

import { Request, Response, NextFunction } from 'express';
import { z, ZodError } from 'zod';
import { AppError, ErrorCode } from '../utils/errors';

export function validate<T extends z.ZodTypeAny>(
  schema: T,
  source: 'body' | 'query' | 'params' = 'body'
) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      const data = source === 'body' ? req.body : source === 'query' ? req.query : req.params;
      schema.parse(data);
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const fields: Record<string, string> = {};
        error.errors.forEach((err) => {
          const path = err.path.join('.');
          fields[path] = err.message;
        });

        throw new AppError(
          ErrorCode.VALIDATION_ERROR,
          'Validation failed',
          400,
          fields
        );
      }
      next(error);
    }
  };
}
