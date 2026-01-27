/**
 * Prisma client singleton
 */

import { PrismaClient } from '@prisma/client';
import { logger } from '../utils/logger';

const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' 
    ? ['query', 'error', 'warn'] 
    : ['error'],
});

prisma.$on('error' as never, (e: unknown) => {
  logger.error('Prisma error', { error: e });
});

export default prisma;
