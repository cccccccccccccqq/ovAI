import {readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';

// This command intentionally cannot write into a live Firebase project.
const projectId = 'demo-ov-chronicles';
const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:18080';
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199';
for (const value of [host, storageHost]) {
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(value)) {
    throw new Error('Seed accepts only loopback emulator hosts.');
  }
}
for (const value of [process.env.GCLOUD_PROJECT, process.env.GOOGLE_CLOUD_PROJECT]) {
  if (value && value !== projectId) throw new Error('Seed requires demo-ov-chronicles.');
}
const args = process.argv.slice(2);
if (args.some((arg) => arg !== '--with-media')) throw new Error('Supported option: --with-media');
process.env.FIRESTORE_EMULATOR_HOST = host;
process.env.FIREBASE_STORAGE_EMULATOR_HOST = storageHost;
const root = fileURLToPath(new URL('../', import.meta.url));
const catalog = JSON.parse(await readFile(path.join(root, 'seed/catalog.json'), 'utf8'));
const app = initializeApp({projectId, storageBucket: `${projectId}.appspot.com`});

try {
  const db = getFirestore(app);
  const bucket = getStorage(app).bucket();
  const withMedia = args.includes('--with-media');
  if (withMedia) {
    const paths = new Set(catalog.sites.map((site) => site.imagePath));
    for (const template of catalog.templates) {
      paths.add(template.imagePath);
      for (const voice of template.voiceIds) {
        const objectPath = `catalog/audio/${voice}/${template.id}.m4a`;
        paths.add(objectPath);
        template.audioByVoice[voice] = {storagePath: objectPath, status: 'ready'};
      }
    }
    for (const objectPath of paths) {
      if (!/^catalog\/(audio|images)\/[A-Za-z0-9_./-]+$/.test(objectPath) || objectPath.includes('..')) {
        throw new Error('Unsafe catalog media path.');
      }
      const localPath = path.join(root, 'app/assets', objectPath.slice('catalog/'.length));
      const contentType = objectPath.endsWith('.m4a') ? 'audio/mp4' : 'image/jpeg';
      await bucket.file(objectPath).save(await readFile(localPath), {
        resumable: false,
        metadata: {contentType, cacheControl: 'public,max-age=3600'},
      });
    }
    console.log(`Seeded ${paths.size} media files into Storage emulator.`);
  }
  const batch = db.batch();
  for (const site of catalog.sites) batch.set(db.doc(`sites/${site.id}`), site);
  for (const template of catalog.templates) {
    batch.set(db.doc(`storyTemplates/${template.id}`), {
      ...template,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Seeded ${catalog.sites.length} sites and ${catalog.templates.length} prepared templates into ${projectId}.`);
} finally {
  await deleteApp(app);
}
