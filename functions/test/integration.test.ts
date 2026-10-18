import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { after, test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { historicalFixture, preparedFixture } from "./fixture.js";
import { preparedUsageKey, requestKey } from "../src/domain.js";

const hasEmulators = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);
const projectId = process.env.GCLOUD_PROJECT ?? "demo-ov-chronicles";
const functionHost = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";
const baseUrl = `http://${functionHost}/${projectId}/asia-northeast1`;
const app = hasEmulators ? initializeApp({ projectId }, `integration-${randomUUID()}`) : undefined;
const db = app ? getFirestore(app) : undefined;
const authUsers: string[] = [];
const createdDocuments: string[] = [];

after(async () => {
  if (!app || !db) return;
  const batch = db.batch();
  for (const path of createdDocuments) batch.delete(db.doc(path));
  await batch.commit();
  if (authUsers.length > 0) await getAuth(app).deleteUsers(authUsers);
  await deleteApp(app);
});

async function signIn(): Promise<{ uid: string; token: string }> {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-key`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ returnSecureToken: true }),
  });
  assert.equal(response.status, 200, await response.clone().text());
  const json = await response.json() as { localId: string; idToken: string };
  authUsers.push(json.localId);
  createdDocuments.push(`users/${json.localId}`);
  createdDocuments.push(`usage/${preparedUsageKey(json.localId, new Date().toISOString().slice(0, 10))}`);
  return { uid: json.localId, token: json.idToken };
}

interface Result {
  chronicleId: string;
  status: string;
  replayed: boolean;
  contentVersion: number;
  uid: string;
  displayName: string;
}

async function call(name: string, data: unknown, token?: string): Promise<{ result?: Result; error?: { status: string; message: string } }> {
  const response = await fetch(`${baseUrl}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  const json = await response.json() as { result?: Result; error?: { status: string; message: string } };
  if (!json.error) assert.equal(response.status, 200, JSON.stringify(json));
  return json;
}

test("historical paths persist source metadata, parent choice and voice with private playback progress", {
  skip: hasEmulators ? false : "Run with the local auth, firestore and functions emulators.",
}, async () => {
  assert.ok(db);
  const alice = await signIn();
  const bob = await signIn();
  const first = `history-first-${randomUUID()}`;
  const second = `history-second-${randomUUID()}`;
  const unrelated = `history-other-${randomUUID()}`;
  for (const id of [first, second, unrelated]) createdDocuments.push(`storyTemplates/${id}`);
  await db.doc(`storyTemplates/${first}`).set({ ...historicalFixture(first), nextIds: [second] });
  await db.doc(`storyTemplates/${second}`).set({ ...historicalFixture(second), chapter: 2, nextIds: [] });
  await db.doc(`storyTemplates/${unrelated}`).set(historicalFixture(unrelated));
  const create = async (templateId: string, options: { parentId?: string; voiceId?: string } = {}) => {
    const requestId = randomUUID();
    const key = requestKey(alice.uid, requestId);
    const chronicleId = `chr_${key}`;
    createdDocuments.push(`chronicles/${chronicleId}`, `users/${alice.uid}/library/${chronicleId}`, `generationRequests/${key}`);
    const input = { requestId, templateId, voiceId: options.voiceId ?? "samantha", ...(options.parentId ? { parentId: options.parentId } : {}) };
    return { input, response: await call("createPreparedChronicle", input, alice.token) };
  };
  const opened = await create(first);
  assert.ok(opened.response.result, JSON.stringify(opened.response));
  const firstId = opened.response.result.chronicleId;
  const snapshot = await db.doc(`chronicles/${firstId}`).get();
  assert.equal(snapshot.get("contentKind"), "historical-synopsis");
  assert.equal(snapshot.get("segments")[0].kind, "history");
  assert.equal(snapshot.get("durationMs"), 240_000);
  assert.equal(snapshot.get("seriesId"), "temujin-childhood-en");
  assert.deepEqual(snapshot.get("sourceSections"), [59, 60, 61, 62, 63, 64, 65, 66]);
  assert.equal(snapshot.get("scenes")[1].endMs, 240_000);
  assert.equal((await create(unrelated, { parentId: firstId })).response.error?.status, "INVALID_ARGUMENT");
  assert.equal((await create(second, { parentId: firstId, voiceId: "daniel" })).response.error?.status, "INVALID_ARGUMENT");
  assert.equal((await call("createPreparedChronicle", { requestId: randomUUID(), templateId: second, voiceId: "samantha", parentId: firstId }, bob.token)).error?.status, "PERMISSION_DENIED");
  const continued = await create(second, { parentId: firstId });
  assert.ok(continued.response.result, JSON.stringify(continued.response));
  const secondId = continued.response.result.chronicleId;
  assert.equal((await db.doc(`chronicles/${secondId}`).get()).get("parentId"), firstId);
  assert.equal((await db.doc(`users/${alice.uid}/library/${secondId}`).get()).get("parentId"), firstId);
  assert.equal((await call("createPreparedChronicle", continued.input, alice.token)).result?.replayed, true);
  assert.equal((await call("patchLibraryItem", { chronicleId: secondId, audioPositionMs: 240_001 }, alice.token)).error?.status, "INVALID_ARGUMENT");
  await call("patchLibraryItem", { chronicleId: secondId, audioPositionMs: 92_000, bookmarked: true }, alice.token);
  const library = await db.doc(`users/${alice.uid}/library/${secondId}`).get();
  assert.equal(library.get("audioPositionMs"), 92_000);
  assert.equal(library.get("bookmarked"), true);
  // A later editorial update does not alter an account's captured narration,
  // source references, audio duration or the selected journey edge.
  await db.doc(`storyTemplates/${second}`).update({ contentVersion: 2, sourceSections: [67] });
  assert.equal((await db.doc(`chronicles/${secondId}`).get()).get("contentVersion"), 1);
  assert.deepEqual((await db.doc(`chronicles/${secondId}`).get()).get("sourceSections"), [59, 60, 61, 62, 63, 64, 65, 66]);
});

test("real callable functions enforce ownership, immutable snapshots and atomic replay", {
  skip: hasEmulators ? false : "Run through firebase emulators:exec with auth, firestore, functions.",
}, async (context) => {
  assert.ok(db);
  const alice = await signIn();
  const bob = await signIn();
  const templateId = `integration-${randomUUID()}`;
  const unpublishedId = `draft-${randomUUID()}`;
  await db.doc(`storyTemplates/${templateId}`).set(preparedFixture(templateId));
  await db.doc(`storyTemplates/${unpublishedId}`).set({ ...preparedFixture(unpublishedId), status: "draft" });
  createdDocuments.push(`storyTemplates/${templateId}`, `storyTemplates/${unpublishedId}`);
  const payload = { requestId: randomUUID(), templateId, voiceId: "samantha" };
  let chronicleId = "";

  await context.test("unauthenticated callers cannot execute any callable", async () => {
    for (const name of ["ensureProfile", "createPreparedChronicle", "patchLibraryItem", "deleteChronicle"]) {
      assert.equal((await call(name, {})).error?.status, "UNAUTHENTICATED");
    }
  });

  await context.test("profile can update only safe display metadata", async () => {
    const profile = await call("ensureProfile", { displayName: "  Амар  " }, alice.token);
    assert.equal(profile.result?.uid, alice.uid);
    assert.equal(profile.result?.displayName, "Амар");
    const before = await db.doc(`users/${alice.uid}`).get();
    assert.ok(before.get("createdAt"));
    await call("ensureProfile", { displayName: "A" }, alice.token);
    const after = await db.doc(`users/${alice.uid}`).get();
    assert.ok(before.get("createdAt").isEqual(after.get("createdAt")));
    assert.equal((await call("ensureProfile", { displayName: "A", role: "admin" }, alice.token)).error?.status, "INVALID_ARGUMENT");
  });

  await context.test("simultaneous retries create one snapshot, library item and request", async () => {
    const responses = await Promise.all(Array.from({ length: 4 }, () => call("createPreparedChronicle", payload, alice.token)));
    assert.ok(responses.every((response) => response.result?.status === "ready"), JSON.stringify(responses));
    const ids = new Set(responses.map((response) => response.result?.chronicleId));
    assert.equal(ids.size, 1);
    assert.equal(responses.filter((response) => response.result?.replayed === false).length, 1);
    chronicleId = responses[0]!.result!.chronicleId;
    const snapshot = await db.doc(`chronicles/${chronicleId}`).get();
    assert.equal(snapshot.get("uid"), alice.uid);
    assert.equal(snapshot.get("contentKind"), "prepared-demo");
    assert.equal(snapshot.get("audioStatus"), "ready");
    assert.equal(snapshot.get("audioPath"), `catalog/audio/samantha/${templateId}.m4a`);
    assert.equal(snapshot.get("segments")[0].text, "An imagined traveller arrived.");
    assert.ok(snapshot.get("createdAt"));
    assert.equal((await db.collection(`users/${alice.uid}/library`).get()).size, 1);
    const requests = await db.collection("generationRequests").where("uid", "==", alice.uid).get();
    assert.equal(requests.size, 1);
    createdDocuments.push(`chronicles/${chronicleId}`, `users/${alice.uid}/library/${chronicleId}`, ...requests.docs.map((document) => document.ref.path));
  });

  await context.test("changed options cannot reuse a requestId", async () => {
    assert.equal((await call("createPreparedChronicle", { ...payload, voiceId: "daniel" }, alice.token)).error?.status, "ALREADY_EXISTS");
  });

  await context.test("template changes do not replace previously captured content", async () => {
    await db.doc(`storyTemplates/${templateId}`).update({ title: "New editorial version", contentVersion: 2, status: "draft" });
    const replay = await call("createPreparedChronicle", payload, alice.token);
    assert.equal(replay.result?.chronicleId, chronicleId);
    assert.equal(replay.result?.contentVersion, 1);
    assert.equal(replay.result?.replayed, true);
    assert.equal((await db.doc(`chronicles/${chronicleId}`).get()).get("title"), "A prepared story");
    await db.doc(`storyTemplates/${templateId}`).update({ status: "published" });
  });

  await context.test("unpublished templates, unavailable voices and forged content are rejected", async () => {
    assert.equal((await call("createPreparedChronicle", { ...payload, requestId: randomUUID(), templateId: unpublishedId }, alice.token)).error?.status, "NOT_FOUND");
    assert.equal((await call("createPreparedChronicle", { ...payload, requestId: randomUUID(), voiceId: "unknown" }, alice.token)).error?.status, "INVALID_ARGUMENT");
    assert.equal((await call("createPreparedChronicle", { ...payload, requestId: randomUUID(), segments: [{ text: "forged" }] }, alice.token)).error?.status, "INVALID_ARGUMENT");
  });

  await context.test("only the owner can update finite bounded library fields", async () => {
    assert.equal((await call("patchLibraryItem", { chronicleId, bookmarked: true }, bob.token)).error?.status, "PERMISSION_DENIED");
    assert.equal((await call("patchLibraryItem", { chronicleId, readingProgress: 1.1 }, alice.token)).error?.status, "INVALID_ARGUMENT");
    assert.equal((await call("patchLibraryItem", { chronicleId, audioPositionMs: -1 }, alice.token)).error?.status, "INVALID_ARGUMENT");
    assert.equal((await call("patchLibraryItem", { chronicleId, title: "forged" }, alice.token)).error?.status, "INVALID_ARGUMENT");
    assert.equal((await call("patchLibraryItem", { chronicleId, bookmarked: true, readingProgress: 0.42, audioPositionMs: 1500 }, alice.token)).result?.status, "ready");
    const saved = await db.doc(`users/${alice.uid}/library/${chronicleId}`).get();
    assert.equal(saved.get("readingProgress"), 0.42);
    assert.equal(saved.get("audioPositionMs"), 1500);
    assert.equal(saved.get("bookmarked"), true);
  });

  await context.test("missing audio is explicit and equal requestIds remain account-scoped", async () => {
    const copied = await call("createPreparedChronicle", { ...payload, voiceId: "daniel" }, bob.token);
    assert.ok(copied.result, JSON.stringify(copied));
    assert.notEqual(copied.result.chronicleId, chronicleId);
    const snapshot = await db.doc(`chronicles/${copied.result.chronicleId}`).get();
    assert.equal(snapshot.get("audioStatus"), "unavailable");
    assert.equal(snapshot.get("audioPath"), undefined);
    const requests = await db.collection("generationRequests").where("uid", "==", bob.uid).get();
    createdDocuments.push(`chronicles/${copied.result.chronicleId}`, `users/${bob.uid}/library/${copied.result.chronicleId}`, ...requests.docs.map((document) => document.ref.path));
  });

  await context.test("soft deletion is owner-only and replay can never resurrect a chronicle", async () => {
    assert.equal((await call("deleteChronicle", { chronicleId }, bob.token)).error?.status, "PERMISSION_DENIED");
    assert.equal((await call("deleteChronicle", { chronicleId }, alice.token)).result?.status, "deleted");
    const deletedAt = (await db.doc(`chronicles/${chronicleId}`).get()).get("deletedAt");
    assert.equal((await db.doc(`users/${alice.uid}/library/${chronicleId}`).get()).exists, false);
    assert.equal((await call("deleteChronicle", { chronicleId }, alice.token)).result?.status, "deleted");
    assert.ok(deletedAt.isEqual((await db.doc(`chronicles/${chronicleId}`).get()).get("deletedAt")));
    const replay = await call("createPreparedChronicle", payload, alice.token);
    assert.equal(replay.result?.status, "deleted");
    assert.equal(replay.result?.chronicleId, chronicleId);
    assert.equal((await db.doc(`users/${alice.uid}/library/${chronicleId}`).get()).exists, false);
    assert.equal((await call("patchLibraryItem", { chronicleId, bookmarked: false }, alice.token)).error?.status, "FAILED_PRECONDITION");
  });

  await context.test("prepared-copy cap is atomic under concurrency and free on replay or rejection", async () => {
    const account = await signIn();
    const date = new Date().toISOString().slice(0, 10);
    const usageReference = db.doc(`usage/${preparedUsageKey(account.uid, date)}`);
    await usageReference.set({ uid: account.uid, date, kind: "prepared-copy", count: 99, limit: 100 });
    const rejected = await call("createPreparedChronicle", { ...payload, requestId: randomUUID(), voiceId: "unknown" }, account.token);
    assert.equal(rejected.error?.status, "INVALID_ARGUMENT");
    assert.equal((await usageReference.get()).get("count"), 99);

    const inputs = Array.from({ length: 4 }, () => ({ ...payload, requestId: randomUUID() }));
    const responses = await Promise.all(inputs.map((input) => call("createPreparedChronicle", input, account.token)));
    const successfulIndex = responses.findIndex((response) => response.result?.status === "ready");
    assert.notEqual(successfulIndex, -1, JSON.stringify(responses));
    assert.equal(responses.filter((response) => response.result).length, 1);
    assert.equal(responses.filter((response) => response.error?.status === "RESOURCE_EXHAUSTED").length, 3);
    assert.equal((await usageReference.get()).get("count"), 100);
    const requests = await db.collection("generationRequests").where("uid", "==", account.uid).get();
    assert.equal(requests.size, 1);
    const savedId = responses[successfulIndex]!.result!.chronicleId;
    createdDocuments.push(`chronicles/${savedId}`, `users/${account.uid}/library/${savedId}`, ...requests.docs.map((document) => document.ref.path));

    const replay = await call("createPreparedChronicle", inputs[successfulIndex], account.token);
    assert.equal(replay.result?.chronicleId, savedId);
    assert.equal(replay.result?.replayed, true);
    assert.equal((await usageReference.get()).get("count"), 100);
    assert.equal((await call("createPreparedChronicle", { ...payload, requestId: randomUUID() }, account.token)).error?.status, "RESOURCE_EXHAUSTED");
    assert.equal((await usageReference.get()).get("count"), 100);
  });
});
