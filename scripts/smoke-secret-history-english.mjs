import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomUUID, createHash} from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, signInAnonymously, signInWithCustomToken, signOut} from 'firebase/auth';
import {getFirestore, connectFirestoreEmulator, getDocFromServer, doc, setDoc, terminate, setLogLevel} from 'firebase/firestore';
import {getFunctions, connectFunctionsEmulator, httpsCallable} from 'firebase/functions';
import {getStorage, connectStorageEmulator, getBytes, ref} from 'firebase/storage';
import {initializeApp as initializeAdmin, deleteApp as deleteAdmin} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {preparedUsageKey, requestKey} from '../functions/lib/src/domain.js';

const projectId = 'demo-ov-chronicles';
for (const variable of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT', 'FIREBASE_PROJECT_ID']) {
  assert.ok(!process.env[variable] || process.env[variable] === projectId, 'Only the demo project is accepted.');
}
const hosts = {FIRESTORE_EMULATOR_HOST: '127.0.0.1:18080', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
  FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199', FUNCTIONS_EMULATOR_HOST: '127.0.0.1:5001'};
for (const [variable, fallback] of Object.entries(hosts)) {
  const host = process.env[variable] ?? fallback;
  assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/, 'Only loopback emulator hosts are accepted.');
  process.env[variable] = host;
}
const endpoint = (variable) => {
  const [host, port] = process.env[variable].split(':');
  return [host, Number(port)];
};
const apps = [];
const users = [];
const createdDocuments = new Set();
setLogLevel('silent');
function client() {
  const app = initializeApp({projectId, apiKey: 'demo-emulator-key', appId: '1:1:web:1',
    storageBucket: `${projectId}.appspot.com`}, `english-history-check-${randomUUID()}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`, {disableWarnings: true});
  const db = getFirestore(app);
  connectFirestoreEmulator(db, ...endpoint('FIRESTORE_EMULATOR_HOST'));
  const functions = getFunctions(app, 'asia-northeast1');
  connectFunctionsEmulator(functions, ...endpoint('FUNCTIONS_EMULATOR_HOST'));
  const storage = getStorage(app);
  connectStorageEmulator(storage, ...endpoint('FIREBASE_STORAGE_EMULATOR_HOST'));
  const result = {app, auth, db, functions, storage};
  apps.push(result);
  return result;
}
async function signIn(item) {
  const {user} = await signInAnonymously(item.auth);
  users.push(user.uid);
  createdDocuments.add(`users/${user.uid}`);
  createdDocuments.add(`usage/${preparedUsageKey(user.uid, new Date().toISOString().slice(0, 10))}`);
  return user.uid;
}
async function dispose(item) {
  await signOut(item.auth);
  await terminate(item.db);
  await deleteApp(item.app);
  apps.splice(apps.indexOf(item), 1);
}
const call = async (item, name, input) => (await httpsCallable(item.functions, name)(input)).data;
async function create(item, templateId, voiceId, parentId) {
  const uid = item.auth.currentUser.uid;
  const requestId = randomUUID();
  const key = requestKey(uid, requestId);
  const expectedId = `chr_${key}`;
  for (const path of [`chronicles/${expectedId}`, `generationRequests/${key}`, `users/${uid}/library/${expectedId}`]) createdDocuments.add(path);
  const input = {requestId, templateId, voiceId, ...(parentId ? {parentId} : {})};
  const result = await call(item, 'createPreparedChronicle', input);
  assert.equal(result.chronicleId, expectedId);
  assert.equal(result.status, 'ready');
  return {id: result.chronicleId, input};
}
const admin = initializeAdmin({projectId}, `english-history-admin-${randomUUID()}`);
const canonicalIds = ['onon-child-en', 'hoelun-family-en', 'brothers-conflict-en', 'taichiud-escape-en', 'eight-horses-en'];
const voiceIds = ['samantha', 'daniel', 'karen', 'moira'];
const sha = (value) => createHash('sha256').update(value).digest('hex');
try {
  const alice = client();
  const uid = await signIn(alice);
  const site = (await getDocFromServer(doc(alice.db, 'sites/onon'))).data();
  assert.equal(site.name, 'Onon River');
  assert.equal(site.contentKind, 'historical-synopsis');
  const series = (await getDocFromServer(doc(alice.db, 'series/temujin-childhood-en'))).data();
  assert.equal(series.language, 'en');
  assert.deepEqual(series.chapterIds, canonicalIds);
  for (const id of canonicalIds) {
    const chapter = (await getDocFromServer(doc(alice.db, 'chapters', id))).data();
    assert.equal(chapter.language, 'en');
    assert.equal(chapter.durationMs, 240000);
    assert.equal(chapter.contentKind, 'historical-synopsis');
    assert.ok(chapter.segments.every((segment) => segment.kind === 'history' && segment.citationId));
    assert.equal(chapter.scenes.at(-1).endMs, 240000);
  }
  for (const id of ['onon-basin', 'deli-un-boldaq']) {
    const place = (await getDocFromServer(doc(alice.db, 'historicalPlaces', id))).data();
    assert.ok(['regional', 'uncertain'].includes(place.confidence));
    assert.ok(place.radiusMeters > 0);
  }
  let first;
  for (const voiceId of voiceIds) {
    const created = await create(alice, 'onon-child-en', voiceId);
    const snapshot = (await getDocFromServer(doc(alice.db, 'chronicles', created.id))).data();
    assert.equal(snapshot.voiceId, voiceId);
    assert.equal(snapshot.audioPath, `catalog/audio/${voiceId}/onon-child-en.m4a`);
    assert.equal(snapshot.durationMs, 240000);
    assert.equal(snapshot.segments[0].kind, 'history');
    const bytes = new Uint8Array(await getBytes(ref(alice.storage, snapshot.audioPath), 12 * 1024 * 1024));
    const local = await readFile(new URL(`../app/assets/audio/${voiceId}/onon-child-en.m4a`, import.meta.url));
    assert.equal(sha(bytes), sha(local));
    assert.equal(new TextDecoder().decode(bytes.slice(4, 8)), 'ftyp');
    if (voiceId === 'samantha') first = created;
  }
  let parent = first.id;
  const journey = [first.id];
  for (const [index, id] of canonicalIds.slice(1).entries()) {
    const created = await create(alice, id, 'samantha', parent);
    const snapshot = (await getDocFromServer(doc(alice.db, 'chronicles', created.id))).data();
    assert.equal(snapshot.parentId, parent);
    assert.equal(snapshot.chapter, index + 2);
    assert.equal(snapshot.voiceId, 'samantha');
    assert.equal(snapshot.seriesId, series.id);
    assert.equal(snapshot.durationMs, 240000);
    journey.push(created.id);
    parent = created.id;
  }
  const alternate = await create(alice, 'onon-child-lyrical-en', 'daniel');
  const alternateSnapshot = (await getDocFromServer(doc(alice.db, 'chronicles', alternate.id))).data();
  assert.equal(alternateSnapshot.style, 'Lyrical');
  assert.deepEqual(alternateSnapshot.nextIds, ['hoelun-family-en']);
  assert.equal((await call(alice, 'createPreparedChronicle', first.input)).replayed, true);
  await call(alice, 'patchLibraryItem', {chronicleId: first.id, bookmarked: true, audioPositionMs: 92000, readingProgress: 0.4});
  await call(alice, 'patchLibraryItem', {chronicleId: journey[1], audioPositionMs: 33000});
  await assert.rejects(call(alice, 'patchLibraryItem', {chronicleId: first.id, audioPositionMs: 240001}), {code: 'functions/invalid-argument'});
  await assert.rejects(setDoc(doc(alice.db, 'storyTemplates/onon-child-en'), {title: 'tampered'}), {code: 'permission-denied'});
  const bob = client();
  await signIn(bob);
  await assert.rejects(getDocFromServer(doc(bob.db, `users/${uid}/library/${first.id}`)), {code: 'permission-denied'});
  await assert.rejects(getDocFromServer(doc(bob.db, 'chronicles', first.id)), {code: 'permission-denied'});
  await dispose(alice);
  // Prove restoration from the database with a fresh client, independent of
  // browser memory, local chapter state and any Firestore client cache.
  const resumed = client();
  const token = await getAdminAuth(admin).createCustomToken(uid);
  await signInWithCustomToken(resumed.auth, token);
  const progress = (await getDocFromServer(doc(resumed.db, `users/${uid}/library/${first.id}`))).data();
  assert.equal(progress.audioPositionMs, 92000);
  assert.equal(progress.bookmarked, true);
  const secondProgress = (await getDocFromServer(doc(resumed.db, `users/${uid}/library/${journey[1]}`))).data();
  assert.equal(secondProgress.audioPositionMs, 33000);
  for (const [index, chronicleId] of journey.entries()) {
    const snapshot = (await getDocFromServer(doc(resumed.db, 'chronicles', chronicleId))).data();
    assert.equal(snapshot.templateId, canonicalIds[index]);
    if (index > 0) assert.equal(snapshot.parentId, journey[index - 1]);
  }
  console.log('PASS: published Onon site, 5 English chapters, source citations and approximate map regions read through the real client SDK.');
  console.log('PASS: 4 selected voices fetched from Storage and matched local M4A bytes; alternate tone and Chapter 1 → 5 path created through callable Functions.');
  console.log('PASS: fresh authenticated client restored 1:32 + bookmark, independent Chapter 2 progress and every parent path edge from Firestore.');
  console.log('PASS: other-account reads, direct content writes and playback beyond four minutes were denied.');
} finally {
  for (const item of [...apps]) await dispose(item);
  const db = getAdminFirestore(admin);
  const batch = db.batch();
  for (const documentPath of createdDocuments) batch.delete(db.doc(documentPath));
  await batch.commit();
  if (users.length > 0) await getAdminAuth(admin).deleteUsers(users);
  await deleteAdmin(admin);
}
