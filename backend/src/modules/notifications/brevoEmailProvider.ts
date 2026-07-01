/**
 * Brevo email provider
 * Sends transactional emails via the Brevo REST API.
 */

import { EmailProvider, EmailOptions } from './emailProvider';
import { logger } from '../../utils/logger';

const BREVO_REQUEST_TIMEOUT_MS = 15_000;

function firstNonEmpty(...values: Array<string | undefined>): string {
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed) return trimmed;
  }
  return '';
}

export function getBrevoConfig() {
  return {
    apiKey: firstNonEmpty(process.env.BREVO_API_KEY, process.env.BREVO_API_KEY_GRENOBLE),
    senderEmail: firstNonEmpty(
      process.env.BREVO_SENDER_EMAIL,
      process.env.BREVO_SENDER_EMAIL_GRENOBLE,
      'noreply@barberclub-grenoble.fr',
    ),
    senderName: firstNonEmpty(
      process.env.BREVO_SENDER_NAME,
      process.env.BREVO_SENDER_NAME_GRENOBLE,
      'BarberClub',
    ),
  };
}

export function isBrevoConfigured(): boolean {
  return getBrevoConfig().apiKey.length > 0;
}

class BrevoEmailProvider implements EmailProvider {
  async sendEmail(options: EmailOptions): Promise<void> {
    const { apiKey, senderEmail, senderName } = getBrevoConfig();

    if (!apiKey) {
      logger.warn('Brevo not configured, email not sent', {
        to: options.to,
        subject: options.subject,
      });
      throw new Error('Brevo not configured');
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), BREVO_REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          'api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          sender: { email: senderEmail, name: senderName },
          to: [{ email: options.to }],
          subject: options.subject,
          htmlContent: options.html,
          textContent: options.text || options.html.replace(/<[^>]*>/g, ''),
        }),
        signal: controller.signal,
      });

      if (!response.ok) {
        const errorBody = await response.text();
        const errorMessage = `Brevo email API error ${response.status}: ${errorBody.slice(0, 500)}`;
        logger.error(errorMessage, {
          to: options.to,
          subject: options.subject,
          status: response.status,
        });
        throw new Error(errorMessage);
      }

      let parsed: { messageId?: string } = {};
      try {
        parsed = (await response.json()) as { messageId?: string };
      } catch {
        // Brevo may return an empty body on success; no-op.
      }

      logger.info('Email sent via Brevo', {
        to: options.to,
        subject: options.subject,
        messageId: parsed.messageId ?? null,
      });
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));
      logger.error(`Failed to send email via Brevo: ${err.message}`, {
        to: options.to,
        subject: options.subject,
        error: err.message,
        ...(err.stack ? { stack: err.stack } : {}),
      });
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }
}

export const brevoEmailProvider = new BrevoEmailProvider();
