import { randomBytes } from "node:crypto";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { configstore } = require("firebase-tools/lib/configstore");
const firebaseAuth = require("firebase-tools/lib/auth");

const projectId = process.argv[2];
const webAppId = process.argv[3];
const adminEmail = process.argv[4];
if (!projectId || !webAppId || !adminEmail) {
  throw new Error("Usage: node scripts/bootstrap-cloud.mjs PROJECT_ID WEB_APP_ID ADMIN_EMAIL");
}
if (!/^[a-z][a-z0-9-]{4,29}$/.test(projectId)) throw new Error("Invalid project ID.");
if (!/^1:\d+:web:[a-f0-9]+$/.test(webAppId)) throw new Error("Invalid Firebase web app ID.");
if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(adminEmail)) throw new Error("Invalid admin email.");

const refreshToken = configstore.get("tokens.refresh_token");
const access = await firebaseAuth.getAccessToken(refreshToken, []);
const accessToken = access?.access_token;
if (!accessToken) throw new Error("Run `firebase login` before bootstrapping.");

async function request(url, { method = "GET", body, oauth = true } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      "content-type": "application/json",
      ...(oauth ? { authorization: `Bearer ${accessToken}` } : {})
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) })
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload?.error?.message ?? `${method} ${url} failed (${response.status})`);
    error.code = payload?.error?.status ?? payload?.error?.message;
    throw error;
  }
  return payload;
}

for (const service of [
  "identitytoolkit.googleapis.com",
  "compute.googleapis.com"
]) {
  await request(
    `https://serviceusage.googleapis.com/v1/projects/${projectId}/services/${service}:enable`,
    { method: "POST", body: {} }
  );
}

let authConfigured = false;
for (let attempt = 0; attempt < 8 && !authConfigured; attempt++) {
  try {
    await request(
      `https://identitytoolkit.googleapis.com/admin/v2/projects/${projectId}/config?updateMask=signIn.email.enabled,signIn.email.passwordRequired`,
      {
        method: "PATCH",
        body: { signIn: { email: { enabled: true, passwordRequired: true } } }
      }
    );
    authConfigured = true;
  } catch (error) {
    if (String(error.message).includes("CONFIGURATION_NOT_FOUND")) {
      await request(
        `https://identitytoolkit.googleapis.com/v2/projects/${projectId}/identityPlatform:initializeAuth`,
        { method: "POST", body: {} }
      );
    }
    if (attempt === 7) throw error;
    await new Promise((resolve) => setTimeout(resolve, 2500));
  }
}

const appConfig = await request(
  `https://firebase.googleapis.com/v1beta1/projects/${projectId}/webApps/${encodeURIComponent(webAppId)}/config`
);
const apiKey = appConfig.apiKey;
if (!apiKey) throw new Error("Firebase web app configuration did not return an API key.");

let uid;
try {
  const created = await request(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      oauth: false,
      body: {
        email: adminEmail,
        password: randomBytes(32).toString("base64url"),
        returnSecureToken: false
      }
    }
  );
  uid = created.localId;
} catch (error) {
  if (!String(error.message).includes("EMAIL_EXISTS")) throw error;
  const lookup = await request(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`,
    { method: "POST", body: { email: [adminEmail] } }
  );
  uid = lookup.users?.[0]?.localId;
}
if (!uid) throw new Error("Unable to resolve platform administrator UID.");

await request(
  `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`,
  {
    method: "POST",
    body: {
      localId: uid,
      email: adminEmail,
      emailVerified: true,
      disableUser: false,
      customAttributes: JSON.stringify({ platformAdmin: true })
    }
  }
);
await request(
  `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey)}`,
  {
    method: "POST",
    oauth: false,
    body: { requestType: "PASSWORD_RESET", email: adminEmail }
  }
);

const now = new Date().toISOString();
const features = {
  classes: true,
  chat: true,
  attendanceQr: true,
  dietPlans: true,
  progressPhotos: false
};
const plans = {
  trial: {
    planId: "trial",
    name: "Free trial",
    description: "Explore the gym core suite",
    status: "active",
    isPublic: true,
    isTrial: true,
    trialDays: 14,
    currency: "INR",
    priceMinor: 0,
    billingPeriod: "trial",
    version: 1,
    limits: { activeMembers: 5, activeTrainers: 1, activeStaff: 1, scheduledClasses: 3 },
    features
  },
  starter: {
    planId: "starter",
    name: "Starter",
    description: "For growing neighbourhood gyms",
    status: "active",
    isPublic: true,
    isTrial: false,
    trialDays: 14,
    currency: "INR",
    priceMinor: 99900,
    billingPeriod: "monthly",
    version: 1,
    limits: { activeMembers: 100, activeTrainers: 5, activeStaff: 5, scheduledClasses: 100 },
    features: { ...features, progressPhotos: true }
  }
};

function firestoreValue(value) {
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (value && typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, firestoreValue(item)]))
      }
    };
  }
  throw new Error(`Unsupported Firestore bootstrap value: ${value}`);
}

for (const [planId, plan] of Object.entries(plans)) {
  await request(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/saas_plans/${planId}`,
    {
      method: "PATCH",
      body: {
        fields: {
          ...Object.fromEntries(Object.entries(plan).map(([key, value]) => [key, firestoreValue(value)])),
          createdAt: { timestampValue: now },
          updatedAt: { timestampValue: now },
          updatedBy: { stringValue: uid }
        }
      }
    }
  );
}

console.log(`Bootstrapped ${projectId}: email Auth, platform admin ${adminEmail}, trial and starter plans.`);
