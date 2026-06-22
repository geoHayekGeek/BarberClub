import { runBookingLoyaltyRewardSync } from '../src/modules/loyalty_v2/bookingRewards';
import { logger } from '../src/utils/logger';

type CliOptions = {
  fromDate?: string;
  toDate?: string;
};

function pad(value: number): string {
  return String(value).padStart(2, '0');
}

function formatLocalDate(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function startOfWeekLocal(date: Date): Date {
  const copy = new Date(date);
  copy.setHours(0, 0, 0, 0);
  const day = copy.getDay();
  const delta = day === 0 ? -6 : 1 - day;
  copy.setDate(copy.getDate() + delta);
  return copy;
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {};

  for (const arg of argv) {
    if (arg.startsWith('--from=')) {
      options.fromDate = arg.slice('--from='.length);
    } else if (arg.startsWith('--to=')) {
      options.toDate = arg.slice('--to='.length);
    }
  }

  return options;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const now = new Date();

  const fromDate = args.fromDate ?? formatLocalDate(startOfWeekLocal(now));
  const toDate = args.toDate ?? formatLocalDate(now);

  logger.info('Starting booking loyalty backfill', { fromDate, toDate });
  await runBookingLoyaltyRewardSync({ fromDate, toDate });
  logger.info('Booking loyalty backfill completed', { fromDate, toDate });
}

main().catch((error) => {
  logger.error('Booking loyalty backfill failed', {
    error: error instanceof Error ? error.message : error,
  });
  process.exit(1);
});
