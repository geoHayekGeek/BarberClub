/**
 * SMTP email provider
 * Sends emails via SMTP using nodemailer
 * Disabled unless SMTP configuration is provided
 */

import nodemailer from 'nodemailer';
import { EmailProvider, EmailOptions } from './emailProvider';
import { logger } from '../../utils/logger';

class SMTPEmailProvider implements EmailProvider {
  private transporter: nodemailer.Transporter | null = null;

  private isConfigured(): boolean {
    return !!(
      process.env.SMTP_HOST &&
      process.env.SMTP_PORT &&
      process.env.SMTP_USER &&
      process.env.SMTP_PASSWORD &&
      process.env.SMTP_FROM
    );
  }

  private getTransporter(): nodemailer.Transporter {
    if (!this.isConfigured()) {
      throw new Error('SMTP not configured');
    }

    if (!this.transporter) {
      const port = parseInt(process.env.SMTP_PORT || '587', 10);
      const isSecure = port === 465;

      this.transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port,
        secure: isSecure,
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASSWORD?.replace(/\s+/g, ''),
        },
        tls: {
          rejectUnauthorized: false,
        },
      });
    }

    return this.transporter;
  }

  async sendEmail(options: EmailOptions): Promise<void> {
    if (!this.isConfigured()) {
      logger.warn('SMTP not configured, email not sent', {
        to: options.to,
        subject: options.subject,
      });
      return;
    }

    try {
      const transporter = this.getTransporter();
      const mailOptions = {
        from: process.env.SMTP_FROM,
        to: options.to,
        subject: options.subject,
        text: options.text || options.html.replace(/<[^>]*>/g, ''),
        html: options.html,
      };

      await transporter.sendMail(mailOptions);
      logger.info('Email sent via SMTP', {
        to: options.to,
        subject: options.subject,
      });
    } catch (error) {
      logger.error('Failed to send email via SMTP', {
        to: options.to,
        subject: options.subject,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }
}

export const smtpEmailProvider = new SMTPEmailProvider();
