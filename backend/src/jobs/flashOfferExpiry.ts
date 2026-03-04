/**
 * Periodic job: expire flash offer activations past expiresAt and decrement spotsTaken.
 */

import { clientOffersService } from '../modules/client_offers/service';
import { logger } from '../utils/logger';

const INTERVAL_MS = 10 * 60 * 1000; // 10 minutes

let intervalId: ReturnType<typeof setInterval> | null = null;

export function startFlashOfferExpiryJob(): void {
  if (intervalId != null) return;
  intervalId = setInterval(async () => {
    try {
      const count = await clientOffersService.expireFlashActivations();
      if (count > 0) {
        logger.info('Flash offer expiry job', { expiredCount: count });
      }
    } catch (error) {
      logger.error('Flash offer expiry job failed', { error });
    }
  }, INTERVAL_MS);
  logger.info('Flash offer expiry job started', { intervalMinutes: INTERVAL_MS / 60000 });
}

export function stopFlashOfferExpiryJob(): void {
  if (intervalId != null) {
    clearInterval(intervalId);
    intervalId = null;
    logger.info('Flash offer expiry job stopped');
  }
}
