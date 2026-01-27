/**
 * Email provider interface
 * Abstracts email sending functionality
 */

export interface EmailOptions {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

export interface EmailProvider {
  sendEmail(options: EmailOptions): Promise<void>;
}
