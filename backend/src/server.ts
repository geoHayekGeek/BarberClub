/**
 * Server entry point
 */

import { createApp } from './app';
import config from './config';
import { logger } from './utils/logger';
import prisma from './db/client';
import { startFlashOfferExpiryJob, stopFlashOfferExpiryJob } from './jobs/flashOfferExpiry';
import { startUserSyncJob, stopUserSyncJob } from './jobs/userSync';
import { startBookingLoyaltyRewardJob, stopBookingLoyaltyRewardJob } from './jobs/bookingLoyaltyRewards';
import { disconnectWebsiteClient } from './db/websiteClient';

const app = createApp();

async function startServer(): Promise<void> {
  try {
    await prisma.$connect();
    logger.info('Database connected');

    if (config.NODE_ENV !== 'test') {
      startFlashOfferExpiryJob();
      startUserSyncJob();
      startBookingLoyaltyRewardJob();
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

async function shutdown(signal: 'SIGTERM' | 'SIGINT'): Promise<void> {
  logger.info(`${signal} received, shutting down gracefully`);
  stopFlashOfferExpiryJob();
  stopUserSyncJob();
  stopBookingLoyaltyRewardJob();

  await Promise.allSettled([disconnectWebsiteClient(), prisma.$disconnect()]);
  process.exit(0);
}

process.on('SIGTERM', () => {
  void shutdown('SIGTERM');
});

process.on('SIGINT', () => {
  void shutdown('SIGINT');
});

startServer();
