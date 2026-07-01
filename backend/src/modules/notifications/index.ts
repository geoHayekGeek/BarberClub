/**
 * Email notification module
 * Exports the appropriate email provider based on environment and configuration
 */

import config from '../../config';
import { devEmailProvider } from './devEmailProvider';
import { brevoEmailProvider, isBrevoConfigured } from './brevoEmailProvider';
import { smtpEmailProvider, isSMTPConfigured } from './smtpEmailProvider';
import { EmailProvider } from './emailProvider';

let emailProvider: EmailProvider;

// Test and development: always use DevEmailProvider so tests and local work stay in-memory.
// Production: prefer Brevo when configured, otherwise fall back to SMTP.
if (config.NODE_ENV === 'test') {
  emailProvider = devEmailProvider;
} else if (config.NODE_ENV === 'development') {
  emailProvider = devEmailProvider;
} else if (isBrevoConfigured()) {
  emailProvider = brevoEmailProvider;
} else if (isSMTPConfigured()) {
  emailProvider = smtpEmailProvider;
} else {
  emailProvider = brevoEmailProvider;
}

export { emailProvider, devEmailProvider };
