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
const location = args.get("location");
const confirmation = args.get("confirm");
const dryRun = args.has("dry-run");

if (
  typeof projectId !== "string" ||
  !/^[a-z][a-z0-9-]{4,29}$/.test(projectId) ||
  typeof location !== "string" ||
  !/^[a-z0-9-]+$/.test(location)
) {
  throw new Error(
    "Usage: npm run storage:provision -- --project PROJECT_ID --location LOCATION " +
      "[--dry-run | --confirm PROJECT_ID]",
  );
}

if (dryRun) {
  console.log(`Would provision the default Storage bucket for ${projectId} in ${location}.`);
  process.exit(0);
}
if (confirmation !== projectId) {
  throw new Error(`Refusing to provision Storage. Rerun with --confirm ${projectId}.`);
}

const refreshToken = configstore.get("tokens.refresh_token");
const access = await firebaseAuth.getAccessToken(refreshToken, []);
const accessToken = access?.access_token;
if (!accessToken) throw new Error("Run `firebase login` before provisioning Storage.");

async function jsonRequest(url, { method = "GET", body, allowNotFound = false } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (allowNotFound && response.status === 404) return null;
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? `${method} ${url} failed (${response.status})`);
  }
  return payload;
}

const endpoint = `https://firebasestorage.googleapis.com/v1alpha/projects/${projectId}/defaultBucket`;
const existing = await jsonRequest(endpoint, { allowNotFound: true });
if (existing) {
  if (existing.location && existing.location !== location) {
    throw new Error(
      `Default bucket already exists in immutable location ${existing.location}, not ${location}.`,
    );
  }
  console.log(`Default Storage bucket already exists: ${existing.bucket?.name ?? existing.name}.`);
  process.exit(0);
}

const created = await jsonRequest(endpoint, {
  method: "POST",
  body: { location },
});
console.log(
  `Provisioned ${created.bucket?.name ?? `${projectId}.firebasestorage.app`} in ${created.location}.`,
);
