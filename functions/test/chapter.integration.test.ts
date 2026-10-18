import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { after, test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import type { ChapterProgressResult } from "../src/chapters.js";

const hasEmulators = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);
const projectId = process.env.GCLOUD_PROJECT ?? "demo-ov-chronicles";
const functionHost = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";
const baseUrl = `http://${functionHost}/${projectId}/asia-northeast1`;
const app = hasEmulators ? initializeApp({ projectId }, `chapters-${randomUUID()}`) : undefined;
const db = app ? getFirestore(app) : undefined;
const users: string[] = [];
const documents: string[] = [];

after(async () => {
  if (!app || !db) return;
  const batch = db.batch();
  for (const path of documents) batch.delete(db.doc(path));
  await batch.commit();
  if (users.length) await getAuth(app).deleteUsers(users);
  await deleteApp(app);
});

async function signIn(): Promise<{ uid: string; token: string }> {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=local-key`, {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  assert.equal(response.status, 200, await response.clone().text());
  const value = await response.json() as { localId: string; idToken: string };
  users.push(value.localId);
  return { uid: value.localId, token: value.idToken };
}

async function patch(data: unknown, token?: string): Promise<{
  result?: ChapterProgressResult; error?: { status: string; message: string };
}> {
  const response = await fetch(`${baseUrl}/patchChapterProgress`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const value = await response.json() as { result?: ChapterProgressResult; error?: { status: string; message: string } };
  if (!value.error) assert.equal(response.status, 200, JSON.stringify(value));
  return value;
}

test("shared chapters save validated progress separately for each authenticated account", {
  skip: hasEmulators ? false : "Run through Firebase auth, firestore and functions emulators.",
}, async (context) => {
  assert.ok(db);
  const chapterId = `chapter-${randomUUID()}`;
  const draftId = `draft-${randomUUID()}`;
  const chapter = { id: chapterId, seriesId: "temujin-childhood", status: "published", contentVersion: 1, durationMs: 240_000 };
  await db.doc(`chapters/${chapterId}`).set(chapter);
  await db.doc(`chapters/${draftId}`).set({ ...chapter, id: draftId, status: "draft" });
  documents.push(`chapters/${chapterId}`, `chapters/${draftId}`);
  const alice = await signIn();
  const bob = await signIn();
  const payload = { chapterId, contentVersion: 1, audioPositionMs: 92_000 };
  const alicePath = `users/${alice.uid}/chapterProgress/${chapterId}`;
  const bobPath = `users/${bob.uid}/chapterProgress/${chapterId}`;
  documents.push(alicePath, bobPath);

  await context.test("anonymous local accounts are authenticated and unauthenticated calls are rejected", async () => {
    assert.equal((await patch(payload)).error?.status, "UNAUTHENTICATED");
    const response = await patch(payload, alice.token);
    assert.deepEqual(response.result, { chapterId, contentVersion: 1, audioPositionMs: 92_000, bookmarked: false, completed: false });
    const saved = await db.doc(alicePath).get();
    assert.equal(saved.get("uid"), alice.uid);
    assert.equal(saved.get("seriesId"), chapter.seriesId);
    assert.ok(saved.get("createdAt"));
    assert.ok(saved.get("updatedAt"));
  });

  await context.test("users share content while their playback states remain independent", async () => {
    await patch({ ...payload, audioPositionMs: 40_000, bookmarked: true }, bob.token);
    await patch({ chapterId, contentVersion: 1, bookmarked: true }, alice.token);
    assert.equal((await db.doc(alicePath).get()).get("audioPositionMs"), 92_000);
    assert.equal((await db.doc(bobPath).get()).get("audioPositionMs"), 40_000);
    assert.deepEqual((await db.doc(`chapters/${chapterId}`).get()).data(), chapter);
    assert.equal((await patch({ ...payload, uid: bob.uid }, alice.token)).error?.status, "INVALID_ARGUMENT");
  });

  await context.test("duration, publication and version validation prevent invalid persisted state", async () => {
    assert.equal((await patch({ ...payload, audioPositionMs: 240_001 }, alice.token)).error?.status, "INVALID_ARGUMENT");
    assert.equal((await patch({ ...payload, contentVersion: 2 }, alice.token)).error?.status, "FAILED_PRECONDITION");
    assert.equal((await patch({ ...payload, chapterId: draftId }, alice.token)).error?.status, "NOT_FOUND");
    assert.equal((await patch({ ...payload, chapterId: "missing-chapter" }, alice.token)).error?.status, "NOT_FOUND");
    assert.equal((await db.doc(alicePath).get()).get("audioPositionMs"), 92_000);
  });

  await context.test("resume updates preserve creation time and all independent progress fields", async () => {
    const createdAt = (await db.doc(alicePath).get()).get("createdAt");
    await patch({ ...payload, audioPositionMs: 240_000, completed: true }, alice.token);
    const saved = await db.doc(alicePath).get();
    assert.equal(saved.get("completed"), true);
    assert.equal(saved.get("bookmarked"), true);
    assert.ok(saved.get("createdAt").isEqual(createdAt));
  });

  await context.test("new editorial versions reset obsolete playback and completion but preserve bookmarks", async () => {
    await db.doc(`chapters/${chapterId}`).update({ contentVersion: 2 });
    assert.equal((await patch(payload, alice.token)).error?.status, "FAILED_PRECONDITION");
    const response = await patch({ chapterId, contentVersion: 2, bookmarked: true }, alice.token);
    assert.deepEqual(response.result, { chapterId, contentVersion: 2, audioPositionMs: 0, bookmarked: true, completed: false });
  });
});
