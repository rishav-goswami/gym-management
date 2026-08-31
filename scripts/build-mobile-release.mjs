#!/usr/bin/env node

import { mkdirSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const appDirectory = join(repositoryRoot, "apps", "gym_app");
const target = process.argv[2];
const forwardedArguments = process.argv.slice(3);

if (!new Set(["android", "ios"]).has(target)) {
  console.error("Usage: node scripts/build-mobile-release.mjs <android|ios> [Flutter build options]");
  process.exit(64);
}

const pubspec = readFileSync(join(appDirectory, "pubspec.yaml"), "utf8");
const versionMatch = pubspec.match(/^version:\s*([^+\s]+)\+(\d+)\s*$/m);

if (!versionMatch) {
  console.error("Unable to read version: <build> from apps/gym_app/pubspec.yaml");
  process.exit(65);
}

const optionValue = (name, fallback) => {
  const inline = forwardedArguments.find((argument) => argument.startsWith(`${name}=`));
  if (inline) return inline.slice(name.length + 1);

  const index = forwardedArguments.indexOf(name);
  return index >= 0 && forwardedArguments[index + 1]
    ? forwardedArguments[index + 1]
    : fallback;
};

const buildName = optionValue("--build-name", versionMatch[1]);
const buildNumber = optionValue("--build-number", versionMatch[2]);
const releaseId = `${buildName}+${buildNumber}`.replace(/[^A-Za-z0-9._+-]/g, "-");
const symbolsDirectory = join(repositoryRoot, ".release-symbols", target, releaseId);
const obfuscationMap = join(symbolsDirectory, "obfuscation-map.json");
mkdirSync(symbolsDirectory, { recursive: true });

const buildTarget = target === "android" ? "appbundle" : "ipa";
const argumentsForFlutter = [
  "flutter",
  "build",
  buildTarget,
  "--release",
  "--obfuscate",
  `--split-debug-info=${symbolsDirectory}`,
  `--extra-gen-snapshot-options=--save-obfuscation-map=${obfuscationMap}`,
  "--dart-define=APP_FLAVOR=production",
  ...forwardedArguments,
];

console.log(`Building ${target} release ${releaseId}.`);
console.log(`Private symbol files: ${symbolsDirectory}`);

const result = spawnSync("fvm", argumentsForFlutter, {
  cwd: appDirectory,
  stdio: "inherit",
});

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

if (result.status !== 0) {
  console.error("Build failed. Keep any generated symbols with the matching build while troubleshooting.");
  process.exit(result.status ?? 1);
}

console.log("Build complete. Back up the matching private symbol directory; do not commit it.");
