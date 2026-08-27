import { createRequire } from "node:module";

import * as foundationMetadata from "./001_foundation_metadata.mjs";

const require = createRequire(new URL("../functions/package.json", import.meta.url));
const { applicationDefault, getApps, initializeApp } = require("firebase-admin/app");
const { FieldValue, getFirestore } = require("firebase-admin/firestore");

const migrations = [foundationMetadata];
const args = new Map();
for (let index = 2; index < process.argv.length; index += 1) {
  const value = process.argv[index];
  if (value.startsWith("--")) args.set(value.slice(2), process.argv[index + 1]?.startsWith("--") ? true : process.argv[++index]);
}

const projectId = args.get("project");
const confirmation = args.get("confirm");
const dryRun = args.has("dry-run");

if (typeof projectId !== "string" || !/^[a-z][a-z0-9-]{4,29}$/.test(projectId)) {
  throw new Error("Usage: node firebase/migrations/run.mjs --project PROJECT_ID [--dry-run | --confirm PROJECT_ID]");
}
if (!dryRun && confirmation !== projectId) {
  throw new Error(`Refusing to write. Rerun with --confirm ${projectId} after reviewing the target.`);
}

if (getApps().length === 0) initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();

for (const migration of migrations) {
  const record = db.doc(`_schema_migrations/${migration.id}`);
  const existing = await record.get();
  if (existing.exists) {
    console.log(`skip ${migration.id} (already applied)`);
    continue;
  }
  if (dryRun) {
    console.log(`pending ${migration.id}: ${migration.description}`);
    continue;
  }
  await migration.apply({ db, FieldValue });
  await record.create({
    id: migration.id,
    description: migration.description,
    appliedAt: FieldValue.serverTimestamp(),
  });
  console.log(`applied ${migration.id}`);
}
