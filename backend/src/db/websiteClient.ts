/**
 * Secondary Prisma client for the reservation website database.
 */

import { PrismaClient } from '@prisma/client';
import config from '../config';

let websiteClient: PrismaClient | null = null;

export function getWebsiteClient(): PrismaClient | null {
  if (!config.WEBSITE_DATABASE_URL) {
    return null;
  }

  if (!websiteClient) {
    websiteClient = new PrismaClient({
      datasources: {
        db: {
          url: config.WEBSITE_DATABASE_URL,
        },
      },
      log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
    });

  }

  return websiteClient;
}

export async function disconnectWebsiteClient(): Promise<void> {
  if (!websiteClient) {
    return;
  }

  await websiteClient.$disconnect();
  websiteClient = null;
}
