import assert from 'node:assert/strict';
import {mkdtemp, mkdir, readFile, writeFile, symlink, rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import test from 'node:test';
import {CLOUD_PROJECT, assetPath, assertCatalogDocument, assertCloudTarget, canonicalJson, documentAction, loadCatalogPlan, sha256} from '../scripts/cloud-catalog-lib.mjs';
import {createCloudClient, decodeFirestoreFields, firestoreFields, main, parseOptions} from '../scripts/migrate-cloud-catalog.mjs';
import {publishedTemplate} from '../functions/lib/src/domain.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = {project: CLOUD_PROJECT, bucket: `${CLOUD_PROJECT}.firebasestorage.app`};

test('cloud target cannot inherit emulator routing or another project', () => {
  assert.doesNotThrow(() => assertCloudTarget(target, {}));
  for (const variable of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'STORAGE_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST', 'FIREBASE_EMULATOR_HUB']) {
    assert.throws(() => assertCloudTarget(target, {[variable]: '127.0.0.1:9199'}));
  }
  assert.throws(() => assertCloudTarget({...target, project: 'demo-ov-chronicles'}, {}));
  assert.throws(() => assertCloudTarget(target, {GCLOUD_PROJECT: 'demo-ov-chronicles'}));
  assert.throws(() => assertCloudTarget({...target, bucket: 'another-project.firebasestorage.app'}, {}));
  assert.throws(() => assertCloudTarget({...target, bucket: undefined}, {}));
});

test('writable paths exclude private user state and unsafe media names', () => {
  assert.doesNotThrow(() => assertCatalogDocument('storyTemplates/onon-child-en'));
  for (const name of ['users/demo', 'chronicles/demo', 'generationRequests/demo', 'users/demo/library/x', 'sites/../x', 'sources/.']) assert.throws(() => assertCatalogDocument(name));
  assert.equal(assetPath('/tmp/project', 'catalog/audio/daniel/onon-child-en.m4a'), '/tmp/project/app/assets/audio/daniel/onon-child-en.m4a');
  for (const name of ['catalog/audio/../x', 'catalog/images//x', 'users/photo.jpg', 'catalog/audio/./x']) assert.throws(() => assetPath(root, name));
});

test('existing differing content is a conflict while unrelated server fields survive', () => {
  const desired = {id: 'onon', title: 'Original', center: {latitude: 49.03}, nextIds: []};
  assert.equal(documentAction(undefined, desired), 'create');
  assert.equal(documentAction({...desired, updatedAt: 'server timestamp', editorialOwner: 'existing'}, desired), 'identical');
  assert.equal(documentAction({...desired, title: 'Cloud revision'}, desired), 'conflict');
  assert.equal(documentAction({...desired, center: {latitude: 47.5}}, desired), 'conflict');
});

test('Firestore REST field conversion preserves authored numbers and nested content', () => {
  const value = {english: 'Höelün', enabled: true, absent: null, count: 240000, lat: 49.03, blank: {}, paths: [], scenes: [{startMs: 0, caption: 'Beginning'}]};
  assert.deepEqual(decodeFirestoreFields(firestoreFields(value)), value);
  assert.throws(() => firestoreFields({lat: Infinity}));
});

test('CLI defaults to local dry-run and apply must pin a reviewed manifest', () => {
  assert.equal(parseOptions([]).mode, 'plan');
  assert.throws(() => parseOptions(['--project=demo-ov-chronicles']));
  assert.throws(() => parseOptions(['--inspect', '--apply']));
  assert.throws(() => parseOptions(['--apply', `--bucket=${target.bucket}`]));
  assert.throws(() => parseOptions(['--unknown']));
});

test('full migration contains canonical editorial content and intact recordings', async () => {
  const plan = await loadCatalogPlan(root, publishedTemplate);
  assert.equal(plan.documents.length, 39);
  assert.equal(plan.media.length, 72);
  assert.equal(plan.manifest.totals.historicalRecordings, 24);
  assert.ok(plan.manifest.totals.mediaBytes > 59000000);
  assert.equal(plan.documents.filter((item) => item.path.startsWith('chapters/')).length, 5);
  assert.equal(plan.documents.filter((item) => item.path.startsWith('storyTemplates/')).length, 17);
  assert.equal(plan.documents.filter((item) => item.path.startsWith('sources/')).length, 9);
  assert.ok(!plan.documents.some((item) => /^(users|chronicles|generationRequests)\//.test(item.path)));
  assert.equal(plan.manifestSha256, sha256(canonicalJson(plan.manifest)));
  assert.ok(plan.manifest.media.every((item) => !('localPath' in item)));
});

test('changed production hashes fail local preflight before any cloud operation', async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'ov-catalog-test-'));
  try {
    await mkdir(path.join(temporary, 'seed'));
    await mkdir(path.join(temporary, 'app'));
    await symlink(path.join(root, 'app/assets'), path.join(temporary, 'app/assets'));
    for (const name of ['catalog.json', 'secret-history-english.json', 'secret-history-english-audio.production.json', 'cloud-catalog-provenance.json']) {
      await writeFile(path.join(temporary, 'seed', name), await readFile(path.join(root, 'seed', name)));
    }
    const productionPath = path.join(temporary, 'seed/secret-history-english-audio.production.json');
    const production = JSON.parse(await readFile(productionPath, 'utf8'));
    production.assets[0].audioSha256 = 'a'.repeat(64);
    await writeFile(productionPath, JSON.stringify(production));
    await assert.rejects(loadCatalogPlan(temporary, publishedTemplate), /Audio integrity failure/);
    production.catalogSha256 = 'b'.repeat(64);
    await writeFile(productionPath, JSON.stringify(production));
    await assert.rejects(loadCatalogPlan(temporary, publishedTemplate), /different historical catalog/);
  } finally {
    await rm(temporary, {recursive: true, force: true});
  }
});

test('REST writes carry create-only preconditions and media readback pins its generation', async () => {
  const temporary = await mkdtemp(path.join(os.tmpdir(), 'ov-cloud-rest-'));
  const calls = [];
  const content = Buffer.from('a mocked audio payload');
  const localPath = path.join(temporary, 'test.m4a');
  const file = {path: 'catalog/audio/daniel/onon-child-en.m4a', localPath, bytes: content.length, sha256: sha256(content), contentType: 'audio/mp4'};
  const json = (data) => new Response(JSON.stringify(data), {headers: {'Content-Type': 'application/json'}});
  try {
    await writeFile(localPath, content);
    const client = await createCloudClient(target, {accessTokenProvider: async () => 'test-only', fetcher: async (url, init) => {
      calls.push({url, init});
      if (url.includes('alt=media')) return new Response(content);
      if (url.includes('/o/catalog%2Faudio')) return json({size: String(content.length), contentType: 'audio/mp4', generation: '12345', metadata: {firebaseStorageDownloadTokens: 'existing-test-token'}});
      return json({});
    }});
    await client.upload(file);
    await client.createDocuments([{path: 'sites/onon', data: {id: 'onon', status: 'published'}}]);
    const upload = calls.find((call) => call.url.includes('/upload/'));
    assert.match(upload.url, /ifGenerationMatch=0/);
    assert.match(upload.init.headers['Content-Type'], /^multipart\/related/);
    assert.match(upload.init.body.toString(), /"firebaseStorageDownloadTokens":"[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}"/);
    assert.ok(calls.some((call) => /alt=media&generation=12345/.test(call.url)));
    const commit = calls.find((call) => call.url.endsWith('/documents:commit'));
    const body = JSON.parse(commit.init.body);
    assert.deepEqual(body.writes[0].currentDocument, {exists: false});
    assert.equal(body.writes[0].update.name, `projects/${CLOUD_PROJECT}/databases/(default)/documents/sites/onon`);
    assert.ok(!('updateMask' in body.writes[0]));
  } finally {
    await rm(temporary, {recursive: true, force: true});
  }
});

test('existing tokenless media is a conflict and existing download tokens are preserved', async () => {
  let downloads = 0;
  const bytes = Buffer.from('existing audio');
  const file = {path: 'catalog/audio/daniel/onon-child-en.m4a', bytes: bytes.length, sha256: sha256(bytes), contentType: 'audio/mp4'};
  let metadata = {};
  const client = await createCloudClient(target, {accessTokenProvider: async () => 'test-only', fetcher: async (url, init) => {
    assert.ok(!init.method || init.method === 'GET', 'Inspect must never change or rotate an existing token.');
    if (url.includes('alt=media')) { downloads++; return new Response(bytes); }
    return new Response(JSON.stringify({size: String(bytes.length), contentType: 'audio/mp4', generation: '12345', metadata}));
  }});
  assert.equal(await client.getMedia(file), 'conflict');
  assert.equal(downloads, 0);
  metadata = {firebaseStorageDownloadTokens: ''};
  assert.equal(await client.getMedia(file), 'conflict');
  metadata = {firebaseStorageDownloadTokens: 'existing-token,second-token'};
  assert.equal(await client.getMedia(file), 'identical');
  assert.equal(downloads, 1);
  assert.equal(metadata.firebaseStorageDownloadTokens, 'existing-token,second-token');
});

test('any failed media upload prevents the catalog Firestore publish', async () => {
  const plan = await loadCatalogPlan(root, publishedTemplate);
  let commits = 0;
  let uploads = 0;
  const client = {
    inspectInfrastructure: async () => {},
    getDocument: async () => undefined,
    getMedia: async () => 'create',
    upload: async () => { uploads++; throw new Error('Simulated upload failure'); },
    createDocuments: async () => { commits++; },
  };
  await assert.rejects(main(['--apply', `--bucket=${target.bucket}`, `--manifest-sha256=${plan.manifestSha256}`], {clientFactory: async () => client}), /Simulated upload failure/);
  assert.ok(uploads >= 1 && uploads <= 4, 'No more uploads should be queued after the first failure.');
  assert.equal(commits, 0);
});
