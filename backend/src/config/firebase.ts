/**
 * Firebase Admin SDK initialization
 * Uses FIREBASE_SERVICE_ACCOUNT (JSON string) or FIREBASE_SERVICE_ACCOUNT_PATH (file path)
 */

import * as admin from 'firebase-admin';
import path from 'path';
import fs from 'fs';
import { logger } from '../utils/logger';

let initialized = false;

export function initializeFirebase(): admin.app.App | null {
  if (initialized) {
    return admin.app();
  }

  let serviceAccount: object | null = null;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (serviceAccountJson) {
    try {
      serviceAccount = JSON.parse(serviceAccountJson) as object;
      logger.info('Firebase service account loaded from FIREBASE_SERVICE_ACCOUNT');
    } catch {
      logger.warn('FIREBASE_SERVICE_ACCOUNT is present but invalid JSON');
      serviceAccount = null;
    }
  }

  if (!serviceAccount) {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (!serviceAccountPath) {
      logger.warn('Firebase push disabled: FIREBASE_SERVICE_ACCOUNT or FIREBASE_SERVICE_ACCOUNT_PATH is not set');
      return null;
    }
    const resolvedPath = path.isAbsolute(serviceAccountPath)
      ? serviceAccountPath
      : path.resolve(process.cwd(), serviceAccountPath);
    if (!fs.existsSync(resolvedPath)) {
      logger.warn('Firebase push disabled: FIREBASE_SERVICE_ACCOUNT_PATH file does not exist', { resolvedPath });
      return null;
    }
    try {
      serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf-8')) as object;
      logger.info('Firebase service account loaded from FIREBASE_SERVICE_ACCOUNT_PATH', { resolvedPath });
    } catch {
      logger.warn('Firebase push disabled: failed to parse FIREBASE_SERVICE_ACCOUNT_PATH JSON', { resolvedPath });
      return null;
    }
  }

  try {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    initialized = true;
    logger.info('Firebase Admin initialized successfully');
    return admin.app();
  } catch (error) {
    logger.warn('Firebase push disabled: failed to initialize Firebase Admin', {
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

export function getMessaging(): admin.messaging.Messaging | null {
  const app = initializeFirebase();
  return app ? admin.messaging() : null;
}
