import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';

// Deliberately restricted to the local demo project, including media uploads.
const projectId = 'demo-ov-chronicles';
const root = fileURLToPath(new URL('../', import.meta.url));
const args = process.argv.slice(2);
const validateOnly = args.includes('--validate-only');
let audioPath = path.join(root, 'app/assets/audio/secret-history/onon-child-v1/narration-mn.mp3');
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--validate-only') continue;
  if (args[i] === '--audio' && args[i + 1] && !args[i + 1].startsWith('--')) {
    audioPath = path.resolve(args[++i]);
    continue;
  }
  throw new Error('Usage: node scripts/seed-secret-history.mjs [--validate-only] [--audio /path/to/narration-mn.mp3]');
}
const catalog = JSON.parse(await readFile(path.join(root, 'seed/secret-history-chapter-1.json'), 'utf8'));
const assert = (condition, message) => { if (!condition) throw new Error(message); };
const safeId = (id) => typeof id === 'string' && /^[a-z0-9][a-z0-9-]{0,79}$/.test(id);
assert(catalog.schemaVersion === 1, 'Unsupported chapter seed schema.');
assert(catalog.series.id === 'temujin-childhood' && catalog.series.status === 'published', 'Unexpected series.');
assert(Array.isArray(catalog.chapters) && catalog.chapters.length === 1, 'Expected one selected chapter.');
const placeIds = new Set();
for (const place of catalog.historicalPlaces) {
  assert(safeId(place.id) && !placeIds.has(place.id), 'Invalid or duplicate place ID.');
  placeIds.add(place.id);
  assert(place.status === 'published', 'Only published prototype places are supported.');
  assert(['regional', 'uncertain'].includes(place.confidence), 'Places must disclose location uncertainty.');
  assert(Number.isFinite(place.center?.latitude) && Math.abs(place.center.latitude) <= 90, 'Invalid latitude.');
  assert(Number.isFinite(place.center?.longitude) && Math.abs(place.center.longitude) <= 180, 'Invalid longitude.');
  assert(Number.isFinite(place.radiusMeters) && place.radiusMeters > 0, 'Expected an approximate area.');
  assert(typeof place.description === 'string' && place.description.length > 40, 'Place context is required.');
}
const chapterIds = new Set();
for (const chapter of catalog.chapters) {
  assert(chapter.id === 'onon-child' && !chapterIds.has(chapter.id), 'Unexpected or duplicate chapter.');
  chapterIds.add(chapter.id);
  assert(chapter.status === 'published' && chapter.seriesId === catalog.series.id, 'Chapter is not in this series.');
  assert(chapter.language === 'mn' && chapter.contentVersion === 1 && chapter.durationMs === 240000, 'Expected Mongolian four-minute v1.');
  assert(chapter.audio?.storagePath === 'catalog/secret-history/onon-child-v1/narration-mn.mp3', 'Unexpected Storage path.');
  assert(chapter.audio.durationMs === chapter.durationMs, 'Audio duration differs from chapter.');
  assert(chapter.sourceSections.join(',') === '59,60,61,62,63,64,65,66', 'Unexpected source sections.');
  assert(typeof chapter.narration === 'string' && chapter.narration.length > 1000, 'Narration is missing.');
  assert(chapter.routeGeometry === null, 'This prototype must not invent a historical route.');
  let endMs = 0;
  for (const scene of chapter.scenes) {
    assert(safeId(scene.id) && scene.startMs === endMs && scene.endMs > scene.startMs, 'Scene timeline has a gap or overlap.');
    assert(Number.isInteger(scene.startMs) && Number.isInteger(scene.endMs), 'Cue times must be integer milliseconds.');
    assert(placeIds.has(scene.placeId), 'Scene refers to an unknown place.');
    assert(typeof scene.narration === 'string' && scene.narration.length > 0, 'Scene narration is missing.');
    endMs = scene.endMs;
  }
  assert(endMs === chapter.durationMs, 'Scenes do not cover four minutes.');
  assert(chapter.scenes.map((scene) => scene.narration).join('\n\n') === chapter.narration, 'Scene narration differs from chapter.');
}
assert(JSON.stringify(catalog.series.chapterIds) === JSON.stringify([...chapterIds]), 'Series order differs from seeded chapters.');
if (validateOnly) {
  console.log(`Validated ${catalog.chapters.length} Mongolian chapter, ${placeIds.size} approximate places and a 240000 ms scene timeline.`);
  process.exit(0);
}

const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:18080';
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199';
for (const value of [host, storageHost]) {
  assert(/^(127\.0\.0\.1|localhost):\d+$/.test(value), 'Seed accepts only loopback emulator hosts.');
}
for (const value of [process.env.GCLOUD_PROJECT, process.env.GOOGLE_CLOUD_PROJECT, process.env.FIREBASE_PROJECT_ID]) {
  assert(!value || value === projectId, 'Seed requires demo-ov-chronicles.');
}
process.env.FIRESTORE_EMULATOR_HOST = host;
process.env.FIREBASE_STORAGE_EMULATOR_HOST = storageHost;
// Read everything before any writes, so a missing generated audio file cannot
// publish a chapter pointing at a nonexistent object.
const audioBytes = await readFile(audioPath);
assert(audioBytes.length > 1024, 'Generated narration audio is missing or too small.');
assert(audioBytes.subarray(0, 3).toString() === 'ID3' || audioBytes[0] === 0xff, 'Expected MP3 audio.');
const sha256 = createHash('sha256').update(audioBytes).digest('hex');
const app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`});
try {
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket();
  const objectPath = catalog.chapters[0].audio.storagePath;
  await bucket.file(objectPath).save(audioBytes, {
    resumable: false,
    metadata: {contentType: 'audio/mpeg', cacheControl: 'public,max-age=3600', metadata: {sha256, language: 'mn', contentVersion: '1'}},
  });
  const batch = db.batch();
  batch.set(db.doc(`series/${catalog.series.id}`), catalog.series);
  for (const chapter of catalog.chapters) batch.set(db.doc(`chapters/${chapter.id}`), chapter);
  for (const place of catalog.historicalPlaces) batch.set(db.doc(`historicalPlaces/${place.id}`), place);
  await batch.commit();
  const snapshot = await db.doc('chapters/onon-child').get();
  assert(snapshot.exists && snapshot.data().audio.storagePath === objectPath, 'Chapter read-back failed.');
  const [metadata] = await bucket.file(objectPath).getMetadata();
  assert(Number(metadata.size) === audioBytes.length, 'Storage read-back size differs.');
  console.log(`Saved and read back series/${catalog.series.id}, chapters/onon-child and ${placeIds.size} historicalPlaces in ${projectId}.`);
  console.log(`Storage: ${objectPath} (${audioBytes.length} bytes; SHA-256 ${sha256}).`);
} finally {
  await deleteApp(app);
}
