import type { Auth } from "firebase-admin/auth";
import type { Firestore, Query } from "firebase-admin/firestore";
import { DomainError } from "./domain.js";

/** The caller must have signed in again within this window before deleting. */
export const RECENT_SIGN_IN_SECONDS = 5 * 60;

/** Minimal Cloud Storage surface, so the deletion can be tested without a bucket. */
export interface AccountFiles {
  deleteFiles(options: { prefix: string }): Promise<unknown>;
}

export interface DeleteAccountResult {
  uid: string;
  deleted: true;
}

export function requireRecentSignIn(authTime: unknown, nowSeconds = Math.floor(Date.now() / 1000)): void {
  if (typeof authTime !== "number" || !Number.isFinite(authTime) || nowSeconds - authTime > RECENT_SIGN_IN_SECONDS) {
    throw new DomainError("failed-precondition", "Sign in again before deleting your account.");
  }
}

async function deleteMatches(db: Firestore, query: Query): Promise<void> {
  const writer = db.bulkWriter();
  for (const document of (await query.get()).docs) void writer.delete(document.ref);
  await writer.close();
}

/**
 * Permanently removes everything owned by the account (App Store Guideline
 * 5.1.1(v)), then the Firebase user. Published catalog content is untouched.
 * Every step is idempotent, so a failed request can simply be repeated.
 */
export async function deleteAccount(db: Firestore, auth: Auth, files: AccountFiles | undefined, uid: string): Promise<DeleteAccountResult> {
  for (const collection of ["chronicles", "generationRequests", "usage"]) {
    await deleteMatches(db, db.collection(collection).where("uid", "==", uid));
  }
  // Removes the profile together with its library and chapterProgress records.
  await db.recursiveDelete(db.doc(`users/${uid}`));
  if (files) {
    for (const prefix of [`chronicles/${uid}/`, `users/${uid}/`]) {
      try {
        await files.deleteFiles({ prefix });
      } catch (error: unknown) {
        // A project whose bucket has not been provisioned holds no account files.
        if ((error as { code?: unknown }).code !== 404) throw error;
      }
    }
  }
  try {
    await auth.deleteUser(uid);
  } catch (error: unknown) {
    if ((error as { code?: unknown }).code !== "auth/user-not-found") throw error;
  }
  return { uid, deleted: true };
}
