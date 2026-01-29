/**
 * Configuration module
 * Loads and validates environment variables
 */

import path from 'path';
import dotenv from 'dotenv';
import { z } from 'zod';

// Load .env from backend root so it works whether you run from backend/ or project root
const backendRoot = path.resolve(__dirname, '../..');
dotenv.config({ path: path.join(backendRoot, '.env') });

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().transform(Number).pipe(z.number().int().positive()).default('3000'),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRES_IN: z.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('30d'),
  CORS_ORIGINS: z.string().transform((val) => val.split(',').map((s) => s.trim())),
  RATE_LIMIT_WINDOW_MS: z.string().transform(Number).pipe(z.number().int().positive()).default('900000'),
  RATE_LIMIT_MAX_REQUESTS: z.string().transform(Number).pipe(z.number().int().positive()).default('100'),
  LOG_LEVEL: z.string().optional(),
  FRONTEND_URL: z.string().url().default('http://localhost:5173'),
  BACKEND_PUBLIC_URL: z.string().url().optional(),
  TIMIFY_BASE_URL: z.string().url().default('https://api.timify.com/v1'),
  TIMIFY_REGION: z.enum(['EUROPE', 'US', 'ASIA']).default('EUROPE'),
  TIMIFY_COMPANY_IDS: z.string().optional(),
  TIMIFY_TIMEOUT_MS: z.string().transform(Number).pipe(z.number().int().positive()).default('10000'),
  TIMIFY_MAX_RETRIES: z.string().transform(Number).pipe(z.number().int().min(0).max(5)).default('2'),
  LOYALTY_TARGET: z.string().transform(Number).pipe(z.number().int().positive()).default('10'),
  LOYALTY_QR_TTL_SECONDS: z.string().transform(Number).pipe(z.number().int().positive()).default('120'),
  ENABLE_LOCAL_CANCEL: z.string().transform((val) => val === 'true').default('false'),
  BOOKING_CANCEL_CUTOFF_MINUTES: z.string().transform(Number).pipe(z.number().int().min(0)).default('60'),
  ADMIN_SECRET: z.string().min(1).optional(),
});

type Config = z.infer<typeof configSchema>;

let config: Config;

try {
  const parsed = configSchema.parse(process.env);
  
  // Set BACKEND_PUBLIC_URL default if not provided
  if (!parsed.BACKEND_PUBLIC_URL) {
    parsed.BACKEND_PUBLIC_URL = `http://localhost:${parsed.PORT}`;
  }
  
  config = parsed as Config & { BACKEND_PUBLIC_URL: string };
  
  // Validate ADMIN_SECRET is set in production
  if (config.NODE_ENV === 'production' && !config.ADMIN_SECRET) {
    throw new Error('Configuration error: ADMIN_SECRET is required in production');
  }
  
  // Validate ADMIN_SECRET is not default value in production
  if (config.NODE_ENV === 'production' && config.ADMIN_SECRET === 'change-me-in-production') {
    throw new Error('Configuration error: ADMIN_SECRET must be changed from default value in production');
  }
} catch (error) {
  if (error instanceof z.ZodError) {
    const missingVars = error.errors.map((e) => `${e.path.join('.')}: ${e.message}`);
    throw new Error(`Configuration error:\n${missingVars.join('\n')}`);
  }
  throw error;
}

export default config;
