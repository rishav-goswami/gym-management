import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { configstore } = require("firebase-tools/lib/configstore");
const firebaseAuth = require("firebase-tools/lib/auth");

const args = new Map();
for (let index = 2; index < process.argv.length; index += 1) {
  const value = process.argv[index];
  if (!value.startsWith("--")) continue;
  const next = process.argv[index + 1];
  args.set(value.slice(2), next && !next.startsWith("--") ? process.argv[++index] : true);
}

const projectId = args.get("project");
const requestedBucket = args.get("bucket");
const confirmation = args.get("confirm");
const dryRun = args.has("dry-run");
const origins = typeof args.get("origins") === "string"
  ? args.get("origins").split(",").map((origin) => origin.trim()).filter(Boolean)
  : ["*"];

if (typeof projectId !== "string" || !/^[a-z][a-z0-9-]{4,29}$/.test(projectId)) {
  throw new Error(
    "Usage: npm run storage:cors -- --project PROJECT_ID [--bucket BUCKET] [--origins URL,...] [--dry-run | --confirm PROJECT_ID]",
  );
}
if (!dryRun && confirmation !== projectId) {
  throw new Error(`Refusing to write. Rerun with --confirm ${projectId}.`);
}

const cors = [{
  origin: origins,
  method: ["GET", "HEAD", "PUT", "POST", "DELETE"],
  responseHeader: [
    "Authorization",
    "Content-Type",
    "Cache-Control",
    "ETag",
    "Content-Length",
    "x-goog-resumable",
  ],
  maxAgeSeconds: 3600,
}];

if (dryRun) {
  console.log(JSON.stringify({ projectId, bucket: requestedBucket ?? "default", cors }, null, 2));
  process.exit(0);
}

const refreshToken = configstore.get("tokens.refresh_token");
const access = await firebaseAuth.getAccessToken(refreshToken, []);
const accessToken = access?.access_token;
if (!accessToken) throw new Error("Run `firebase login` before configuring Storage CORS.");

async function jsonRequest(url, { method = "GET", body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? `${method} ${url} failed (${response.status})`);
  }
  return payload;
}

function normalizeBucketName(value) {
  if (typeof value !== "string" || value.length === 0) return null;
  return value.replace(/^gs:\/\//, "").split("/").at(-1);
}

let bucket = normalizeBucketName(requestedBucket);
if (!bucket) {
  const project = await jsonRequest(
    `https://firebase.googleapis.com/v1beta1/projects/${projectId}`,
  );
  bucket = normalizeBucketName(project.resources?.storageBucket);
}
if (!bucket) {
  const storage = await jsonRequest(
    `https://firebasestorage.googleapis.com/v1alpha/projects/${projectId}/defaultBucket`,
  );
  bucket = normalizeBucketName(storage.bucket?.name);
}
if (!bucket) {
  throw new Error("No default Storage bucket found. Pass --bucket BUCKET_NAME.");
}

const encodedBucket = encodeURIComponent(bucket);
const result = await jsonRequest(
  `https://storage.googleapis.com/storage/v1/b/${encodedBucket}?updateMask=cors&fields=name,cors`,
  { method: "PATCH", body: { cors } },
);
console.log(`Storage CORS configured for gs://${bucket} with ${result.cors?.length ?? 0} rule.`);
