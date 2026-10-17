import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, signInAnonymously, signOut} from 'firebase/auth';
import {getFirestore, connectFirestoreEmulator, getDocFromServer, getDocs, collection, doc, terminate} from 'firebase/firestore';
import {getFunctions, connectFunctionsEmulator, httpsCallable} from 'firebase/functions';
import {getStorage, connectStorageEmulator, getBytes, ref} from 'firebase/storage';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
  throw new Error('Run this smoke check only inside Firebase emulators:exec.');
}
const projectId = 'demo-ov-chronicles';
const app = initializeApp({
  projectId,
  apiKey: 'demo-emulator-key',
  appId: '1:1:web:1',
  storageBucket: `${projectId}.appspot.com`,
});
const auth = getAuth(app);
const db = getFirestore(app);
const functions = getFunctions(app, 'asia-northeast1');
const storage = getStorage(app);
const endpoint = (value, fallback) => {
  const match = /^(127\.0\.0\.1|localhost):(\d+)$/.exec(value ?? fallback);
  if (!match) throw new Error('Smoke test requires loopback emulators.');
  return [match[1], Number(match[2])];
};
const [authHost, authPort] = endpoint(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099');
connectAuthEmulator(auth, `http://${authHost}:${authPort}`, {disableWarnings: true});
connectFirestoreEmulator(db, ...endpoint(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:18080'));
connectFunctionsEmulator(functions, ...endpoint(process.env.FUNCTIONS_EMULATOR_HOST, '127.0.0.1:5001'));
connectStorageEmulator(storage, ...endpoint(process.env.FIREBASE_STORAGE_EMULATOR_HOST, '127.0.0.1:9199'));
const call = async (name, data) => (await httpsCallable(functions, name)(data)).data;

try {
  const {user} = await signInAnonymously(auth);
  await call('ensureProfile', {displayName: 'Emulator Traveller'});
  const sites = await getDocs(collection(db, 'sites'));
  assert.equal(sites.size, 4);
  const input = {requestId: randomUUID(), templateId: 'silver-tree', voiceId: 'karen'};
  const created = await call('createPreparedChronicle', input);
  const replay = await call('createPreparedChronicle', input);
  assert.equal(created.chronicleId, replay.chronicleId);
  assert.equal(replay.replayed, true);
  const storyRef = doc(db, 'chronicles', created.chronicleId);
  const saved = (await getDocFromServer(storyRef)).data();
  assert.equal(saved.uid, user.uid);
  assert.equal(saved.contentKind, 'prepared-demo');
  assert.equal(saved.contentVersion, 1);
  assert.ok(saved.segments.length > 0);
  assert.ok(saved.citations.length > 0);
  assert.equal(saved.audioStatus, 'ready');
  const audio = new Uint8Array(await getBytes(ref(storage, saved.audioPath), 10 * 1024 * 1024));
  assert.ok(audio.byteLength > 1000);
  assert.equal(new TextDecoder().decode(audio.slice(4, 8)), 'ftyp');
  await call('patchLibraryItem', {chronicleId: created.chronicleId, bookmarked: true, readingProgress: 0.5, audioPositionMs: 12000});
  const library = (await getDocFromServer(doc(db, 'users', user.uid, 'library', created.chronicleId))).data();
  assert.equal(library.bookmarked, true);
  assert.equal(library.audioPositionMs, 12000);
  await call('deleteChronicle', {chronicleId: created.chronicleId});
  await assert.rejects(getDocFromServer(storyRef), (error) => error.code === 'permission-denied');
  const deletedReplay = await call('createPreparedChronicle', input);
  assert.equal(deletedReplay.status, 'deleted');
  console.log(`Seed + client SDK smoke passed: 4 sites, private story snapshot, replay, ${audio.byteLength} audio bytes, progress, deletion.`);
} finally {
  await signOut(auth);
  await terminate(db);
  await deleteApp(app);
}
