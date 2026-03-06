/**
 * Server entry point
 */

import { createApp } from './app';
import config from './config';
import { logger } from './utils/logger';
import prisma from './db/client';
import { startFlashOfferExpiryJob, stopFlashOfferExpiryJob } from './jobs/flashOfferExpiry';

const app = createApp();

async function startServer(): Promise<void> {
  try {
    await prisma.$connect();
    logger.info('Database connected');

    if (config.NODE_ENV !== 'test') {
      startFlashOfferExpiryJob();
    }

    app.listen(config.PORT, '0.0.0.0', () => {
      logger.info(`Server running on port ${config.PORT}`, {
        env: config.NODE_ENV,
        port: config.PORT,
      });
    });
  } catch (error) {
    logger.error('Failed to start server', { error });
    process.exit(1);
  }
}

process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  stopFlashOfferExpiryJob();
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully');
  stopFlashOfferExpiryJob();
  await prisma.$disconnect();
  process.exit(0);
});

startServer();
