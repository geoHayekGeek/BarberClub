/**
 * Periodic job: award loyalty points for completed website bookings.
 */

import { runBookingLoyaltyRewardSync } from '../modules/loyalty_v2/bookingRewards';
import { getWebsiteClient } from '../db/websiteClient';
import { logger } from '../utils/logger';

const INTERVAL_MS = 10 * 60 * 1000; // 10 minutes

let intervalId: ReturnType<typeof setInterval> | null = null;
let isRunning = false;

async function runBookingLoyaltyRewardJob(): Promise<void> {
  if (isRunning) {
    return;
  }

  isRunning = true;
  try {
    await runBookingLoyaltyRewardSync();
  } catch (error) {
    logger.error('Booking loyalty reward job failed', {
      error: error instanceof Error ? error.message : error,
    });
  } finally {
    isRunning = false;
  }
}

export function startBookingLoyaltyRewardJob(): void {
  if (intervalId != null) {
    return;
  }

  const websiteClient = getWebsiteClient();
  if (!websiteClient) {
    logger.info('Booking loyalty reward job disabled - WEBSITE_DATABASE_URL not configured');
    return;
  }

  intervalId = setInterval(() => {
    void runBookingLoyaltyRewardJob();
  }, INTERVAL_MS);

  logger.info('Booking loyalty reward job started', { intervalMinutes: INTERVAL_MS / 60000 });
  void runBookingLoyaltyRewardJob();
}

export function stopBookingLoyaltyRewardJob(): void {
  if (intervalId == null) {
    return;
  }

  clearInterval(intervalId);
  intervalId = null;
  logger.info('Booking loyalty reward job stopped');
}
