/**
 * Firebase Admin SDK initialization
 * Uses FIREBASE_SERVICE_ACCOUNT (JSON string) or FIREBASE_SERVICE_ACCOUNT_PATH (file path)
 */

import * as admin from 'firebase-admin';
import path from 'path';
import fs from 'fs';

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
    } catch {
      serviceAccount = null;
    }
  }

  if (!serviceAccount) {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (!serviceAccountPath) {
      return null;
    }
    const resolvedPath = path.isAbsolute(serviceAccountPath)
      ? serviceAccountPath
      : path.resolve(process.cwd(), serviceAccountPath);
    if (!fs.existsSync(resolvedPath)) {
      return null;
    }
    try {
      serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf-8')) as object;
    } catch {
      return null;
    }
  }

  try {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    initialized = true;
    return admin.app();
  } catch {
    return null;
  }
}

export function getMessaging(): admin.messaging.Messaging | null {
  const app = initializeFirebase();
  return app ? admin.messaging() : null;
}
