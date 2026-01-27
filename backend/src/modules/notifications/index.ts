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

// Always use DevEmailProvider in test mode (tests need to access emails programmatically)
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
