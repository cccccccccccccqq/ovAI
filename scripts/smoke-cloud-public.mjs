import assert from 'node:assert/strict';
import {createHash, randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {initializeApp, deleteApp} from 'firebase/app';
import {getFirestore, collection, doc, query, where, getDocsFromServer, getDocFromServer, terminate, setLogLevel} from 'firebase/firestore';
import {getStorage, ref, getDownloadURL, getMetadata} from 'firebase/storage';
import {CLOUD_PROJECT, CHAPTERS, VOICES, assertCloudTarget, canonicalJson} from './cloud-catalog-lib.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

// Read the MP4 movie header rather than trusting catalog duration alone.
export function m4aDurationSeconds(bytes) {
  function find(start, end, wanted) {
    for (let offset = start; offset + 8 <= end;) {
      let size = bytes.readUInt32BE(offset);
      const type = bytes.toString('ascii', offset + 4, offset + 8);
      let header = 8;
      if (size === 1) {
        assert.ok(offset + 16 <= end, 'Truncated extended MP4 atom.');
        size = Number(bytes.readBigUInt64BE(offset + 8));
        header = 16;
      } else if (size === 0) size = end - offset;
      assert.ok(Number.isSafeInteger(size) && size >= header && offset + size <= end, 'Invalid MP4 atom size.');
      if (type === wanted) return {start: offset + header, end: offset + size};
      offset += size;
    }
    throw new Error(`Missing MP4 ${wanted} header.`);
  }
  const movie = find(0, bytes.length, 'moov');
  const header = find(movie.start, movie.end, 'mvhd');
  const version = bytes[header.start];
  assert.ok(version === 0 || version === 1, 'Unsupported MP4 movie header.');
  const timescaleOffset = header.start + (version === 0 ? 12 : 20);
  const durationOffset = timescaleOffset + 4;
  assert.ok(durationOffset + (version === 0 ? 4 : 8) <= header.end, 'Truncated MP4 movie header.');
  const timescale = bytes.readUInt32BE(timescaleOffset);
  const duration = version === 0 ? bytes.readUInt32BE(durationOffset) : Number(bytes.readBigUInt64BE(durationOffset));
  assert.ok(timescale > 0 && Number.isFinite(duration), 'Invalid MP4 duration.');
  return duration / timescale;
}

export async function main(args = process.argv.slice(2)) {
  assert.equal(args.length, 1, 'Pass the path to downloaded target web SDK JSON. This script only reads public cloud data.');
  const config = JSON.parse(await readFile(path.resolve(args[0]), 'utf8'));
  assertCloudTarget({project: config.projectId, bucket: config.storageBucket});
  assert.equal(config.projectId, CLOUD_PROJECT);
  const history = JSON.parse(await readFile(path.join(root, 'seed/secret-history-english.json'), 'utf8'));
  const production = JSON.parse(await readFile(path.join(root, 'seed/secret-history-english-audio.production.json'), 'utf8'));
  const app = initializeApp(config, `ov-readonly-cloud-smoke-${randomUUID()}`);
  const db = getFirestore(app);
  const storage = getStorage(app);
  setLogLevel('silent');
  try {
    const [sites, templates, series] = await Promise.all([
      getDocsFromServer(query(collection(db, 'sites'), where('status', '==', 'published'))),
      getDocsFromServer(query(collection(db, 'storyTemplates'), where('status', '==', 'published'))),
      getDocFromServer(doc(db, 'series', 'temujin-childhood-en')),
    ]);
    assert.equal(sites.size, 5, 'Expected all five published places.');
    assert.equal(templates.size, 17, 'Expected all seventeen published prepared templates.');
    assert.ok(sites.docs.some((item) => item.id === 'onon' && item.data().name === 'Onon River'));
    assert.ok(series.exists());
    assert.equal(series.data().language, 'en');
    assert.deepEqual(series.data().chapterIds, CHAPTERS);
    const templateById = new Map(templates.docs.map((item) => [item.id, item.data()]));
    for (const expected of history.templates) {
      const actual = templateById.get(expected.id);
      assert.ok(actual, `Missing English template ${expected.id}.`);
      for (const field of ['id', 'siteId', 'language', 'contentKind', 'durationMs', 'chapter', 'segments', 'citations', 'scenes', 'sourceSections', 'nextIds', 'audioByVoice']) {
        assert.equal(canonicalJson(actual[field]), canonicalJson(expected[field]), `Template mismatch ${expected.id}/${field}.`);
      }
      assert.deepEqual(actual.voiceIds, VOICES);
    }
    const chapters = await Promise.all(CHAPTERS.map((id) => getDocFromServer(doc(db, 'chapters', id))));
    for (const [index, snapshot] of chapters.entries()) {
      assert.ok(snapshot.exists(), `Missing chapter ${CHAPTERS[index]}.`);
      const expected = history.chapters.find((item) => item.id === snapshot.id);
      assert.equal(snapshot.data().language, 'en');
      assert.equal(snapshot.data().durationMs, 240000);
      assert.equal(canonicalJson(snapshot.data().segments), canonicalJson(expected.segments));
      assert.equal(canonicalJson(snapshot.data().scenes), canonicalJson(expected.scenes));
    }
    console.log('PASS: unauthenticated Firebase client SDK read five published places, seventeen templates, five English chapters, alternate tone and linked chapter paths.');

    const objectPath = 'catalog/audio/daniel/onon-child-en.m4a';
    const recording = production.assets.find((item) => item.voiceId === 'daniel' && item.templateId === 'onon-child-en');
    assert.ok(recording);
    const audioRef = ref(storage, objectPath);
    const [metadata, downloadUrl] = await Promise.all([getMetadata(audioRef), getDownloadURL(audioRef)]);
    assert.equal(metadata.fullPath, objectPath);
    assert.equal(metadata.contentType, 'audio/mp4');
    assert.equal(metadata.size, recording.bytes);
    // The download URL is a bearer URL. Keep it in memory and never log it.
    const response = await fetch(downloadUrl, {signal: AbortSignal.timeout(30000)});
    assert.ok(response.ok, `Public audio fetch failed with HTTP ${response.status}.`);
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.equal(digest(bytes), recording.audioSha256, 'Cloud audio differs from the generated recording.');
    const seconds = m4aDurationSeconds(bytes);
    assert.ok(Math.abs(seconds - 240) < 0.05, 'Cloud audio is not four minutes long.');
    console.log(`PASS: Storage SDK metadata and getDownloadURL work; downloaded Daniel narration matches SHA-256 and actual M4A duration ${seconds.toFixed(3)} seconds.`);

    await assert.rejects(getDocsFromServer(collection(db, 'users', 'cloud-readonly-probe', 'library')), {code: 'permission-denied'});
    await assert.rejects(getDocFromServer(doc(db, 'sources', 'secret-history-de-rachewiltz-2015')), {code: 'permission-denied'});
    console.log('PASS: unauthenticated private library and administrative source reads were denied. No Auth user or cloud document/object was created or changed.');
  } finally {
    await terminate(db);
    await deleteApp(app);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    // SDK diagnostics can include resource URLs. Print only safe failure labels.
    console.error(`Cloud public smoke failed: ${error.code ?? error.name ?? 'unknown'}.`);
    if (error instanceof assert.AssertionError) console.error(error.message);
    process.exitCode = 1;
  });
}
