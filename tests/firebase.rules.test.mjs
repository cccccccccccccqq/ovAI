import { readFile } from 'node:fs/promises';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  setLogLevel,
  updateDoc,
  where,
} from 'firebase/firestore';
import {
  deleteObject,
  getBytes,
  getMetadata,
  listAll,
  ref,
  updateMetadata,
  uploadBytes,
} from 'firebase/storage';

// This suite refuses to start without emulators and never uses a real project.
const projectId = 'demo-ov-chronicles';
const bucketUrl = `gs://${projectId}.appspot.com`;
const storagePaths = [
  'catalog/kharkhorin/cover.jpg',
  'chronicles/alice/alice-story/audio.m4a',
  'chronicles/bob/bob-story/audio.m4a',
  'chronicles/alice/deleted-story/audio.m4a',
  'chronicles/alice/bob-story/audio.m4a',
  'chronicles/bob/alice-story/audio.m4a',
  'chronicles/alice/missing-story/audio.m4a',
  'chronicles/alice/alice-story/nested/audio.m4a',
  'users/alice/covers/cover.jpg',
  'users/alice/covers/nested/cover.jpg',
  'sources/archive/manuscript.pdf',
  'unrecognized/private.txt',
];
let environment;
let alice;
let bob;
let guest;
let unauthenticated;
let admin;
let fakeAdmin;

before(async () => {
  setLogLevel('silent');
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Run with firebase emulators:exec (Firestore).');
  assert.ok(process.env.FIREBASE_STORAGE_EMULATOR_HOST, 'Run with firebase emulators:exec (Storage).');
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 18080,
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
    storage: {
      host: '127.0.0.1',
      port: 9199,
      rules: await readFile(new URL('../storage.rules', import.meta.url), 'utf8'),
    },
  });
  await environment.clearFirestore();
  await environment.clearStorage();
  alice = environment.authenticatedContext('alice');
  bob = environment.authenticatedContext('bob');
  guest = environment.authenticatedContext('guest', {
    firebase: { sign_in_provider: 'anonymous' },
  });
  unauthenticated = environment.unauthenticatedContext();
  admin = environment.authenticatedContext('admin', { admin: true });
  fakeAdmin = environment.authenticatedContext('fake-admin', { admin: 'true', role: 'admin' });
  await environment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const documents = {
      'sites/kharkhorin': { name: 'Kharkhorin' },
      'series/published-series': { status: 'published', title: 'Тэмүжиний бага нас' },
      'series/draft-series': { status: 'draft' },
      'chapters/published-chapter': { status: 'published', title: 'Ононы эрэгт мэндэлсэн хүү' },
      'chapters/draft-chapter': { status: 'draft' },
      'historicalPlaces/onon': { status: 'published', confidence: 'regional' },
      'historicalPlaces/private-place': { status: 'draft' },
      'users/alice/chapterProgress/published-chapter': { audioPositionMs: 92000, contentVersion: 1 },
      'users/bob/chapterProgress/published-chapter': { audioPositionMs: 40000, contentVersion: 1 },
      'chapters/published-chapter/private/secret': { secret: true },
      'storyTemplates/published': { siteId: 'kharkhorin', status: 'published', title: 'Published story' },
      'storyTemplates/draft': { siteId: 'kharkhorin', status: 'draft', title: 'Private draft' },
      'users/alice': { displayName: 'Alice', role: 'admin' },
      'users/bob': { displayName: 'Bob' },
      'users/guest': { displayName: 'Guest' },
      'users/alice/library/alice-story': { chronicleId: 'alice-story', createdAt: 1 },
      'users/bob/library/bob-story': { chronicleId: 'bob-story', createdAt: 2 },
      'chronicles/alice-story': { uid: 'alice', status: 'ready', title: 'Alice story', createdAt: 1 },
      'chronicles/bob-story': { uid: 'bob', status: 'ready', title: 'Bob story', createdAt: 2 },
      'chronicles/guest-story': { uid: 'guest', status: 'ready', title: 'Guest story', createdAt: 3 },
      'chronicles/deleted-story': { uid: 'alice', status: 'deleted', createdAt: 4 },
      'generationRequests/request-one': { uid: 'alice', status: 'complete' },
      'sources/source-one': { title: 'Historical source' },
      'facts/fact-one': { sourceId: 'source-one', text: 'Verified fact' },
      'conflicts/conflict-one': { sourceIds: ['source-one'], status: 'open' },
      'adminAudit/audit-one': { action: 'publish' },
      'sites/kharkhorin/private/secret': { secret: true },
      'storyTemplates/published/private/secret': { secret: true },
      'users/alice/private/secret': { secret: true },
      'users/alice/library/alice-story/private/secret': { secret: true },
      'chronicles/alice-story/private/secret': { secret: true },
      'sources/source-one/private/secret': { secret: true },
      'unrecognized/secret': { secret: true },
    };
    await Promise.all(Object.entries(documents).map(([path, value]) => setDoc(doc(database, path), value)));
    await Promise.all(storagePaths.map((path) => uploadBytes(
      ref(context.storage(bucketUrl), path),
      new TextEncoder().encode('Emulator-only fixture'),
      { contentType: 'application/octet-stream' },
    )));
  });
});

after(async () => {
  if (environment) await environment.cleanup();
});

test('public catalog reads expose sites and published templates only', async () => {
  for (const context of [unauthenticated, guest, alice, bob]) {
    const database = context.firestore();
    await assertSucceeds(getDoc(doc(database, 'sites/kharkhorin')));
    await assertSucceeds(getDocs(collection(database, 'sites')));
    await assertSucceeds(getDoc(doc(database, 'storyTemplates/published')));
    await assertFails(getDoc(doc(database, 'storyTemplates/draft')));
    const published = await assertSucceeds(getDocs(query(
      collection(database, 'storyTemplates'),
      where('siteId', '==', 'kharkhorin'),
      where('status', '==', 'published'),
    )));
    assert.equal(published.size, 1);
    await assertFails(getDocs(collection(database, 'storyTemplates')));
  }
  await assertSucceeds(getDoc(doc(admin.firestore(), 'storyTemplates/draft')));
  await assertSucceeds(getDocs(collection(admin.firestore(), 'storyTemplates')));
  await assertFails(getDoc(doc(fakeAdmin.firestore(), 'storyTemplates/draft')));
});

test('chronicles are private to the owner and deleted records cannot be read', async () => {
  await assertSucceeds(getDoc(doc(alice.firestore(), 'chronicles/alice-story')));
  await assertSucceeds(getDoc(doc(bob.firestore(), 'chronicles/bob-story')));
  await assertSucceeds(getDoc(doc(guest.firestore(), 'chronicles/guest-story')));
  for (const context of [unauthenticated, bob, guest, admin, fakeAdmin]) {
    await assertFails(getDoc(doc(context.firestore(), 'chronicles/alice-story')));
  }
  await assertFails(getDoc(doc(alice.firestore(), 'chronicles/deleted-story')));
  await assertFails(getDoc(doc(alice.firestore(), 'chronicles/bob-story')));
  const owned = await assertSucceeds(getDocs(query(
    collection(alice.firestore(), 'chronicles'),
    where('uid', '==', 'alice'),
    where('status', '==', 'ready'),
    orderBy('createdAt', 'desc'),
  )));
  assert.equal(owned.size, 1);
  await assertFails(getDocs(collection(alice.firestore(), 'chronicles')));
  await assertFails(getDocs(query(collection(alice.firestore(), 'chronicles'), where('uid', '==', 'alice'))));
});

test('profiles and libraries can only be read by their owning user', async () => {
  await assertSucceeds(getDoc(doc(alice.firestore(), 'users/alice')));
  await assertSucceeds(getDoc(doc(guest.firestore(), 'users/guest')));
  const library = await assertSucceeds(getDocs(query(
    collection(alice.firestore(), 'users/alice/library'),
    orderBy('createdAt', 'desc'),
  )));
  assert.equal(library.size, 1);
  for (const context of [unauthenticated, bob, guest, admin]) {
    await assertFails(getDoc(doc(context.firestore(), 'users/alice')));
    await assertFails(getDoc(doc(context.firestore(), 'users/alice/library/alice-story')));
    await assertFails(getDocs(collection(context.firestore(), 'users/alice/library')));
  }
  await assertFails(getDocs(collection(alice.firestore(), 'users')));
  await assertFails(getDocs(collectionGroup(alice.firestore(), 'library')));
});

test('research data uses a boolean admin claim and generation jobs stay server-only', async () => {
  for (const path of ['sources/source-one', 'facts/fact-one', 'conflicts/conflict-one', 'adminAudit/audit-one']) {
    await assertSucceeds(getDoc(doc(admin.firestore(), path)));
    for (const context of [unauthenticated, alice, bob, guest, fakeAdmin]) {
      await assertFails(getDoc(doc(context.firestore(), path)));
    }
  }
  // Alice's persisted profile says role: admin, which must never grant access.
  for (const context of [unauthenticated, alice, bob, admin]) {
    await assertFails(getDoc(doc(context.firestore(), 'generationRequests/request-one')));
  }
});

test('all clients including admins are denied protected creates, updates and deletes', async () => {
  const existing = [
    'sites/kharkhorin', 'storyTemplates/published', 'users/alice',
    'users/alice/library/alice-story', 'chronicles/alice-story',
    'generationRequests/request-one', 'sources/source-one', 'facts/fact-one',
    'conflicts/conflict-one', 'adminAudit/audit-one',
  ];
  for (const context of [unauthenticated, alice, bob, admin]) {
    for (const path of existing) {
      await assertFails(updateDoc(doc(context.firestore(), path), { role: 'admin', uid: 'bob' }));
      await assertFails(deleteDoc(doc(context.firestore(), path)));
    }
    for (const path of [
      'sites/new-site', 'storyTemplates/new-template', 'users/new-user',
      'users/alice/library/new-story', 'chronicles/new-story',
      'generationRequests/new-request', 'sources/new-source',
    ]) {
      await assertFails(setDoc(doc(context.firestore(), path), { uid: 'alice', status: 'published' }));
    }
  }
});

test('unmatched documents and nested subcollections never inherit parent access', async () => {
  const paths = [
    'sites/kharkhorin/private/secret',
    'storyTemplates/published/private/secret',
    'users/alice/private/secret',
    'users/alice/library/alice-story/private/secret',
    'chronicles/alice-story/private/secret',
    'sources/source-one/private/secret',
    'unrecognized/secret',
  ];
  for (const context of [unauthenticated, alice, admin]) {
    for (const path of paths) {
      await assertFails(getDoc(doc(context.firestore(), path)));
      await assertFails(setDoc(doc(context.firestore(), path), { expose: true }));
    }
  }
});

test('catalog media is public while chronicle audio checks both path and database ownership', async () => {
  for (const context of [unauthenticated, guest, alice, bob]) {
    await assertSucceeds(getMetadata(ref(context.storage(bucketUrl), 'catalog/kharkhorin/cover.jpg')));
    await assertSucceeds(listAll(ref(context.storage(bucketUrl), 'catalog/kharkhorin')));
  }
  const audio = 'chronicles/alice/alice-story/audio.m4a';
  await assertSucceeds(getMetadata(ref(alice.storage(bucketUrl), audio)));
  const bytes = await assertSucceeds(getBytes(ref(alice.storage(bucketUrl), audio)));
  assert.ok(bytes.byteLength > 0);
  await assertSucceeds(getMetadata(ref(bob.storage(bucketUrl), 'chronicles/bob/bob-story/audio.m4a')));
  for (const context of [unauthenticated, bob, guest, admin]) {
    await assertFails(getMetadata(ref(context.storage(bucketUrl), audio)));
  }
  for (const path of [
    'chronicles/alice/deleted-story/audio.m4a',
    'chronicles/alice/bob-story/audio.m4a',
    'chronicles/bob/alice-story/audio.m4a',
    'chronicles/alice/missing-story/audio.m4a',
    'chronicles/alice/alice-story/nested/audio.m4a',
  ]) {
    await assertFails(getMetadata(ref(alice.storage(bucketUrl), path)));
  }
});

test('covers stay owner-only and source files require an admin claim', async () => {
  await assertSucceeds(getMetadata(ref(alice.storage(bucketUrl), 'users/alice/covers/cover.jpg')));
  for (const context of [unauthenticated, bob, guest, admin]) {
    await assertFails(getMetadata(ref(context.storage(bucketUrl), 'users/alice/covers/cover.jpg')));
  }
  await assertFails(getMetadata(ref(alice.storage(bucketUrl), 'users/alice/covers/nested/cover.jpg')));
  await assertSucceeds(getMetadata(ref(admin.storage(bucketUrl), 'sources/archive/manuscript.pdf')));
  for (const context of [unauthenticated, alice, bob, fakeAdmin]) {
    await assertFails(getMetadata(ref(context.storage(bucketUrl), 'sources/archive/manuscript.pdf')));
  }
  for (const context of [unauthenticated, alice, admin]) {
    await assertFails(getMetadata(ref(context.storage(bucketUrl), 'unrecognized/private.txt')));
  }
});

test('media uploads, deletions and download-token metadata changes are server-only', async () => {
  const paths = [
    'catalog/kharkhorin/cover.jpg',
    'chronicles/alice/alice-story/audio.m4a',
    'users/alice/covers/cover.jpg',
    'sources/archive/manuscript.pdf',
  ];
  for (const context of [unauthenticated, alice, bob, admin]) {
    for (const path of paths) {
      const file = ref(context.storage(bucketUrl), path);
      await assertFails(deleteObject(file));
      await assertFails(updateMetadata(file, {
        customMetadata: { firebaseStorageDownloadTokens: 'client-supplied-public-token' },
      }));
    }
    await assertFails(uploadBytes(
      ref(context.storage(bucketUrl), 'chronicles/alice/alice-story/new-audio.m4a'),
      new Uint8Array([1, 2, 3]),
      { customMetadata: { firebaseStorageDownloadTokens: 'client-supplied-public-token' } },
    ));
  }
});


test('published historical series, chapters and places are shared while drafts stay private', async () => {
  for (const [collectionName, publishedId, draftId] of [
    ['series', 'published-series', 'draft-series'],
    ['chapters', 'published-chapter', 'draft-chapter'],
    ['historicalPlaces', 'onon', 'private-place'],
  ]) {
    for (const context of [unauthenticated, guest, alice, bob]) {
      const database = context.firestore();
      await assertSucceeds(getDoc(doc(database, collectionName, publishedId)));
      await assertFails(getDoc(doc(database, collectionName, draftId)));
      const published = await assertSucceeds(getDocs(query(collection(database, collectionName), where('status', '==', 'published'))));
      assert.equal(published.size, 1);
      await assertFails(getDocs(collection(database, collectionName)));
    }
    await assertSucceeds(getDoc(doc(admin.firestore(), collectionName, draftId)));
    for (const context of [unauthenticated, alice, admin]) {
      await assertFails(setDoc(doc(context.firestore(), collectionName, 'new-content'), { status: 'published' }));
      await assertFails(updateDoc(doc(context.firestore(), collectionName, publishedId), { title: 'Forged' }));
      await assertFails(deleteDoc(doc(context.firestore(), collectionName, publishedId)));
    }
  }
  await assertFails(getDoc(doc(alice.firestore(), 'chapters/published-chapter/private/secret')));
});

test('chapter progress is owner-readable and can only be written through server APIs', async () => {
  const path = 'users/alice/chapterProgress/published-chapter';
  await assertSucceeds(getDoc(doc(alice.firestore(), path)));
  await assertSucceeds(getDocs(collection(alice.firestore(), 'users/alice/chapterProgress')));
  for (const context of [unauthenticated, bob, guest, admin]) {
    await assertFails(getDoc(doc(context.firestore(), path)));
    await assertFails(getDocs(collection(context.firestore(), 'users/alice/chapterProgress')));
  }
  for (const context of [unauthenticated, alice, bob, guest, admin]) {
    await assertFails(setDoc(doc(context.firestore(), 'users/alice/chapterProgress/new-chapter'), { audioPositionMs: 0 }));
    await assertFails(updateDoc(doc(context.firestore(), path), { audioPositionMs: 240000 }));
    await assertFails(deleteDoc(doc(context.firestore(), path)));
  }
});
