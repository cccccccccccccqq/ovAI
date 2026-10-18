import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall, type CallableRequest } from "firebase-functions/v2/https";
import { DomainError } from "./domain.js";
import * as service from "./service.js";
import * as chapters from "./chapters.js";
import * as account from "./account.js";

if (getApps().length === 0) initializeApp();
const database = getFirestore();
setGlobalOptions({ region: "asia-northeast1", maxInstances: 10 });

// Every callable requires Firebase Authentication. App Check is enforced only
// when ENFORCE_APP_CHECK=true, because the web app has no reCAPTCHA site key yet.
const callableOptions = { enforceAppCheck: process.env.ENFORCE_APP_CHECK === "true" };

async function authenticated<T>(
  request: CallableRequest<unknown>,
  operation: (uid: string, data: unknown) => Promise<T>,
): Promise<T> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in before using your cloud library.");
  try {
    return await operation(request.auth.uid, request.data);
  } catch (error: unknown) {
    if (error instanceof DomainError) throw new HttpsError(error.code, error.message);
    logger.error("An authenticated library operation failed.", error);
    throw new HttpsError("internal", "The operation could not be completed. Please try again.");
  }
}

export const ensureProfile = onCall(callableOptions, (request) =>
  authenticated(request, (uid, data) => service.ensureProfile(database, uid, data)));

export const createPreparedChronicle = onCall(callableOptions, (request) =>
  authenticated(request, (uid, data) => service.createPreparedChronicle(database, uid, data)));

export const patchLibraryItem = onCall(callableOptions, (request) =>
  authenticated(request, (uid, data) => service.patchLibraryItem(database, uid, data)));

export const deleteChronicle = onCall(callableOptions, (request) =>
  authenticated(request, (uid, data) => service.deleteChronicle(database, uid, data)));

export const patchChapterProgress = onCall(callableOptions, (request) =>
  authenticated(request, (uid, data) => chapters.patchChapterProgress(database, uid, data)));

// Requires a fresh sign-in, so a session left open on a shared device cannot
// erase the account. The emulator has no default bucket unless one is configured.
export const deleteAccount = onCall(callableOptions, (request) =>
  authenticated(request, (uid) => {
    account.requireRecentSignIn(request.auth?.token.auth_time);
    const bucket = process.env.FIREBASE_STORAGE_EMULATOR_HOST || process.env.FUNCTIONS_EMULATOR !== "true"
      ? getStorage().bucket()
      : undefined;
    return account.deleteAccount(database, getAuth(), bucket, uid);
  }));
