// Replaces the four Orkhon sites and their eleven story templates in the cloud
// catalog with the source-based versions from app/tool/sourced_content.json,
// and overwrites their narration in Storage. The create-only migration cannot
// do this because these documents already exist.
//
// Dry run (local only):   node scripts/publish-sourced-orkhon.mjs
// Inspect the cloud:      node scripts/publish-sourced-orkhon.mjs --inspect --firebase-cli-auth
// Publish:                node scripts/publish-sourced-orkhon.mjs --apply --firebase-cli-auth
//
// Only sites/, storyTemplates/ and sources/ documents and catalog/audio/
// objects for the listed IDs are written. User data is never read or written.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {CLOUD_PROJECT, VOICES, documentAction, loadCatalogPlan, sha256} from './cloud-catalog-lib.mjs';
import {createCloudClient, firestoreFields} from './migrate-cloud-catalog.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const content = JSON.parse(await readFile(path.join(root, 'app/tool/sourced_content.json'), 'utf8'));
const siteIds = Object.keys(content.sites);
const templateIds = Object.keys(content.templates);

const args = process.argv.slice(2);
const mode = args.includes('--apply') ? 'apply' : args.includes('--inspect') ? 'inspect' : 'plan';
const options = {project: CLOUD_PROJECT, bucket: `${CLOUD_PROJECT}.firebasestorage.app`, firebaseCliAuth: args.includes('--firebase-cli-auth')};

const {publishedTemplate} = await import('../functions/lib/src/domain.js');
const plan = await loadCatalogPlan(root, publishedTemplate);
const wanted = new Set([
  ...siteIds.map((id) => `sites/${id}`),
  ...templateIds.map((id) => `storyTemplates/${id}`),
]);
for (const document of plan.documents) {
  if (!document.path.startsWith('storyTemplates/') || !wanted.has(document.path)) continue;
  for (const citation of document.data.citations) wanted.add(`sources/${citation.id}`);
}
const documents = plan.documents.filter((document) => wanted.has(document.path));
const audioPaths = new Set(templateIds.flatMap((id) => VOICES.map((voice) => `catalog/audio/${voice}/${id}.m4a`)));
const media = plan.media.filter((file) => audioPaths.has(file.path));
assert.equal(documents.length, wanted.size, 'A requested document is missing from the local catalog.');
assert.equal(media.length, audioPaths.size, 'A narration file is missing locally.');
console.log(`Local plan: ${documents.length} documents (${siteIds.length} sites, ${templateIds.length} templates, ${documents.length - siteIds.length - templateIds.length} sources), ${media.length} narration files.`);
if (mode === 'plan') {
  console.log('Local dry-run only: no cloud request was made.');
  process.exit(0);
}

const client = await createCloudClient(options);
await client.inspectInfrastructure();
const status = async () => ({
  documents: await Promise.all(documents.map(async (d) => ({...d, action: documentAction(await client.getDocument(d.path), d.data)}))),
  media: await Promise.all(media.map(async (f) => ({...f, action: await client.getMedia(f)}))),
});
const count = (items) => items.reduce((sum, item) => ({...sum, [item.action]: (sum[item.action] ?? 0) + 1}), {});
const before = await status();
console.log(JSON.stringify({documents: count(before.documents), media: count(before.media)}));
if (mode === 'inspect') {
  console.log('Inspection only: no write was made.');
  process.exit(0);
}

// The token used by the CLI client is reused through its own request helper
// by calling the public REST endpoints below with the same credential path.
const {default: authModule} = await import('firebase-tools/lib/auth.js');
const account = authModule.getProjectDefaultAccount(root);
assert.ok(account?.tokens?.refresh_token, 'Firebase CLI is not signed in.');
const token = (await authModule.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform'])).access_token;
const request = async (url, init = {}) => {
  const response = await fetch(url, {...init, headers: {...init.headers, Authorization: `Bearer ${token}`}});
  if (!response.ok) throw new Error(`Cloud request failed (${response.status}): ${await response.text()}`);
  return response.json();
};
const bucketRoot = `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(options.bucket)}`;

for (const file of before.media.filter((f) => f.action !== 'identical')) {
  const bytes = await readFile(file.localPath);
  assert.equal(sha256(bytes), file.sha256);
  const existing = await fetch(`${bucketRoot}/o/${encodeURIComponent(file.path)}?fields=generation,metadata`, {headers: {Authorization: `Bearer ${token}`}});
  const current = existing.status === 404 ? undefined : await existing.json();
  // Keep an existing download token so previously issued URLs keep working.
  const downloadToken = current?.metadata?.firebaseStorageDownloadTokens?.split(',')[0] || randomUUID();
  const boundary = 'ov_sourced_orkhon';
  const metadata = JSON.stringify({name: file.path, contentType: file.contentType, cacheControl: 'public,max-age=3600', metadata: {sha256: file.sha256, migration: 'ov-sourced-orkhon-v1', firebaseStorageDownloadTokens: downloadToken}});
  const body = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n--${boundary}\r\nContent-Type: ${file.contentType}\r\n\r\n`),
    bytes,
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);
  await request(`https://storage.googleapis.com/upload/storage/v1/b/${encodeURIComponent(options.bucket)}/o?uploadType=multipart&ifGenerationMatch=${current?.generation ?? 0}`, {method: 'POST', headers: {'Content-Type': `multipart/related; boundary=${boundary}`}, body});
}
console.log('Narration uploaded.');

const database = `projects/${options.project}/databases/(default)`;
const writes = before.documents.filter((d) => d.action !== 'identical').map(({path: documentPath, data}) => ({
  update: {name: `${database}/documents/${documentPath}`, fields: firestoreFields(data)},
  // Only authored fields are replaced; server-only fields are kept.
  updateMask: {fieldPaths: Object.keys(data)},
}));
if (writes.length) await request(`https://firestore.googleapis.com/v1/${database}/documents:commit`, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({writes})});
console.log(`Committed ${writes.length} documents.`);

const after = await status();
const summary = {documents: count(after.documents), media: count(after.media)};
console.log(JSON.stringify(summary));
assert.ok([...after.documents, ...after.media].every((item) => item.action === 'identical'), 'Readback differs from the local catalog.');
console.log('Verified every published document field and the SHA-256 of every narration file.');
