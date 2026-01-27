/**
 * TIMIFY module
 * Exports configured TIMIFY client instance
 */

import config from '../../config';
import TimifyClient from './timifyClient';
import type { TimifyRegion } from './types';

const timifyClient = new TimifyClient({
  baseURL: config.TIMIFY_BASE_URL,
  region: config.TIMIFY_REGION as TimifyRegion,
  timeout: config.TIMIFY_TIMEOUT_MS,
  maxRetries: config.NODE_ENV === 'test' ? 0 : config.TIMIFY_MAX_RETRIES,
});

export { timifyClient };
export type { TimifyRegion } from './types';
