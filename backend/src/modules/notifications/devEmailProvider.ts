/**
 * Development email provider
 * Stores sent emails in memory for local inspection
 * Only active in development/test environments
 */

import crypto from 'crypto';
import { EmailProvider, EmailOptions } from './emailProvider';
import config from '../../config';

interface StoredEmail extends EmailOptions {
  id: string;
  sentAt: Date;
}

class DevEmailProvider implements EmailProvider {
  private emails: StoredEmail[] = [];
  private maxEmails = 100;

  async sendEmail(options: EmailOptions): Promise<void> {
    if (config.NODE_ENV !== 'development' && config.NODE_ENV !== 'test') {
      throw new Error('DevEmailProvider should only be used in development/test');
    }

    const email: StoredEmail = {
      ...options,
      id: crypto.randomUUID(),
      sentAt: new Date(),
    };

    this.emails.unshift(email);

    if (this.emails.length > this.maxEmails) {
      this.emails = this.emails.slice(0, this.maxEmails);
    }
  }

  getEmails(): StoredEmail[] {
    return [...this.emails];
  }

  getEmailById(id: string): StoredEmail | undefined {
    return this.emails.find((e) => e.id === id);
  }

  clearEmails(): void {
    this.emails = [];
  }
}

export const devEmailProvider = new DevEmailProvider();
