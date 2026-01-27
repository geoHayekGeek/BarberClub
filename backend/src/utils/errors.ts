/**
 * Custom error types and error response formatting
 */

import { ZodError } from 'zod';

export enum ErrorCode {
  // Validation errors
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  INVALID_INPUT = 'INVALID_INPUT',
  
  // Authentication errors
  UNAUTHORIZED = 'UNAUTHORIZED',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  TOKEN_INVALID = 'TOKEN_INVALID',
  REFRESH_TOKEN_INVALID = 'REFRESH_TOKEN_INVALID',
  REFRESH_TOKEN_EXPIRED = 'REFRESH_TOKEN_EXPIRED',
  
  // Resource errors
  NOT_FOUND = 'NOT_FOUND',
  CONFLICT = 'CONFLICT',
  USER_ALREADY_EXISTS = 'USER_ALREADY_EXISTS',
  FORBIDDEN = 'FORBIDDEN',
  
  // Server errors
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  DATABASE_ERROR = 'DATABASE_ERROR',
  
  // Booking errors
  BOOKING_SLOT_UNAVAILABLE = 'BOOKING_SLOT_UNAVAILABLE',
  BOOKING_PROVIDER_ERROR = 'BOOKING_PROVIDER_ERROR',
  BOOKING_VALIDATION_ERROR = 'BOOKING_VALIDATION_ERROR',
  BOOKING_NOT_FOUND = 'BOOKING_NOT_FOUND',
  BOOKING_NOT_CANCELABLE = 'BOOKING_NOT_CANCELABLE',
  CANCEL_NOT_AVAILABLE = 'CANCEL_NOT_AVAILABLE',
  
  // Loyalty errors
  LOYALTY_NOT_READY = 'LOYALTY_NOT_READY',
  INVALID_OR_EXPIRED_QR = 'INVALID_OR_EXPIRED_QR',
  
  // Offer errors
  OFFER_NOT_FOUND = 'OFFER_NOT_FOUND',
  
  // Salon errors
  SALON_NOT_FOUND = 'SALON_NOT_FOUND',
  
  // Barber errors
  BARBER_NOT_FOUND = 'BARBER_NOT_FOUND',
  
  // Admin errors
  ADMIN_FORBIDDEN = 'ADMIN_FORBIDDEN',
}

export interface ErrorResponse {
  error: {
    code: string;
    message: string;
    fields?: Record<string, string | boolean>;
  };
}

export class AppError extends Error {
  public readonly code: ErrorCode;
  public readonly statusCode: number;
  public readonly fields?: Record<string, string | boolean>;

  constructor(
    code: ErrorCode,
    message: string,
    statusCode: number = 500,
    fields?: Record<string, string | boolean>
  ) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.fields = fields;
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON(): ErrorResponse {
    const response: ErrorResponse = {
      error: {
        code: this.code,
        message: this.message,
      },
    };

    if (this.fields) {
      response.error.fields = this.fields;
    }

    return response;
  }
}

export function formatError(error: unknown): { statusCode: number; response: ErrorResponse } {
  if (error instanceof AppError) {
    return {
      statusCode: error.statusCode,
      response: error.toJSON(),
    };
  }

  if (error instanceof ZodError) {
    const fields: Record<string, string> = {};
    error.errors.forEach((err) => {
      const path = err.path.join('.');
      fields[path] = err.message;
    });

    return {
      statusCode: 400,
      response: {
        error: {
          code: ErrorCode.VALIDATION_ERROR,
          message: 'Validation failed',
          fields,
        },
      },
    };
  }

  if (error instanceof Error) {

    return {
      statusCode: 500,
      response: {
        error: {
          code: ErrorCode.INTERNAL_ERROR,
          message: process.env.NODE_ENV === 'production' 
            ? 'An internal error occurred' 
            : error.message,
        },
      },
    };
  }

  return {
    statusCode: 500,
    response: {
      error: {
        code: ErrorCode.INTERNAL_ERROR,
        message: 'An unknown error occurred',
      },
    },
  };
}
