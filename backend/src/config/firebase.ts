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
    // #region agent log
    import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:14',message:'Firebase already initialized',data:{},timestamp:Date.now(),hypothesisId:'A'})+'\n')).catch(()=>{});
    // #endregion
    return admin.app();
  }

  let serviceAccount: object | null = null;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  // #region agent log
  import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:19',message:'Check FIREBASE_SERVICE_ACCOUNT env',data:{exists:!!serviceAccountJson},timestamp:Date.now(),hypothesisId:'A'})+'\n')).catch(()=>{});
  // #endregion
  if (serviceAccountJson) {
    try {
      serviceAccount = JSON.parse(serviceAccountJson) as object;
    } catch {
      serviceAccount = null;
    }
  }

  if (!serviceAccount) {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    // #region agent log
    import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:30',message:'Check FIREBASE_SERVICE_ACCOUNT_PATH env',data:{path:serviceAccountPath,cwd:process.cwd()},timestamp:Date.now(),hypothesisId:'C'})+'\n')).catch(()=>{});
    // #endregion
    if (!serviceAccountPath) {
      return null;
    }
    const resolvedPath = path.isAbsolute(serviceAccountPath)
      ? serviceAccountPath
      : path.resolve(process.cwd(), serviceAccountPath);
    // #region agent log
    import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:36',message:'Resolved service account path',data:{resolvedPath:resolvedPath,exists:fs.existsSync(resolvedPath)},timestamp:Date.now(),hypothesisId:'C'})+'\n')).catch(()=>{});
    // #endregion
    if (!fs.existsSync(resolvedPath)) {
      return null;
    }
    try {
      serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf-8')) as object;
      // #region agent log
      import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:40',message:'Service account file parsed',data:{hasProjectId:!!(serviceAccount as any)?.project_id},timestamp:Date.now(),hypothesisId:'C'})+'\n')).catch(()=>{});
      // #endregion
    } catch (e) {
      // #region agent log
      import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:43',message:'Failed to parse service account',data:{error:e instanceof Error?e.message:String(e)},timestamp:Date.now(),hypothesisId:'C'})+'\n')).catch(()=>{});
      // #endregion
      return null;
    }
  }

  try {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    initialized = true;
    // #region agent log
    import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:48',message:'Firebase Admin initialized SUCCESS',data:{},timestamp:Date.now(),hypothesisId:'A'})+'\n')).catch(()=>{});
    // #endregion
    return admin.app();
  } catch (e) {
    // #region agent log
    import('fs').then(fs => fs.appendFileSync('c:\\Users\\GeorgioHayek\\Dev\\Applications\\Barber\\.cursor\\debug.log', JSON.stringify({location:'firebase.ts:51',message:'Firebase Admin init FAILED',data:{error:e instanceof Error?e.message:String(e)},timestamp:Date.now(),hypothesisId:'A'})+'\n')).catch(()=>{});
    // #endregion
    return null;
  }
}

export function getMessaging(): admin.messaging.Messaging | null {
  const app = initializeFirebase();
  return app ? admin.messaging() : null;
}
