import { existsSync, readFileSync, readdirSync } from "node:fs";

const requiredFiles = [
  ".firebaserc",
  "firebase.json",
  "firebase/firestore.rules",
  "firebase/firestore.indexes.json",
  "firebase/storage.rules",
  "firebase/remoteconfig.template.json",
  "firebase/functions/package-lock.json",
  "infra/terraform/backend.hcl.example",
  "infra/terraform/main.tf",
  "infra/terraform/terraform.tfvars.example",
  "firebase/migrations/run.mjs",
];

const missing = requiredFiles.filter((path) => !existsSync(path));
if (missing.length > 0) throw new Error(`Missing portability files:\n- ${missing.join("\n- ")}`);

const firebaseConfig = JSON.parse(readFileSync("firebase.json", "utf8"));
for (const product of ["functions", "firestore", "storage", "remoteconfig", "hosting", "emulators"]) {
  if (!firebaseConfig[product]) throw new Error(`firebase.json does not track ${product}.`);
}

const indexes = JSON.parse(readFileSync("firebase/firestore.indexes.json", "utf8"));
const ttlKeys = new Set(
  (indexes.fieldOverrides ?? [])
    .filter((field) => field.ttl === true)
    .map((field) => `${field.collectionGroup}.${field.fieldPath}`),
);
for (const requiredTtl of ["invitations.expiresAt", "qr_sessions.expiresAt"]) {
  if (!ttlKeys.has(requiredTtl)) throw new Error(`Missing tracked TTL policy ${requiredTtl}.`);
}

const migrationFiles = readdirSync("firebase/migrations")
  .filter((name) => /^\d{3}_[a-z0-9_]+\.mjs$/.test(name))
  .sort();
if (migrationFiles.length === 0) throw new Error("No numbered Firestore migrations found.");
if (new Set(migrationFiles.map((name) => name.slice(0, 3))).size !== migrationFiles.length) {
  throw new Error("Firestore migration numbers must be unique.");
}

console.log(
  `Portability check passed: ${requiredFiles.length} infrastructure files, ` +
    `${indexes.indexes?.length ?? 0} indexes, ${ttlKeys.size} TTL policies, ` +
    `${migrationFiles.length} data migration(s).`,
);
