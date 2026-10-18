import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {publishedTemplate} from '../functions/lib/src/domain.js';

// This editorial importer only ever writes to the local demo emulators. It
// upserts its own catalog records and does not clear account data or progress.
const projectId = 'demo-ov-chronicles';
const root = fileURLToPath(new URL('../', import.meta.url));
const args = process.argv.slice(2);
assert.ok(args.every((arg) => arg === '--validate-only'), 'Supported option: --validate-only');
const validateOnly = args.includes('--validate-only');
const catalog = JSON.parse(await readFile(path.join(root, 'seed/secret-history-english.json'), 'utf8'));
const canonicalIds = ['onon-child-en', 'hoelun-family-en', 'brothers-conflict-en', 'taichiud-escape-en', 'eight-horses-en'];
const voiceIds = ['samantha', 'daniel', 'karen', 'moira'];
assert.equal(catalog.schemaVersion, 1);
assert.equal(catalog.contentKind, 'historical-synopsis');
assert.equal(catalog.series.id, 'temujin-childhood-en');
assert.equal(catalog.series.language, 'en');
assert.equal(catalog.series.status, 'published');
assert.deepEqual(catalog.series.chapterIds, canonicalIds);
assert.equal(catalog.sites.length, 1);
assert.equal(catalog.sites[0].id, 'onon');
assert.equal(catalog.sites[0].status, 'published');
assert.equal(catalog.templates.length, 6);
const templates = new Map();
const placeIds = new Set(catalog.historicalPlaces.map((place) => place.id));
for (const place of catalog.historicalPlaces) {
  assert.equal(place.status, 'published');
  assert.ok(['regional', 'uncertain'].includes(place.confidence));
  assert.ok(Number.isFinite(place.center?.latitude) && Math.abs(place.center.latitude) <= 90);
  assert.ok(Number.isFinite(place.center?.longitude) && Math.abs(place.center.longitude) <= 180);
  assert.ok(Number.isFinite(place.radiusMeters) && place.radiusMeters > 0);
}
for (const raw of catalog.templates) {
  const template = publishedTemplate(raw, raw.id);
  assert.ok(!templates.has(template.id), 'Duplicate story template.');
  assert.equal(template.siteId, 'onon');
  assert.equal(template.seriesId, catalog.series.id);
  assert.equal(template.contentKind, 'historical-synopsis');
  assert.equal(template.durationMs, 240000);
  assert.deepEqual(template.voiceIds, voiceIds);
  assert.ok(template.scenes.length > 0);
  assert.ok(!/[\u0400-\u04ff]/u.test([template.title, template.subtitle, template.seed, ...template.segments.map((s) => s.text)].join(' ')), 'Published narration must be English.');
  for (const scene of template.scenes) assert.ok(placeIds.has(scene.placeId), 'Unknown map area.');
  for (const voice of voiceIds) {
    assert.equal(template.audioByVoice[voice]?.storagePath, `catalog/audio/${voice}/${template.id}.m4a`);
  }
  templates.set(template.id, template);
}
assert.ok(templates.has('onon-child-lyrical-en'));
assert.equal(catalog.chapters.length, 5);
for (const [index, id] of canonicalIds.entries()) {
  const template = templates.get(id);
  assert.equal(template.chapter, index + 1);
  assert.deepEqual(template.nextIds, canonicalIds[index + 1] ? [canonicalIds[index + 1]] : []);
  const chapter = catalog.chapters.find((item) => item.id === id);
  assert.ok(chapter, `Missing shared chapter ${id}.`);
  assert.deepEqual(chapter.segments, template.segments);
  assert.equal(chapter.narrationText, template.segments.map((segment) => segment.text).join('\n\n'));
  assert.equal(chapter.language, 'en');
  assert.equal(chapter.durationMs, 240000);
}
if (validateOnly) {
  console.log('Validated 5 connected English chapters, 1 alternate tone, 4 voices, citations and exact 240000 ms scene timelines.');
  process.exit(0);
}
for (const variable of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT', 'FIREBASE_PROJECT_ID']) {
  assert.ok(!process.env[variable] || process.env[variable] === projectId, 'Only the demo project is accepted.');
}
for (const [variable, fallback] of Object.entries({FIRESTORE_EMULATOR_HOST: '127.0.0.1:18080', FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199'})) {
  const host = process.env[variable] ?? fallback;
  assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/, 'Only loopback emulator hosts are accepted.');
  process.env[variable] = host;
}
// Preflight every file before touching Storage or publishing the catalog. A
// missing voice must not leave a story advertising an unavailable recording.
const objectPaths = new Set(catalog.sites.map((site) => site.imagePath));
for (const template of templates.values()) {
  if (template.imagePath) objectPaths.add(template.imagePath);
  for (const voice of voiceIds) objectPaths.add(template.audioByVoice[voice].storagePath);
}
const media = [];
for (const objectPath of objectPaths) {
  assert.match(objectPath, /^catalog\/(audio|images)\/[A-Za-z0-9_./-]+$/);
  assert.ok(!objectPath.split('/').some((part) => ['.', '..', ''].includes(part)), 'Unsafe Storage path.');
  const bytes = await readFile(path.join(root, 'app/assets', objectPath.slice('catalog/'.length)));
  assert.ok(bytes.length > 1000, `Missing or empty media: ${objectPath}`);
  const audio = objectPath.endsWith('.m4a');
  if (audio) assert.equal(bytes.subarray(4, 8).toString(), 'ftyp', `Invalid M4A: ${objectPath}`);
  media.push({objectPath, bytes, contentType: audio ? 'audio/mp4' : 'image/jpeg', sha256: createHash('sha256').update(bytes).digest('hex')});
}
const app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`});
try {
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket();
  for (const file of media) {
    await bucket.file(file.objectPath).save(file.bytes, {resumable: false,
      metadata: {contentType: file.contentType, cacheControl: 'public,max-age=3600',
        metadata: {sha256: file.sha256, language: 'en', contentVersion: '1'}}});
    const [metadata] = await bucket.file(file.objectPath).getMetadata();
    assert.equal(Number(metadata.size), file.bytes.length, 'Storage read-back differs.');
    assert.equal(metadata.metadata?.sha256, file.sha256);
  }
  const batch = db.batch();
  const stamp = {updatedAt: FieldValue.serverTimestamp()};
  batch.set(db.doc(`series/${catalog.series.id}`), {...catalog.series, ...stamp});
  for (const site of catalog.sites) batch.set(db.doc(`sites/${site.id}`), {...site, ...stamp});
  for (const raw of catalog.templates) batch.set(db.doc(`storyTemplates/${raw.id}`), {...raw, ...stamp});
  for (const chapter of catalog.chapters) batch.set(db.doc(`chapters/${chapter.id}`), {...chapter, ...stamp});
  for (const place of catalog.historicalPlaces) batch.set(db.doc(`historicalPlaces/${place.id}`), {...place, ...stamp});
  // Retain old narration and progress for recovery, while removing the earlier
  // Mongolian prototype from the published public chapter catalog.
  for (const documentPath of ['series/temujin-childhood', 'chapters/onon-child']) {
    const reference = db.doc(documentPath);
    if ((await reference.get()).exists) {
      batch.update(reference, {status: 'archived', replacedBy: documentPath.startsWith('series/') ? catalog.series.id : canonicalIds[0], ...stamp});
    }
  }
  await batch.commit();
  for (const id of templates.keys()) {
    const saved = await db.doc(`storyTemplates/${id}`).get();
    assert.equal(saved.get('language'), 'en');
    assert.equal(saved.get('contentKind'), 'historical-synopsis');
    assert.equal(saved.get('durationMs'), 240000);
  }
  console.log(`Saved and read back Onon site, 5 shared English chapters, 6 story templates and ${placeIds.size} approximate map areas in ${projectId}.`);
  console.log(`Uploaded and verified ${media.length} media objects, including 24 English recordings. Existing users and playback progress were preserved.`);
} finally {
  await deleteApp(app);
}
