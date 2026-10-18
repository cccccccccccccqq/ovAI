import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile, writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {applicationDefault} from 'firebase-admin/app';
import {CLOUD_PROJECT, assertCloudTarget, assertCatalogDocument, documentAction, loadCatalogPlan, sha256} from './cloud-catalog-lib.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const require = createRequire(import.meta.url);

export function parseOptions(args) {
  const options = {project: CLOUD_PROJECT, mode: 'plan', firebaseCliAuth: false};
  const modes = [];
  for (const arg of args) {
    if (['--inspect', '--apply', '--verify'].includes(arg)) modes.push(arg.slice(2));
    else if (arg === '--firebase-cli-auth') options.firebaseCliAuth = true;
    else if (arg.startsWith('--project=')) options.project = arg.slice('--project='.length);
    else if (arg.startsWith('--bucket=')) options.bucket = arg.slice('--bucket='.length);
    else if (arg.startsWith('--manifest-out=')) options.manifestOut = arg.slice('--manifest-out='.length);
    else if (arg.startsWith('--manifest-sha256=')) options.expectedManifest = arg.slice('--manifest-sha256='.length);
    else throw new Error(`Unknown option ${arg}. Supported: --inspect, --apply, --verify, --project=, --bucket=, --manifest-out=, --manifest-sha256=, --firebase-cli-auth.`);
  }
  assert.ok(modes.length <= 1, 'Choose exactly one cloud operation. No operation means a local dry-run.');
  options.mode = modes[0] ?? 'plan';
  assert.equal(options.project, CLOUD_PROJECT, `Only ${CLOUD_PROJECT} is accepted.`);
  if (options.mode !== 'plan') assertCloudTarget(options);
  if (options.mode === 'apply') assert.match(options.expectedManifest ?? '', /^[a-f0-9]{64}$/, 'Apply requires the SHA-256 printed by the local plan.');
  return options;
}

export function firestoreFields(value) {
  const encode = (item) => {
    if (item === null) return {nullValue: null};
    if (typeof item === 'string') return {stringValue: item};
    if (typeof item === 'boolean') return {booleanValue: item};
    if (typeof item === 'number') {
      assert.ok(Number.isFinite(item), 'Firestore does not accept non-finite catalog numbers.');
      return Number.isSafeInteger(item) ? {integerValue: String(item)} : {doubleValue: item};
    }
    if (Array.isArray(item)) return {arrayValue: {values: item.map(encode)}};
    assert.ok(typeof item === 'object', 'Unsupported catalog field.');
    return {mapValue: {fields: Object.fromEntries(Object.entries(item).map(([key, child]) => [key, encode(child)]))}};
  };
  return encode(value).mapValue.fields;
}

export function decodeFirestoreFields(fields = {}) {
  const decode = (item) => {
    if ('nullValue' in item) return null;
    if ('stringValue' in item) return item.stringValue;
    if ('booleanValue' in item) return item.booleanValue;
    if ('integerValue' in item) return Number(item.integerValue);
    if ('doubleValue' in item) return item.doubleValue;
    if ('arrayValue' in item) return (item.arrayValue.values ?? []).map(decode);
    if ('mapValue' in item) return decodeFirestoreFields(item.mapValue.fields ?? {});
    // Extra server timestamp/reference fields are not part of authored content.
    return item;
  };
  return Object.fromEntries(Object.entries(fields).map(([key, item]) => [key, decode(item)]));
}

async function tokenProvider(firebaseCliAuth) {
  if (!firebaseCliAuth) {
    const credential = applicationDefault();
    return async () => (await credential.getAccessToken()).access_token;
  }
  // Reuse the installed Firebase CLI's existing account entirely in memory.
  // No credential is copied to the project, a file or an environment variable.
  const auth = require('firebase-tools/lib/auth.js');
  const account = auth.getProjectDefaultAccount(root);
  assert.ok(account?.tokens?.refresh_token, 'Firebase CLI is not signed in. Run npm run firebase -- login.');
  let current;
  let refreshing;
  return async () => {
    if (current && current.expiresAt > Date.now() + 60000) return current.accessToken;
    refreshing ??= (async () => {
      const token = await auth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
      assert.ok(token.access_token, 'Firebase CLI could not refresh its login.');
      current = {accessToken: token.access_token, expiresAt: token.expires_at ?? Date.now() + 300000};
      return current.accessToken;
    })();
    try {
      return await refreshing;
    } finally {
      refreshing = undefined;
    }
  };
}

async function concurrently(items, callback, count = 4) {
  let index = 0;
  let failure;
  const results = new Array(items.length);
  await Promise.all(Array.from({length: Math.min(count, items.length)}, async () => {
    while (index < items.length && !failure) {
      const current = index++;
      try {
        results[current] = await callback(items[current], current);
      } catch (error) {
        failure ??= error;
      }
    }
  }));
  if (failure) throw failure;
  return results;
}

export async function createCloudClient(options, {accessTokenProvider, fetcher = fetch} = {}) {
  assertCloudTarget(options);
  const accessToken = accessTokenProvider ?? await tokenProvider(options.firebaseCliAuth);
  const request = async (url, {allowMissing = false, bytes = false, ...init} = {}) => {
    const response = await fetcher(url, {...init, headers: {...init.headers, Authorization: `Bearer ${await accessToken()}`}});
    if (allowMissing && response.status === 404) return undefined;
    if (!response.ok) {
      const parsed = await response.json().catch(() => ({}));
      throw new Error(`Cloud request failed (${response.status}): ${parsed.error?.message ?? response.statusText}`);
    }
    return bytes ? Buffer.from(await response.arrayBuffer()) : response.json();
  };
  const database = `projects/${options.project}/databases/(default)`;
  const documentRoot = `https://firestore.googleapis.com/v1/${database}/documents`;
  const bucketRoot = `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(options.bucket)}`;
  return {
    async inspectInfrastructure() {
      const [databaseMetadata, bucketMetadata] = await Promise.all([
        request(`https://firestore.googleapis.com/v1/${database}`),
        request(`${bucketRoot}?fields=name,projectNumber,location`),
      ]);
      assert.equal(databaseMetadata.name, database);
      assert.equal(bucketMetadata.name, options.bucket);
      assert.equal(bucketMetadata.projectNumber, '765364993612', 'Storage belongs to a different Google Cloud project.');
      console.log(`Cloud target confirmed: ${options.project}, Firestore ${databaseMetadata.locationId}, bucket ${bucketMetadata.name} (${bucketMetadata.location}).`);
    },
    async getDocument(documentPath) {
      assertCatalogDocument(documentPath);
      const result = await request(`${documentRoot}/${documentPath}`, {allowMissing: true});
      return result === undefined ? undefined : decodeFirestoreFields(result.fields);
    },
    async getMedia(file) {
      const object = `${bucketRoot}/o/${encodeURIComponent(file.path)}`;
      const metadata = await request(`${object}?fields=name,size,generation,contentType,metadata`, {allowMissing: true});
      if (!metadata) return 'create';
      if (Number(metadata.size) !== file.bytes || metadata.contentType !== file.contentType) return 'conflict';
      // Flutter getDownloadURL requires the Firebase-specific download token.
      // A raw GCS upload does not mint one automatically. Existing tokenless
      // objects need explicit review; never rotate or patch their tokens here.
      const downloadTokens = metadata.metadata?.firebaseStorageDownloadTokens;
      if (typeof downloadTokens !== 'string' || !downloadTokens.split(',')[0].trim()) return 'conflict';
      // Use the pinned generation for readback; a same-size object is not proof
      // of identical narration. Metadata alone never bypasses the checksum.
      const bytes = await request(`${object}?alt=media&generation=${metadata.generation}`, {bytes: true});
      return sha256(bytes) === file.sha256 ? 'identical' : 'conflict';
    },
    async upload(file) {
      const bytes = await readFile(file.localPath);
      assert.equal(sha256(bytes), file.sha256, `Local file changed after preflight: ${file.path}.`);
      const boundary = 'ov_catalog_migration_5ae61';
      const metadata = JSON.stringify({name: file.path, contentType: file.contentType, cacheControl: 'public,max-age=3600', metadata: {sha256: file.sha256, migration: 'ov-cloud-catalog-v1', firebaseStorageDownloadTokens: randomUUID()}});
      const body = Buffer.concat([
        Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n--${boundary}\r\nContent-Type: ${file.contentType}\r\n\r\n`),
        bytes,
        Buffer.from(`\r\n--${boundary}--\r\n`),
      ]);
      await request(`https://storage.googleapis.com/upload/storage/v1/b/${encodeURIComponent(options.bucket)}/o?uploadType=multipart&ifGenerationMatch=0`, {method: 'POST', headers: {'Content-Type': `multipart/related; boundary=${boundary}`}, body});
      assert.equal(await this.getMedia(file), 'identical', `Uploaded object differs: ${file.path}.`);
    },
    async createDocuments(documents) {
      if (!documents.length) return;
      assert.ok(documents.length <= 500, 'Catalog exceeds one atomic Firestore commit.');
      const writes = documents.map(({path: documentPath, data}) => {
        assertCatalogDocument(documentPath);
        return {update: {name: `${database}/documents/${documentPath}`, fields: firestoreFields(data)}, currentDocument: {exists: false}};
      });
      await request(`${documentRoot}:commit`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({writes})});
    },
  };
}

export async function main(args = process.argv.slice(2), {clientFactory = createCloudClient} = {}) {
  const options = parseOptions(args);
  const {publishedTemplate} = await import('../functions/lib/src/domain.js');
  const plan = await loadCatalogPlan(root, publishedTemplate);
  console.log(`Validated local catalog: ${plan.manifest.totals.documents} documents, ${plan.media.length} media objects, ${plan.manifest.totals.mediaBytes} bytes.`);
  console.log(`Manifest SHA-256: ${plan.manifestSha256}`);
  if (options.manifestOut) {
    await writeFile(path.resolve(root, options.manifestOut), `${JSON.stringify({...plan.manifest, manifestSha256: plan.manifestSha256}, null, 2)}\n`);
    console.log('Wrote credential-free migration manifest.');
  }
  if (options.mode === 'plan') {
    console.log('Local dry-run only: no cloud request and no cloud write was made.');
    return;
  }
  if (options.mode === 'apply') assert.equal(options.expectedManifest, plan.manifestSha256, 'Catalog changed since the plan was reviewed. Run the plan again.');
  const client = await clientFactory(options);
  await client.inspectInfrastructure();
  const documentResults = await concurrently(plan.documents, async (document) => ({...document, action: documentAction(await client.getDocument(document.path), document.data)}));
  const mediaResults = await concurrently(plan.media, async (file) => ({...file, action: await client.getMedia(file)}));
  const summarize = (items) => Object.fromEntries(['create', 'identical', 'conflict'].map((action) => [action, items.filter((item) => item.action === action).length]));
  console.log(JSON.stringify({documents: summarize(documentResults), media: summarize(mediaResults)}));
  const conflicts = [...documentResults, ...mediaResults].filter((item) => item.action === 'conflict');
  if (conflicts.length) {
    for (const conflict of conflicts) console.error(`Conflict: ${conflict.path}`);
    throw new Error('Existing cloud content differs. No migration write was made; resolve the listed IDs explicitly.');
  }
  if (options.mode === 'verify') {
    assert.ok([...documentResults, ...mediaResults].every((item) => item.action === 'identical'), 'Cloud migration is incomplete: one or more expected documents or objects are missing.');
    console.log('Verified every authored Firestore field and the downloaded SHA-256 of every media object.');
    return;
  }
  if (options.mode === 'inspect') {
    console.log('Cloud inspection only: no write was made.');
    return;
  }
  const missingMedia = mediaResults.filter((item) => item.action === 'create');
  let completed = 0;
  await concurrently(missingMedia, async (file) => {
    await client.upload(file);
    completed++;
    if (completed % 8 === 0 || completed === missingMedia.length) console.log(`Uploaded and verified ${completed}/${missingMedia.length} missing media objects.`);
  });
  // Publish only after all media is present and checked. Concurrent cloud edits
  // fail the exists:false precondition atomically instead of being overwritten.
  await client.createDocuments(documentResults.filter((item) => item.action === 'create'));
  for (const document of plan.documents) assert.equal(documentAction(await client.getDocument(document.path), document.data), 'identical', `Cloud document readback failed: ${document.path}.`);
  console.log(`Cloud migration complete: ${options.project}. Existing content and user data were preserved. Run --verify for an independent full readback.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    // Do not print credential objects or full HTTP request diagnostics.
    console.error(error.message);
    process.exitCode = 1;
  });
}
