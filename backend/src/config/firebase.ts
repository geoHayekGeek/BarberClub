/**
 * Firebase Admin SDK initialization
 * Initialized once using service account JSON from FIREBASE_SERVICE_ACCOUNT_PATH
 */

import * as admin from 'firebase-admin';
import path from 'path';
import fs from 'fs';

let initialized = false;

export function initializeFirebase(): admin.app.App | null {
  if (initialized) {
    return admin.app();
  }

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
    const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf-8'));
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
