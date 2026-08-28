import { execFileSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";
import { basename } from "node:path";

const stagedOnly = process.argv.includes("--staged");
const gitArgs = stagedOnly
  ? ["diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"]
  : ["ls-files", "-z"];
const files = execFileSync("git", gitArgs, { encoding: "utf8" })
  .split("\0")
  .filter(Boolean);

const firebaseClientConfigPaths = new Set([
  "apps/gym_app/lib/firebase_options.dart",
  "apps/platform_console/lib/firebase_options.dart",
  "apps/gym_app/android/app/google-services.json",
  "apps/gym_app/ios/Runner/GoogleService-Info.plist",
  "apps/gym_app/macos/Runner/GoogleService-Info.plist"
]);

const findings = [];
const rules = [
  ["private key", new RegExp("-----BEGIN (?:RSA |EC |OPENSSH )?" + "PRIVATE KEY-----")],
  ["service-account credential", new RegExp('"type"\\s*:\\s*"service_' + 'account"', "i")],
  ["private credential field", new RegExp('"(?:private_' + 'key|client_' + 'secret|refresh_' + 'token)"\\s*:\\s*"[^"\\n]{8,}"', "i")],
  ["GitHub token", new RegExp("(?:ghp_" + "[A-Za-z0-9]{30,}|github_pat_" + "[A-Za-z0-9_]{30,})")],
  ["AWS access key", new RegExp("AKIA" + "[A-Z0-9]{16}")],
  ["live payment key", new RegExp("(?:sk_live_|rk_live_)" + "[A-Za-z0-9]{16,}")],
  ["Google API key", new RegExp("AIza" + "[A-Za-z0-9_-]{30,}")]
];

for (const file of files) {
  if (file === "scripts/check-secrets.mjs") continue;
  if (/^\.env(?:\.|$)/.test(basename(file)) && !file.endsWith(".example")) {
    findings.push(`${file}: tracked environment file`);
    continue;
  }
  let content;
  try {
    if (stagedOnly) {
      const buffer = execFileSync("git", ["show", `:${file}`], { maxBuffer: 2_000_001 });
      if (buffer.length > 2_000_000 || buffer.includes(0)) continue;
      content = buffer.toString("utf8");
    } else {
      const stats = statSync(file);
      if (!stats.isFile() || stats.size > 2_000_000) continue;
      const buffer = readFileSync(file);
      if (buffer.includes(0)) continue;
      content = buffer.toString("utf8");
    }
  } catch {
    continue;
  }
  for (const [label, pattern] of rules) {
    if (label === "Google API key" && firebaseClientConfigPaths.has(file)) continue;
    if (pattern.test(content)) findings.push(`${file}: possible ${label}`);
  }
}

if (findings.length > 0) {
  console.error("Potential secrets detected:\n" + findings.map((item) => `- ${item}`).join("\n"));
  console.error("Commit blocked. Remove the credential or document a precise scanner exception.");
  process.exit(1);
}

console.log(`Secret check passed for ${files.length} ${stagedOnly ? "staged" : "tracked"} files.`);
