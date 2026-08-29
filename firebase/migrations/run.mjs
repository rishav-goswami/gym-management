import { createRequire } from "node:module";

import * as foundationMetadata from "./001_foundation_metadata.mjs";
import * as memberIdentity from "./002_backfill_member_identity.mjs";
import * as personalFitnessSpaces from "./003_personal_fitness_spaces.mjs";
import * as personalProgressMedia from "./004_personal_progress_media.mjs";
import * as unifiedSupportHub from "./005_unified_support_hub.mjs";

const require = createRequire(new URL("../functions/package.json", import.meta.url));
const { applicationDefault, getApps, initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { FieldPath, FieldValue, getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

const migrations = [
  foundationMetadata,
  memberIdentity,
  personalFitnessSpaces,
  personalProgressMedia,
  unifiedSupportHub,
];
const args = new Map();
for (let index = 2; index < process.argv.length; index += 1) {
  const value = process.argv[index];
  if (value.startsWith("--")) args.set(value.slice(2), process.argv[index + 1]?.startsWith("--") ? true : process.argv[++index]);
}

const projectId = args.get("project");
const confirmation = args.get("confirm");
const dryRun = args.has("dry-run");
const bucketName = args.get("bucket");

if (typeof projectId !== "string" || !/^[a-z][a-z0-9-]{4,29}$/.test(projectId)) {
  throw new Error("Usage: node firebase/migrations/run.mjs --project PROJECT_ID [--bucket BUCKET_NAME] [--dry-run | --confirm PROJECT_ID]");
}
if (!dryRun && confirmation !== projectId) {
  throw new Error(`Refusing to write. Rerun with --confirm ${projectId} after reviewing the target.`);
}

if (getApps().length === 0) initializeApp({
  credential: applicationDefault(),
  projectId,
  ...(typeof bucketName === "string" ? { storageBucket: bucketName } : {}),
});
const db = getFirestore();
const bucket = typeof bucketName === "string" ? getStorage().bucket(bucketName) : undefined;

for (const migration of migrations) {
  const record = db.doc(`_schema_migrations/${migration.id}`);
  const existing = await record.get();
  if (existing.exists) {
    console.log(`skip ${migration.id} (already applied)`);
    continue;
  }
  if (dryRun) {
    console.log(`pending ${migration.id}: ${migration.description}`);
    if (migration.preview) {
      const report = await migration.preview({ db, auth: getAuth(), bucket, FieldPath, FieldValue });
      console.log(JSON.stringify(report, null, 2));
    }
    continue;
  }
  await migration.apply({ db, auth: getAuth(), bucket, FieldPath, FieldValue });
  await record.create({
    id: migration.id,
    description: migration.description,
    appliedAt: FieldValue.serverTimestamp(),
  });
  console.log(`applied ${migration.id}`);
}
