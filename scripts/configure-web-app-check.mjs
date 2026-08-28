import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { configstore } = require("firebase-tools/lib/configstore");
const firebaseAuth = require("firebase-tools/lib/auth");

const projectId = process.argv[2];
const configurations = [
  {
    label: "customer",
    appId: process.argv[3],
    domains: ["createmix-gym-app.web.app", "createmix-gym-app.firebaseapp.com"]
  },
  {
    label: "platform-console",
    appId: process.argv[4],
    domains: ["createmix-gym-admin.web.app", "createmix-gym-admin.firebaseapp.com"]
  }
];

if (!projectId || configurations.some(({ appId }) => !appId)) {
  throw new Error(
    "Usage: node scripts/configure-web-app-check.mjs PROJECT_ID CUSTOMER_WEB_APP_ID CONSOLE_WEB_APP_ID"
  );
}
if (!/^[a-z][a-z0-9-]{4,29}$/.test(projectId)) throw new Error("Invalid project ID.");
for (const { appId } of configurations) {
  if (!/^1:\d+:web:[a-f0-9]+$/.test(appId)) throw new Error(`Invalid Firebase web app ID: ${appId}`);
}

const refreshToken = configstore.get("tokens.refresh_token");
const access = await firebaseAuth.getAccessToken(refreshToken, []);
const accessToken = access?.access_token;
if (!accessToken) throw new Error("Run `firebase login` before configuring App Check.");

async function request(url, { method = "GET", body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json"
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) })
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload?.error?.message ?? `${method} ${url} failed (${response.status})`);
  }
  return payload;
}

for (const service of [
  "recaptchaenterprise.googleapis.com",
  "firebaseappcheck.googleapis.com"
]) {
  await request(
    `https://serviceusage.googleapis.com/v1/projects/${projectId}/services/${service}:enable`,
    { method: "POST", body: {} }
  );
}

const projectNumber = configurations[0].appId.split(":")[1];
let existingKeys = [];
for (let attempt = 0; attempt < 12; attempt++) {
  try {
    const response = await request(
      `https://recaptchaenterprise.googleapis.com/v1/projects/${projectId}/keys?pageSize=100`
    );
    existingKeys = response.keys ?? [];
    break;
  } catch (error) {
    if (attempt === 11) throw error;
    await new Promise((resolve) => setTimeout(resolve, 2500));
  }
}

const results = {};
for (const configuration of configurations) {
  const displayName = `Gym Management ${configuration.label} web App Check`;
  let key = existingKeys.find((candidate) => candidate.displayName === displayName);
  if (!key) {
    key = await request(
      `https://recaptchaenterprise.googleapis.com/v1/projects/${projectId}/keys`,
      {
        method: "POST",
        body: {
          displayName,
          webSettings: {
            allowedDomains: configuration.domains,
            allowAllDomains: false,
            allowAmpTraffic: false,
            integrationType: "SCORE"
          }
        }
      }
    );
  }

  const siteKey = key.name?.split("/").at(-1);
  if (!siteKey) throw new Error(`No site key returned for ${configuration.label}.`);
  const configName = `projects/${projectNumber}/apps/${configuration.appId}/recaptchaEnterpriseConfig`;
  await request(
    `https://firebaseappcheck.googleapis.com/v1/${configName}?updateMask=siteKey,tokenTtl`,
    {
      method: "PATCH",
      body: { name: configName, siteKey, tokenTtl: "3600s" }
    }
  );
  results[configuration.label] = siteKey;
}

console.log(JSON.stringify(results, null, 2));
