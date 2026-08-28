import { createRequire } from "node:module";
import { readFileSync } from "node:fs";

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
if (typeof projectId !== "string" || !/^[a-z][a-z0-9-]{4,29}$/.test(projectId)) {
  throw new Error(
    "Usage: npm run catalog:sync -- --project PROJECT_ID [--bucket BUCKET] [--dry-run | --confirm PROJECT_ID]",
  );
}
if (!dryRun && confirmation !== projectId) {
  throw new Error(`Refusing to upload. Rerun with --confirm ${projectId}.`);
}

const manifest = JSON.parse(readFileSync("firebase/data/exercise-media.v1.json", "utf8"));
if (dryRun) {
  console.log(
    `Would sync ${manifest.images.length} ${manifest.catalogVersion} images to ${projectId}.`,
  );
  process.exit(0);
}

const refreshToken = configstore.get("tokens.refresh_token");
const access = await firebaseAuth.getAccessToken(refreshToken, []);
const accessToken = access?.access_token;
if (!accessToken) throw new Error("Run `firebase login` before syncing the catalog.");

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

let bucket = typeof requestedBucket === "string" ? requestedBucket.replace(/^gs:\/\//, "") : null;
if (!bucket) {
  const project = await jsonRequest(
    `https://firebase.googleapis.com/v1beta1/projects/${projectId}`,
  );
  bucket = project.resources?.storageBucket;
}
if (!bucket) {
  throw new Error(
    "No default Firebase Storage bucket found. Create Storage first or pass --bucket BUCKET_NAME.",
  );
}

let uploaded = 0;
let existing = 0;
for (const path of manifest.images) {
  const destination = `${manifest.destinationPrefix}/${path}`;
  const objectUrl = `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(bucket)}/o/${encodeURIComponent(destination)}`;
  const check = await fetch(objectUrl, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (check.ok) {
    existing++;
    continue;
  }
  if (check.status !== 404) {
    throw new Error(`Unable to check gs://${bucket}/${destination} (${check.status}).`);
  }
  const source = await fetch(`${manifest.sourceRoot}/${path}`);
  if (!source.ok) throw new Error(`Unable to download ${path} (${source.status}).`);
  const upload = await fetch(
    `https://storage.googleapis.com/upload/storage/v1/b/${encodeURIComponent(bucket)}/o?uploadType=media&name=${encodeURIComponent(destination)}`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "image/jpeg",
      },
      body: await source.arrayBuffer(),
    },
  );
  if (!upload.ok) throw new Error(`Unable to upload ${destination} (${upload.status}).`);
  await jsonRequest(`${objectUrl}?updateMask=cacheControl,metadata`, {
    method: "PATCH",
    body: {
      cacheControl: "public,max-age=31536000,immutable",
      metadata: {
        catalogVersion: manifest.catalogVersion,
        sourceCommit: manifest.sourceCommit,
        sourceLicense: manifest.sourceLicense,
      },
    },
  });
  uploaded++;
  console.log(`uploaded ${uploaded}/${manifest.images.length}: ${path}`);
}

const now = new Date().toISOString();
await jsonRequest(
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/platform_config/exerciseCatalog`,
  {
    method: "PATCH",
    body: {
      fields: {
        catalogVersion: { stringValue: manifest.catalogVersion },
        sourceCommit: { stringValue: manifest.sourceCommit },
        sourceLicense: { stringValue: manifest.sourceLicense },
        storageBucket: { stringValue: bucket },
        mediaPrefix: { stringValue: manifest.destinationPrefix },
        imageCount: { integerValue: String(manifest.images.length) },
        updatedAt: { timestampValue: now },
      },
    },
  },
);
console.log(`Catalog sync complete for ${projectId}: ${uploaded} uploaded, ${existing} already present.`);
