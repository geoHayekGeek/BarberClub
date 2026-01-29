/**
 * Email notification module
 * Exports the appropriate email provider based on environment and configuration
 */

import config from '../../config';
import { devEmailProvider } from './devEmailProvider';
import { smtpEmailProvider } from './smtpEmailProvider';
import { EmailProvider } from './emailProvider';

function isSMTPConfigured(): boolean {
  return !!(
    process.env.SMTP_HOST &&
    process.env.SMTP_PORT &&
    process.env.SMTP_USER &&
    process.env.SMTP_PASSWORD &&
    process.env.SMTP_FROM
  );
}

let emailProvider: EmailProvider;

// Test: always use DevEmailProvider (tests need to access emails programmatically)
// Development without SMTP: use DevEmailProvider so forgot-password etc. "send" to in-memory store
// Development with SMTP or production: use SMTP (production should have SMTP configured for real emails)
if (config.NODE_ENV === 'test') {
  emailProvider = devEmailProvider;
} else if (isSMTPConfigured()) {
  emailProvider = smtpEmailProvider;
} else if (config.NODE_ENV === 'development') {
  emailProvider = devEmailProvider;
} else {
  emailProvider = smtpEmailProvider;
}

export { emailProvider, devEmailProvider };
