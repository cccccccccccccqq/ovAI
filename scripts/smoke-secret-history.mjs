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

// A real client-SDK check against only the local, seeded demo project.
const projectId = 'demo-ov-chronicles';
const hosts = {
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:18080',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
  FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199',
  FUNCTIONS_EMULATOR_HOST: '127.0.0.1:5001',
};
for (const key of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT']) {
  assert.ok(!process.env[key] || process.env[key] === projectId, 'Only the demo project is accepted.');
}
for (const [key, fallback] of Object.entries(hosts)) {
  const value = process.env[key] ?? fallback;
  assert.match(value, /^(127\.0\.0\.1|localhost):\d+$/, 'Only loopback emulator hosts are accepted.');
  process.env[key] = value;
}
const endpoint = (key) => {
  const [host, port] = process.env[key].split(':');
  return [host, Number(port)];
};
const apps = [];
const users = [];
setLogLevel('silent');
function client() {
  const app = initializeApp({projectId, apiKey: 'demo-emulator-key', appId: '1:1:web:1',
    storageBucket: `${projectId}.appspot.com`}, `chapter-check-${randomUUID()}`);
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
const admin = initializeAdmin({projectId}, `chapter-check-admin-${randomUUID()}`);
try {
  const alice = client();
  const {user} = await signInAnonymously(alice.auth);
  users.push(user.uid);
  const chapter = (await getDocFromServer(doc(alice.db, 'chapters', 'onon-child'))).data();
  assert.equal(chapter.language, 'mn');
  assert.equal(chapter.durationMs, 240000);
  assert.equal(chapter.status, 'published');
  assert.equal(chapter.routeGeometry, null);
  assert.equal(chapter.scenes.length, 6);
  const series = (await getDocFromServer(doc(alice.db, 'series', chapter.seriesId))).data();
  assert.deepEqual(series.chapterIds, ['onon-child']);
  for (const id of chapter.placeIds) {
    const place = (await getDocFromServer(doc(alice.db, 'historicalPlaces', id))).data();
    assert.ok(place.radiusMeters > 0);
    assert.ok(['regional', 'uncertain'].includes(place.confidence));
  }
  const bytes = new Uint8Array(await getBytes(ref(alice.storage, chapter.audio.storagePath), 12 * 1024 * 1024));
  const localAudio = await readFile(new URL('../app/assets/audio/secret-history/onon-child-v1/narration-mn.mp3', import.meta.url));
  assert.ok(bytes.length > 1000000);
  const sha = (value) => createHash('sha256').update(value).digest('hex');
  assert.equal(sha(bytes), sha(localAudio));
  const call = httpsCallable(alice.functions, 'patchChapterProgress');
  await call({chapterId: 'onon-child', contentVersion: 1, audioPositionMs: 92000, bookmarked: true});
  const progressPath = `users/${user.uid}/chapterProgress/onon-child`;
  const saved = (await getDocFromServer(doc(alice.db, progressPath))).data();
  assert.equal(saved.audioPositionMs, 92000);
  assert.equal(saved.bookmarked, true);
  assert.ok(saved.updatedAt);
  await assert.rejects(setDoc(doc(alice.db, 'chapters', 'onon-child'), {title: 'tampered'}), {code: 'permission-denied'});
  await assert.rejects(call({chapterId: 'onon-child', contentVersion: 1, audioPositionMs: 240001}), {code: 'functions/invalid-argument'});
  const bob = client();
  const bobUser = (await signInAnonymously(bob.auth)).user;
  users.push(bobUser.uid);
  await assert.rejects(getDocFromServer(doc(bob.db, progressPath)), {code: 'permission-denied'});
  // Discard all in-memory player/Firestore state, then authenticate the same UID
  // in a fresh client. Emulator-only admin token never leaves this process.
  await signOut(alice.auth);
  await terminate(alice.db);
  await deleteApp(alice.app);
  apps.splice(apps.indexOf(alice), 1);
  const restored = client();
  const token = await getAdminAuth(admin).createCustomToken(user.uid);
  await signInWithCustomToken(restored.auth, token);
  const resumed = (await getDocFromServer(doc(restored.db, progressPath))).data();
  assert.equal(resumed.audioPositionMs, 92000);
  assert.equal(resumed.bookmarked, true);
  console.log(`PASS: real Firestore chapter + series + ${chapter.placeIds.length} map areas, ${bytes.length} Storage audio bytes verified by SHA-256.`);
  console.log('PASS: callable saved 1:32 + bookmark; a fresh authenticated client restored both from Firestore.');
  console.log('PASS: another account cannot read progress; client content writes and invalid positions are rejected.');
} finally {
  for (const item of apps) {
    await signOut(item.auth);
    await terminate(item.db);
    await deleteApp(item.app);
  }
  for (const uid of users) {
    await getAdminFirestore(admin).doc(`users/${uid}/chapterProgress/onon-child`).delete();
    await getAdminAuth(admin).deleteUser(uid);
  }
  await deleteAdmin(admin);
}
