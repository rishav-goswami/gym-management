#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const failures = [];
const checks = [];

function check(condition, message) {
  (condition ? checks : failures).push(message);
}

function pngSize(path) {
  const buffer = readFileSync(resolve(root, path));
  check(buffer.toString("ascii", 1, 4) === "PNG", `${path} is a PNG`);
  return [buffer.readUInt32BE(16), buffer.readUInt32BE(20)];
}

const appId = "com.rishva.gymmanagement";
const publicBaseUrl = "https://createmix-gym-app.web.app";
const manifest = read("apps/gym_app/android/app/src/main/AndroidManifest.xml");
const seed = read("firebase/functions/src/seed.ts");
const privacy = read("apps/gym_app/web/privacy/index.html");
const terms = read("apps/gym_app/web/terms/index.html");
const deletion = read("apps/gym_app/web/delete-account/index.html");
const pubspec = read("apps/gym_app/pubspec.yaml");
const assetLinks = JSON.parse(read("apps/gym_app/web/.well-known/assetlinks.json"));

check(manifest.includes('android:allowBackup="false"'), "Android cloud backup is disabled");
check(manifest.includes('android:dataExtractionRules="@xml/data_extraction_rules"'), "Android transfer exclusions are configured");
for (const permission of [
  "com.google.android.gms.permission.AD_ID",
  "android.permission.ACCESS_ADSERVICES_AD_ID",
  "android.permission.ACCESS_ADSERVICES_ATTRIBUTION"
]) {
  check(
    manifest.includes(`android:name="${permission}"`) && manifest.includes('tools:node="remove"'),
    `${permission} is explicitly removed`
  );
}

check(assetLinks.length > 0, "Android App Links contains at least one statement");
const androidTarget = assetLinks.find((entry) => entry?.target?.package_name === appId)?.target;
check(Boolean(androidTarget), `Android App Links targets ${appId}`);
check(
  androidTarget?.sha256_cert_fingerprints?.some((value) =>
    /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/.test(value)
  ),
  "Android App Links contains a valid SHA-256 certificate fingerprint"
);

const playFingerprint = process.env.PLAY_APP_SIGNING_SHA256?.toUpperCase();
if (playFingerprint) {
  check(
    androidTarget?.sha256_cert_fingerprints?.includes(playFingerprint),
    "Android App Links contains PLAY_APP_SIGNING_SHA256"
  );
} else {
  checks.push("PLAY_APP_SIGNING_SHA256 not supplied; upload-key App Links only");
}

for (const [name, content] of [["privacy", privacy], ["terms", terms], ["deletion", deletion]]) {
  check(!content.includes("example.com"), `${name} page contains no placeholder domain`);
  check(content.includes("FitGy"), `${name} page identifies the app`);
  check(content.includes("mailto:"), `${name} page provides a contact path`);
}
check(privacy.includes("Fitness and wellness"), "Privacy policy discloses fitness data");
check(privacy.includes("Retention and deletion"), "Privacy policy discloses retention and deletion");
check(deletion.includes("within 30 days"), "Deletion page states the deletion timeline");
check(seed.includes(`${publicBaseUrl}/terms/`), "Firebase seed uses the production Terms URL");
check(seed.includes(`${publicBaseUrl}/privacy/`), "Firebase seed uses the production Privacy URL");

check(/^version:\s+\d+\.\d+\.\d+\+\d+$/m.test(pubspec), "Store version has versionName and versionCode");
for (const [path, expected] of [
  ["apps/gym_app/web/icons/Icon-512.png", 512],
  ["apps/gym_app/web/icons/Icon-192.png", 192],
  ["apps/gym_app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192]
]) {
  const [width, height] = pngSize(path);
  check(width === expected && height === expected, `${path} is ${expected}x${expected}`);
}

try {
  const ignored = execFileSync("git", ["check-ignore", "apps/gym_app/android/key.properties"], {
    cwd: root,
    encoding: "utf8"
  }).trim();
  check(Boolean(ignored), "Android signing properties are ignored by Git");
} catch {
  failures.push("Android signing properties are not ignored by Git");
}

if (process.argv.includes("--live")) {
  const endpoints = [
    [`${publicBaseUrl}/privacy/`, "Privacy Policy"],
    [`${publicBaseUrl}/terms/`, "Terms of Service"],
    [`${publicBaseUrl}/delete-account/`, "Delete your FitGy account"]
  ];
  for (const [url, marker] of endpoints) {
    const response = await fetch(url, { redirect: "follow" });
    const body = await response.text();
    check(response.ok && body.includes(marker), `${url} is deployed and contains ${marker}`);
  }
  const linksResponse = await fetch(`${publicBaseUrl}/.well-known/assetlinks.json`);
  const liveLinks = await linksResponse.json();
  check(Array.isArray(liveLinks) && liveLinks.length > 0, "Live Android App Links is non-empty");

  const brandingResponse = await fetch(
    "https://firestore.googleapis.com/v1/projects/createmix-in/databases/(default)/documents/platform_public/app_branding"
  );
  const branding = await brandingResponse.json();
  check(
    branding?.fields?.privacyUrl?.stringValue === `${publicBaseUrl}/privacy/`,
    "Live Firebase branding uses the production Privacy URL"
  );
  check(
    branding?.fields?.termsUrl?.stringValue === `${publicBaseUrl}/terms/`,
    "Live Firebase branding uses the production Terms URL"
  );
  check(branding?.fields?.name?.stringValue === "FitGy", "Live Firebase branding uses FitGy");
}

for (const message of checks) console.log(`PASS: ${message}`);
if (failures.length) {
  for (const message of failures) console.error(`FAIL: ${message}`);
  process.exit(1);
}
console.log(`Play release check passed (${checks.length} checks).`);
