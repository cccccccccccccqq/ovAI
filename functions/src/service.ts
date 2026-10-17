import { FieldValue, type DocumentSnapshot, type Firestore } from "firebase-admin/firestore";
import {
  DomainError,
  parseChronicleInput,
  parseLibraryPatch,
  parsePreparedInput,
  parseProfileInput,
  nextPreparedCopyCount,
  payloadHash,
  PREPARED_COPY_DAILY_LIMIT,
  preparedUsageKey,
  publishedTemplate,
  requestKey,
} from "./domain.js";

export interface ChronicleResult {
  chronicleId: string;
  status: "ready" | "deleted";
}

export interface PreparedResult extends ChronicleResult {
  replayed: boolean;
  contentVersion: number;
}

function ownChronicle(snapshot: DocumentSnapshot, uid: string): "ready" | "deleted" {
  if (!snapshot.exists) {
    throw new DomainError("not-found", "The chronicle does not exist.");
  }
  if (snapshot.get("uid") !== uid) {
    throw new DomainError("permission-denied", "This chronicle belongs to another account.");
  }
  const status: unknown = snapshot.get("status");
  if (status !== "ready" && status !== "deleted") {
    throw new DomainError("failed-precondition", "The chronicle is not available.");
  }
  return status;
}

export async function ensureProfile(db: Firestore, uid: string, value: unknown): Promise<{ uid: string; displayName: string }> {
  const { displayName } = parseProfileInput(value);
  const reference = db.doc(`users/${uid}`);
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(reference);
    const metadata = { uid, displayName, schemaVersion: 1, updatedAt: FieldValue.serverTimestamp() };
    if (existing.exists) {
      // Do not replace subscriptions, roles, or server-managed account metadata.
      transaction.update(reference, metadata);
    } else {
      transaction.create(reference, { ...metadata, createdAt: FieldValue.serverTimestamp() });
    }
  });
  return { uid, displayName };
}

export async function createPreparedChronicle(db: Firestore, uid: string, value: unknown): Promise<PreparedResult> {
  const input = parsePreparedInput(value);
  const key = requestKey(uid, input.requestId);
  const hash = payloadHash(input);
  const chronicleId = `chr_${key}`;
  const requestReference = db.doc(`generationRequests/${key}`);
  const chronicleReference = db.doc(`chronicles/${chronicleId}`);
  const libraryReference = db.doc(`users/${uid}/library/${chronicleId}`);
  const templateReference = db.doc(`storyTemplates/${input.templateId}`);
  // Fix the server UTC accounting day for the entire transaction, including its
  // automatic retries. A later replay is resolved before inspecting this cap.
  const utcDate = new Date().toISOString().slice(0, 10);
  const usageReference = db.doc(`usage/${preparedUsageKey(uid, utcDate)}`);

  return db.runTransaction(async (transaction): Promise<PreparedResult> => {
    // The durable request record and snapshot commit together. Transactions retry
    // a concurrent identical request, which then reads the original result.
    const previousRequest = await transaction.get(requestReference);
    if (previousRequest.exists) {
      if (previousRequest.get("uid") !== uid || previousRequest.get("payloadHash") !== hash) {
        throw new DomainError("already-exists", "This requestId was already used with different options.");
      }
      if (previousRequest.get("chronicleId") !== chronicleId) {
        throw new DomainError("failed-precondition", "The original request result is unavailable.");
      }
      const original = await transaction.get(chronicleReference);
      const status = ownChronicle(original, uid);
      const contentVersion: unknown = original.get("contentVersion");
      if (typeof contentVersion !== "number" || !Number.isSafeInteger(contentVersion)) {
        throw new DomainError("failed-precondition", "The original content version is unavailable.");
      }
      // Never read a newer template, recreate a deleted snapshot, or restore its
      // library entry during replay.
      return { chronicleId, status, replayed: true, contentVersion };
    }
    const [templateDocument, conflictingChronicle, usageDocument] = await Promise.all([
      transaction.get(templateReference),
      transaction.get(chronicleReference),
      transaction.get(usageReference),
    ]);
    if (conflictingChronicle.exists) {
      throw new DomainError("failed-precondition", "The request requires recovery before it can be repeated.");
    }
    const template = publishedTemplate(templateDocument.data(), input.templateId);
    if (!template.voiceIds.includes(input.voiceId)) {
      throw new DomainError("invalid-argument", "The selected voice is not available for this story.");
    }
    if (usageDocument.exists && (usageDocument.get("uid") !== uid || usageDocument.get("date") !== utcDate ||
        usageDocument.get("kind") !== "prepared-copy" || usageDocument.get("count") === undefined)) {
      throw new DomainError("failed-precondition", "Prepared-copy usage requires recovery.");
    }
    const count = nextPreparedCopyCount(usageDocument.exists ? usageDocument.get("count") : undefined);
    const audio = template.audioByVoice[input.voiceId];
    const timestamp = FieldValue.serverTimestamp();
    const snapshot = {
      id: chronicleId,
      uid,
      templateId: template.id,
      siteId: template.siteId,
      title: template.title,
      subtitle: template.subtitle,
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
      chapter: template.chapter,
      segments: template.segments,
      citations: template.citations,
      voiceId: input.voiceId,
      language: template.language,
      contentVersion: template.contentVersion,
      contentKind: template.contentKind,
      status: "ready",
      audioStatus: audio ? "ready" : "unavailable",
      ...(audio ? { audioPath: audio.storagePath } : {}),
      ...(template.imagePath ? { imagePath: template.imagePath } : {}),
      ...(template.nextIds ? { nextIds: template.nextIds } : {}),
      createdAt: timestamp,
      updatedAt: timestamp,
    };
    transaction.create(chronicleReference, snapshot);
    transaction.create(libraryReference, {
      id: chronicleId,
      uid,
      chronicleId,
      title: template.title,
      siteId: template.siteId,
      voiceId: input.voiceId,
      contentKind: template.contentKind,
      bookmarked: false,
      readingProgress: 0,
      audioPositionMs: 0,
      ...(template.imagePath ? { imagePath: template.imagePath } : {}),
      createdAt: timestamp,
      updatedAt: timestamp,
    });
    transaction.create(requestReference, {
      uid,
      payloadHash: hash,
      chronicleId,
      templateId: template.id,
      voiceId: input.voiceId,
      contentVersion: template.contentVersion,
      contentKind: template.contentKind,
      createdAt: timestamp,
    });
    transaction.set(usageReference, {
      uid,
      date: utcDate,
      kind: "prepared-copy",
      count,
      limit: PREPARED_COPY_DAILY_LIMIT,
      ...(usageDocument.exists ? {} : { createdAt: timestamp }),
      updatedAt: timestamp,
    }, { merge: true });
    return { chronicleId, status: "ready", replayed: false, contentVersion: template.contentVersion };
  });
}

export async function patchLibraryItem(db: Firestore, uid: string, value: unknown): Promise<ChronicleResult> {
  const { chronicleId, ...patch } = parseLibraryPatch(value);
  const chronicleReference = db.doc(`chronicles/${chronicleId}`);
  const libraryReference = db.doc(`users/${uid}/library/${chronicleId}`);
  await db.runTransaction(async (transaction) => {
    const [chronicle, library] = await Promise.all([
      transaction.get(chronicleReference),
      transaction.get(libraryReference),
    ]);
    if (ownChronicle(chronicle, uid) !== "ready") {
      throw new DomainError("failed-precondition", "A deleted chronicle cannot be updated.");
    }
    if (!library.exists || library.get("uid") !== uid || library.get("chronicleId") !== chronicleId) {
      throw new DomainError("not-found", "The library item does not exist.");
    }
    transaction.update(libraryReference, { ...patch, updatedAt: FieldValue.serverTimestamp() });
  });
  return { chronicleId, status: "ready" };
}

export async function deleteChronicle(db: Firestore, uid: string, value: unknown): Promise<ChronicleResult> {
  const { chronicleId } = parseChronicleInput(value);
  const chronicleReference = db.doc(`chronicles/${chronicleId}`);
  const libraryReference = db.doc(`users/${uid}/library/${chronicleId}`);
  await db.runTransaction(async (transaction) => {
    const chronicle = await transaction.get(chronicleReference);
    const status = ownChronicle(chronicle, uid);
    if (status !== "deleted") {
      const timestamp = FieldValue.serverTimestamp();
      transaction.update(chronicleReference, { status: "deleted", deletedAt: timestamp, updatedAt: timestamp });
    }
    transaction.delete(libraryReference);
  });
  return { chronicleId, status: "deleted" };
}
