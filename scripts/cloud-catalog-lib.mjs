import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import path from 'node:path';

export const CLOUD_PROJECT = 'ov-ai-5ae61';
export const VOICES = ['samantha', 'daniel', 'karen', 'moira'];
export const CHAPTERS = ['onon-child-en', 'hoelun-family-en', 'brothers-conflict-en', 'taichiud-escape-en', 'eight-horses-en'];
const WRITABLE_COLLECTIONS = new Set(['sites', 'storyTemplates', 'chapters', 'series', 'historicalPlaces', 'sources']);

export function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

export function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function assertCloudTarget({project, bucket}, environment = process.env) {
  assert.equal(project, CLOUD_PROJECT, `Only ${CLOUD_PROJECT} is accepted.`);
  assert.ok([`${project}.firebasestorage.app`, `${project}.appspot.com`].includes(bucket), 'An explicit bucket belonging to the target project is required.');
  for (const [key, value] of Object.entries(environment)) {
    if (/EMULATOR|FIREBASE_DATABASE_EMULATOR/.test(key)) assert.ok(!value, `Unset ${key} before using the cloud migration.`);
  }
  for (const key of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT', 'FIREBASE_PROJECT_ID']) {
    assert.ok(!environment[key] || environment[key] === project, `${key} conflicts with the cloud target.`);
  }
}

export function assertCatalogDocument(documentPath) {
  const parts = documentPath.split('/');
  assert.equal(parts.length, 2, 'Only top-level editorial documents can be migrated.');
  assert.ok(WRITABLE_COLLECTIONS.has(parts[0]), 'User data and Auth records cannot be migrated by this tool.');
  assert.match(parts[1], /^[a-z0-9][a-z0-9-]*$/);
}

export function assetPath(root, objectPath) {
  assert.match(objectPath, /^catalog\/(audio|images)\/[A-Za-z0-9_./-]+$/);
  assert.ok(!objectPath.split('/').some((part) => ['.', '..', ''].includes(part)), 'Unsafe Storage path.');
  return path.join(root, 'app/assets', objectPath.slice('catalog/'.length));
}

// Unknown server fields are retained. Every authored field must match, however;
// a different title, narration or map position is a conflict, never overwritten.
export function documentAction(existing, desired) {
  if (existing === undefined) return 'create';
  return Object.entries(desired).every(([key, value]) => canonicalJson(existing[key]) === canonicalJson(value)) ? 'identical' : 'conflict';
}

export async function loadCatalogPlan(root, validateTemplate) {
  const inputNames = ['seed/catalog.json', 'seed/secret-history-english.json', 'seed/secret-history-english-audio.production.json', 'seed/cloud-catalog-provenance.json'];
  const inputs = await Promise.all(inputNames.map(async (name) => ({name, bytes: await readFile(path.join(root, name))})));
  const [demo, history, production, provenance] = inputs.map(({bytes}) => JSON.parse(bytes));
  assert.equal(demo.schemaVersion, 1);
  assert.equal(history.schemaVersion, 1);
  assert.equal(history.series.id, 'temujin-childhood-en');
  assert.equal(history.series.language, 'en');
  assert.deepEqual(history.series.chapterIds, CHAPTERS);
  assert.equal(history.templates.length, 6);
  assert.equal(production.assets.length, 24);
  assert.equal(production.catalogSha256, sha256(inputs[1].bytes), 'Audio was generated from a different historical catalog.');
  const documents = [];
  const documentIds = new Set();
  const add = (collection, value) => {
    const documentPath = `${collection}/${value.id}`;
    assertCatalogDocument(documentPath);
    assert.ok(!documentIds.has(documentPath), `Duplicate document ${documentPath}.`);
    documentIds.add(documentPath);
    documents.push({path: documentPath, data: value});
  };
  const mediaPaths = new Set();
  const productionByPath = new Map();
  for (const record of production.assets) {
    const objectPath = `catalog/audio/${record.voiceId}/${record.templateId}.m4a`;
    assert.ok(!productionByPath.has(objectPath), 'Duplicate audio production record.');
    assert.equal(record.assetPath, `assets/${objectPath.slice('catalog/'.length)}`);
    assert.equal(record.measuredSeconds, 240);
    productionByPath.set(objectPath, record);
  }
  for (const catalog of [demo, history]) {
    for (const site of catalog.sites) {
      assert.equal(site.status, 'published');
      add('sites', site);
      mediaPaths.add(site.imagePath);
    }
    for (const inputTemplate of catalog.templates) {
      const template = structuredClone(inputTemplate);
      assert.deepEqual(template.voiceIds, VOICES);
      // Demo audio paths were populated only by the old emulator importer.
      for (const voice of VOICES) template.audioByVoice[voice] = {storagePath: `catalog/audio/${voice}/${template.id}.m4a`, status: 'ready'};
      validateTemplate?.(template, template.id);
      if (catalog === history) {
        assert.equal(template.durationMs, 240000);
        assert.equal(template.language, 'en');
        assert.equal(template.contentKind, 'historical-synopsis');
        assert.ok(!/[\u0400-\u04ff]/u.test([template.title, template.seed, ...template.segments.map((segment) => segment.text)].join(' ')), 'Narration must be English.');
        for (const voice of VOICES) {
          const recording = productionByPath.get(template.audioByVoice[voice].storagePath);
          assert.ok(recording, 'A historical recording is missing.');
          assert.equal(recording.narrationSha256, sha256(template.segments.map((segment) => segment.text).join('\n\n')), 'Recording narration differs from the catalog.');
          assert.equal(recording.contentVersion, template.contentVersion);
        }
      }
      add('storyTemplates', template);
      mediaPaths.add(template.imagePath);
      for (const voice of VOICES) mediaPaths.add(template.audioByVoice[voice].storagePath);
    }
  }
  add('series', history.series);
  for (const chapter of history.chapters) {
    assert.ok(CHAPTERS.includes(chapter.id));
    const template = history.templates.find((item) => item.id === chapter.id);
    assert.equal(chapter.status, 'published');
    assert.equal(chapter.language, 'en');
    assert.equal(chapter.durationMs, 240000);
    for (const key of ['segments', 'scenes', 'citations', 'audioByVoice', 'sourceSections', 'nextIds']) {
      assert.equal(canonicalJson(chapter[key]), canonicalJson(template[key]), `Shared chapter and template differ: ${chapter.id}/${key}.`);
    }
    assert.equal(chapter.narrationText, chapter.segments.map((segment) => segment.text).join('\n\n'));
    add('chapters', chapter);
  }
  assert.equal(history.chapters.length, 5);
  const historicalPlaces = new Set(history.historicalPlaces.map((place) => place.id));
  for (const place of history.historicalPlaces) {
    assert.ok(['regional', 'uncertain'].includes(place.confidence), 'Unverified historical places must remain approximate.');
    assert.ok(Number.isFinite(place.radiusMeters) && place.radiusMeters > 0);
    add('historicalPlaces', place);
  }
  for (const template of history.templates) {
    assert.deepEqual(template.nextIds, CHAPTERS[template.chapter] ? [CHAPTERS[template.chapter]] : []);
    for (const scene of template.scenes) assert.ok(historicalPlaces.has(scene.placeId));
  }
  for (const source of provenance.sources) add('sources', source);
  const citations = new Map();
  for (const template of [...demo.templates, ...history.templates]) {
    for (const citation of template.citations) {
      if (citations.has(citation.id)) assert.equal(canonicalJson(citations.get(citation.id)), canonicalJson(citation), 'Conflicting citation ID.');
      citations.set(citation.id, citation);
    }
  }
  for (const citation of citations.values()) {
    add('sources', {...citation, contentKind: 'citation-metadata', ...(citation.id.startsWith('sh-') ? {sourceId: 'secret-history-de-rachewiltz-2015'} : {})});
  }
  const media = [];
  for (const objectPath of [...mediaPaths].sort()) {
    const localPath = assetPath(root, objectPath);
    const bytes = await readFile(localPath);
    assert.ok(bytes.length > 1000, `Missing or empty media ${objectPath}.`);
    const audio = objectPath.endsWith('.m4a');
    if (audio) assert.equal(bytes.subarray(4, 8).toString(), 'ftyp', `Invalid M4A ${objectPath}.`);
    else assert.ok(bytes[0] === 255 && bytes[1] === 216, `Invalid JPEG ${objectPath}.`);
    const digest = sha256(bytes);
    const recording = productionByPath.get(objectPath);
    if (recording) {
      assert.equal(digest, recording.audioSha256, `Audio integrity failure: ${objectPath}.`);
      assert.equal(bytes.length, recording.bytes);
    }
    media.push({path: objectPath, localPath, bytes: bytes.length, sha256: digest, contentType: audio ? 'audio/mp4' : 'image/jpeg'});
  }
  documents.sort((a, b) => a.path.localeCompare(b.path));
  const manifest = {
    schemaVersion: 1,
    projectId: CLOUD_PROJECT,
    inputFiles: inputs.map(({name, bytes}) => ({path: name, sha256: sha256(bytes)})),
    documents: documents.map(({path: documentPath, data}) => ({path: documentPath, sha256: sha256(canonicalJson(data))})),
    media: media.map(({localPath: _local, ...file}) => file),
    totals: {documents: documents.length, mediaObjects: media.length, mediaBytes: media.reduce((sum, file) => sum + file.bytes, 0), historicalChapters: 5, historicalTemplates: 6, historicalRecordings: 24},
    excluded: ['Auth users', 'users', 'chronicles', 'generationRequests', 'bookmarks and playback progress', 'source PDF and full extracted text'],
  };
  return {documents, media, manifest, manifestSha256: sha256(canonicalJson(manifest))};
}
