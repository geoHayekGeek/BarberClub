/**
 * Centralized rate limiting configuration
 */

import rateLimit from 'express-rate-limit';
import { Request, Response, NextFunction } from 'express';
import config from '../config';

const isDevelopment = config.NODE_ENV === 'development';
const isTest = config.NODE_ENV === 'test';

const createLimiter = (options: {
  windowMs: number;
  max: number;
  message: { error: { code: string; message: string } };
}) => {
  if (isTest) {
    return (_req: Request, _res: Response, next: NextFunction) => next();
  }
  return rateLimit({
    ...options,
    standardHeaders: true,
    legacyHeaders: false,
  });
};

export const generalLimiter = createLimiter({
  windowMs: config.RATE_LIMIT_WINDOW_MS,
  max: config.RATE_LIMIT_MAX_REQUESTS,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests from this IP, please try again later',
    },
  },
});

export const authLimiter = createLimiter({
  windowMs: 15 * 60 * 1000,
  max: isDevelopment ? 50 : 5,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many authentication attempts, please try again later',
    },
  },
});

export const passwordResetLimiter = createLimiter({
  windowMs: 15 * 60 * 1000,
  max: isDevelopment ? 10 : 3,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many password reset attempts, please try again later',
    },
  },
});

export const qrScanLimiter = createLimiter({
  windowMs: 60 * 1000,
  max: 10,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many scan attempts, please try again later',
    },
  },
});

/** Admin loyalty scan: 1 request per 5 seconds per IP (prevents spamming). */
export const adminLoyaltyScanLimiter = createLimiter({
  windowMs: 5 * 1000,
  max: 1,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Veuillez attendre 5 secondes entre chaque scan',
    },
  },
});

/** Admin loyalty earn (v2): same rate limit as scan. */
export const adminLoyaltyEarnLimiter = createLimiter({
  windowMs: 5 * 1000,
  max: 1,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Veuillez attendre 5 secondes entre chaque scan',
    },
  },
});

export const publicReadLimiter = createLimiter({
  windowMs: 60 * 1000,
  max: isDevelopment ? 100 : 60,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests, please try again later',
    },
  },
});

export const adminLimiter = createLimiter({
  windowMs: 15 * 60 * 1000,
  max: isDevelopment ? 20 : 5,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many admin requests, please try again later',
    },
  },
});
