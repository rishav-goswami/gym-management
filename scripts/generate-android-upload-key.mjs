#!/usr/bin/env node

import { randomBytes } from "node:crypto";
import {
  chmodSync,
  existsSync,
  mkdirSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const propertiesPath = join(
  repositoryRoot,
  "apps",
  "gym_app",
  "android",
  "key.properties",
);
const privateDirectory = join(homedir(), ".gym-management", "android-signing");
const keystorePath = join(privateDirectory, "gym-management-upload-keystore.jks");
const certificatePath = join(privateDirectory, "upload-certificate.pem");
const alias = "upload";

const keytoolCandidates = [
  process.env.JAVA_HOME
    ? join(process.env.JAVA_HOME, "bin", "keytool")
    : undefined,
  "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin/keytool",
  "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin/keytool",
  "keytool",
].filter(Boolean);

const keytool = keytoolCandidates.find((candidate) => {
  if (candidate === "keytool") return true;
  return existsSync(candidate);
});

if (!keytool) {
  console.error("Java keytool was not found. Install Java 21 before generating the upload key.");
  process.exit(69);
}

if (existsSync(keystorePath) || existsSync(propertiesPath)) {
  console.error("Android signing material already exists; refusing to overwrite it.");
  console.error(`Keystore: ${keystorePath}`);
  console.error(`Properties: ${propertiesPath}`);
  process.exit(73);
}

mkdirSync(privateDirectory, { recursive: true, mode: 0o700 });
chmodSync(privateDirectory, 0o700);

const password = randomBytes(36).toString("base64url");
const distinguishedName = [
  "CN=Gym Management Android Upload",
  "OU=Mobile",
  "O=Gym Management",
  "L=Jaipur",
  "ST=Rajasthan",
  "C=IN",
].join(", ");

const generate = spawnSync(
  keytool,
  [
    "-genkeypair",
    "-noprompt",
    "-storetype",
    "PKCS12",
    "-keystore",
    keystorePath,
    "-storepass",
    password,
    "-keypass",
    password,
    "-alias",
    alias,
    "-keyalg",
    "RSA",
    "-keysize",
    "2048",
    "-validity",
    "10000",
    "-dname",
    distinguishedName,
  ],
  { encoding: "utf8" },
);

if (generate.status !== 0) {
  console.error(generate.stderr || generate.stdout || "keytool failed");
  process.exit(generate.status ?? 1);
}

chmodSync(keystorePath, 0o600);

const properties = [
  "# Generated locally. Never commit this file or the upload keystore.",
  `storePassword=${password}`,
  `keyPassword=${password}`,
  `keyAlias=${alias}`,
  `storeFile=${keystorePath}`,
  "",
].join("\n");
writeFileSync(propertiesPath, properties, { encoding: "utf8", mode: 0o600 });
chmodSync(propertiesPath, 0o600);

const exportCertificate = spawnSync(
  keytool,
  [
    "-exportcert",
    "-rfc",
    "-alias",
    alias,
    "-keystore",
    keystorePath,
    "-storepass",
    password,
    "-file",
    certificatePath,
  ],
  { encoding: "utf8" },
);

if (exportCertificate.status !== 0) {
  console.error(exportCertificate.stderr || exportCertificate.stdout || "Unable to export public certificate");
  process.exit(exportCertificate.status ?? 1);
}

chmodSync(certificatePath, 0o600);

const inspect = spawnSync(
  keytool,
  [
    "-list",
    "-v",
    "-alias",
    alias,
    "-keystore",
    keystorePath,
    "-storepass",
    password,
  ],
  { encoding: "utf8" },
);

if (inspect.status !== 0) {
  console.error(inspect.stderr || inspect.stdout || "Unable to inspect generated certificate");
  process.exit(inspect.status ?? 1);
}

const sha1 = inspect.stdout.match(/SHA1:\s*([A-F0-9:]+)/)?.[1];
const sha256 = inspect.stdout.match(/SHA256:\s*([A-F0-9:]+)/)?.[1];

console.log("Android upload signing material generated successfully.");
console.log(`Keystore: ${keystorePath}`);
console.log(`Public certificate: ${certificatePath}`);
console.log(`Local Gradle properties: ${propertiesPath}`);
if (sha1) console.log(`SHA-1: ${sha1}`);
if (sha256) console.log(`SHA-256: ${sha256}`);
console.log("The password was not printed. Copy it from key.properties into your password manager.");
console.log("Back up the keystore and password separately before publishing to Google Play.");
