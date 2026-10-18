import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { DomainError, identifier } from "./domain.js";

export interface ChapterProgressPatch {
  chapterId: string;
  contentVersion: number;
  audioPositionMs?: number;
  bookmarked?: boolean;
  completed?: boolean;
}

export interface ChapterProgressResult {
  chapterId: string;
  contentVersion: number;
  audioPositionMs: number;
  bookmarked: boolean;
  completed: boolean;
}

/** The caller can modify only their playback state, never published content. */
export function parseChapterProgressPatch(value: unknown): ChapterProgressPatch {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw new DomainError("invalid-argument", "Input must be an object.");
  }
  const input = value as Record<string, unknown>;
  const allowed = ["chapterId", "contentVersion", "audioPositionMs", "bookmarked", "completed"];
  if (Object.keys(input).some((key) => !allowed.includes(key))) {
    throw new DomainError("invalid-argument", "Unknown chapter progress fields are not accepted.");
  }
  const version = input.contentVersion;
  if (typeof version !== "number" || !Number.isSafeInteger(version) || version < 1 || version > 100_000) {
    throw new DomainError("invalid-argument", "contentVersion must be a positive integer.");
  }
  const result: ChapterProgressPatch = {
    chapterId: identifier(input.chapterId, "chapterId"),
    contentVersion: version,
  };
  if (Object.hasOwn(input, "audioPositionMs")) {
    const position = input.audioPositionMs;
    if (typeof position !== "number" || !Number.isSafeInteger(position) || position < 0 || position > 86_400_000) {
      throw new DomainError("invalid-argument", "audioPositionMs must be a nonnegative bounded integer.");
    }
    result.audioPositionMs = position;
  }
  for (const field of ["bookmarked", "completed"] as const) {
    if (Object.hasOwn(input, field)) {
      if (typeof input[field] !== "boolean") {
        throw new DomainError("invalid-argument", `${field} must be a boolean.`);
      }
      result[field] = input[field];
    }
  }
  if (Object.keys(result).length === 2) {
    throw new DomainError("invalid-argument", "At least one progress field is required.");
  }
  return result;
}

/** Public chapter content is shared; progress is an account-owned small record. */
export async function patchChapterProgress(db: Firestore, uid: string, value: unknown): Promise<ChapterProgressResult> {
  const input = parseChapterProgressPatch(value);
  const chapterReference = db.doc(`chapters/${input.chapterId}`);
  const progressReference = db.doc(`users/${uid}/chapterProgress/${input.chapterId}`);
  return db.runTransaction(async (transaction) => {
    const [chapter, existing] = await Promise.all([
      transaction.get(chapterReference),
      transaction.get(progressReference),
    ]);
    if (!chapter.exists || chapter.get("status") !== "published") {
      throw new DomainError("not-found", "This chapter is not published.");
    }
    const duration: unknown = chapter.get("durationMs");
    const version: unknown = chapter.get("contentVersion");
    const seriesId: unknown = chapter.get("seriesId");
    if (typeof duration !== "number" || !Number.isSafeInteger(duration) || duration <= 0 || duration > 86_400_000 ||
        typeof version !== "number" || !Number.isSafeInteger(version) || version < 1 ||
        typeof seriesId !== "string" || chapter.get("id") !== input.chapterId) {
      throw new DomainError("failed-precondition", "This chapter requires editorial recovery.");
    }
    if (input.contentVersion !== version) {
      throw new DomainError("failed-precondition", "This chapter has changed. Reload it before saving progress.");
    }
    if (input.audioPositionMs !== undefined && input.audioPositionMs > duration) {
      throw new DomainError("invalid-argument", "Playback position exceeds this chapter's audio duration.");
    }
    const sameVersion = existing.exists && existing.get("contentVersion") === version;
    const previousPosition: unknown = sameVersion ? existing.get("audioPositionMs") : 0;
    const savedPosition = typeof previousPosition === "number" && Number.isSafeInteger(previousPosition) &&
      previousPosition >= 0 && previousPosition <= duration ? previousPosition : 0;
    const result: ChapterProgressResult = {
      chapterId: input.chapterId,
      contentVersion: version,
      audioPositionMs: input.audioPositionMs ?? savedPosition,
      bookmarked: input.bookmarked ?? (existing.get("bookmarked") === true),
      completed: input.completed ?? (sameVersion && existing.get("completed") === true),
    };
    transaction.set(progressReference, {
      ...result,
      uid,
      seriesId,
      schemaVersion: 1,
      ...(existing.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return result;
  });
}
