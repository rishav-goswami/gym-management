import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten
} from "firebase-functions/v2/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { z } from "zod";
import { writeAudit } from "./audit";
import { requireAuth, requireGymPermission, requirePlatformAdmin } from "./authz";
import { REGION, ROLE_PERMISSIONS } from "./config";
import {
  attendanceDocumentId,
  assertWithinLimit,
  bookingDocumentId,
  canSelfServiceReactivateMembership,
  expiryReminderWindow,
  hashToken,
  membershipDocumentId,
  normalizeEmail,
  normalizePhone,
  renewalWindow,
  secureToken,
  usageFieldForRole,
  type UsageField
} from "./domain";

initializeApp();
const db = getFirestore();
const ENFORCE_APP_CHECK = process.env.FUNCTIONS_EMULATOR !== "true";

type IdentitySnapshot = {
  displayName: string | null;
  email: string | null;
  phone: string | null;
};

async function userIdentity(
  uid: string,
  token: Record<string, unknown> = {}
): Promise<IdentitySnapshot> {
  const [profile, authUser] = await Promise.all([
    db.doc(`users/${uid}`).get(),
    getAuth().getUser(uid).catch(() => null)
  ]);
  const profileData = profile.data() ?? {};
  const rawEmail = authUser?.email ?? token.email ?? profileData.email;
  const rawPhone = authUser?.phoneNumber ?? token.phone_number ?? profileData.phone;
  const rawName = authUser?.displayName ?? token.name ?? profileData.displayName ?? profileData.name;
  return {
    displayName: typeof rawName === "string" && rawName.trim() ? rawName.trim() : null,
    email: typeof rawEmail === "string" && rawEmail.trim() ? normalizeEmail(rawEmail) : null,
    phone: typeof rawPhone === "string" && rawPhone.trim() ? normalizePhone(rawPhone) : null
  };
}

const gymSchema = z.object({
  name: z.string().trim().min(2).max(100),
  ownerUid: z.string().min(1).optional(),
  ownerEmail: z.string().email().optional(),
  currency: z.string().length(3).default("INR"),
  timezone: z.string().default("Asia/Kolkata"),
  locale: z.string().default("en-IN"),
  phone: z.string().min(8).max(20).optional(),
  city: z.string().trim().max(80).optional(),
  primaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).default("#2563EB"),
  secondaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).default("#0F172A"),
  accentColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).default("#F97316"),
  tagline: z.string().trim().max(120).default("Stronger every day")
}).refine((input) => input.ownerUid || input.ownerEmail, {
  message: "Owner email or UID is required."
});

const gymConfigurationSchema = z.object({
  gymId: z.string().min(1),
  name: z.string().trim().min(2).max(100).optional(),
  currency: z.string().length(3).optional(),
  timezone: z.string().min(1).max(80).optional(),
  locale: z.string().min(2).max(20).optional(),
  phone: z.string().min(8).max(20).nullable().optional(),
  city: z.string().trim().max(80).nullable().optional(),
  website: z.string().url().nullable().optional(),
  primaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  secondaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  accentColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  tagline: z.string().trim().max(120).optional(),
  logoUrl: z.string().url().nullable().optional()
});

const platformGymConfigurationSchema = gymConfigurationSchema.extend({
  features: z.object({
    classes: z.boolean(),
    chat: z.boolean(),
    attendanceQr: z.boolean(),
    dietPlans: z.boolean(),
    progressPhotos: z.boolean()
  }).optional()
});

function configurationUpdate(input: z.infer<typeof platformGymConfigurationSchema>) {
  const branding: Record<string, string | null> = {};
  if (input.primaryColor !== undefined) branding.primaryColor = input.primaryColor;
  if (input.secondaryColor !== undefined) branding.secondaryColor = input.secondaryColor;
  if (input.accentColor !== undefined) branding.accentColor = input.accentColor;
  if (input.tagline !== undefined) branding.tagline = input.tagline;
  if (input.logoUrl !== undefined) branding.logoUrl = input.logoUrl;
  return {
    ...(input.name !== undefined ? { name: input.name } : {}),
    ...(input.currency !== undefined ? { currency: input.currency.toUpperCase() } : {}),
    ...(input.timezone !== undefined ? { timezone: input.timezone } : {}),
    ...(input.locale !== undefined ? { locale: input.locale } : {}),
    ...(input.phone !== undefined ? { phone: input.phone ? normalizePhone(input.phone) : null } : {}),
    ...(input.city !== undefined ? { city: input.city } : {}),
    ...(input.website !== undefined ? { website: input.website } : {}),
    ...(Object.keys(branding).length ? { branding } : {}),
    ...(input.features !== undefined ? { features: input.features } : {}),
    updatedAt: FieldValue.serverTimestamp()
  };
}

const planLimitsSchema = z.object({
  activeMembers: z.number().int().min(0).max(100000),
  activeTrainers: z.number().int().min(0).max(10000),
  activeStaff: z.number().int().min(0).max(10000),
  scheduledClasses: z.number().int().min(0).max(100000)
});

const planFeaturesSchema = z.object({
  classes: z.boolean(),
  chat: z.boolean(),
  attendanceQr: z.boolean(),
  dietPlans: z.boolean(),
  progressPhotos: z.boolean()
});

const featureIdSchema = z.enum([
  "dashboard",
  "training",
  "progress",
  "billing",
  "attendance",
  "classes",
  "chat",
  "members",
  "payments",
  "staff",
  "announcements",
  "branding",
  "profile",
  "registration",
  "onboarding",
  "firstRoutine",
  "firstWorkout",
  "firstProgress",
  "invitationAcceptance",
  "gymCreation"
]);

const saasPlanSchema = z.object({
  planId: z.string().regex(/^[a-z0-9-]{2,40}$/),
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(300).default(""),
  status: z.enum(["active", "inactive"]).default("active"),
  isPublic: z.boolean().default(true),
  isTrial: z.boolean().default(false),
  trialDays: z.number().int().min(1).max(90).default(14),
  currency: z.string().length(3).default("INR"),
  priceMinor: z.number().int().nonnegative().default(0),
  billingPeriod: z.enum(["trial", "monthly", "annual"]).default("monthly"),
  limits: planLimitsSchema,
  features: planFeaturesSchema
});

function planSnapshot(planId: string, plan: Record<string, unknown>) {
  return {
    planId,
    planVersion: Number(plan.version ?? 1),
    planName: String(plan.name),
    limits: plan.limits as Record<string, number>,
    features: plan.features as Record<string, boolean>,
    currency: String(plan.currency ?? "INR"),
    priceMinor: Number(plan.priceMinor ?? 0),
    billingPeriod: String(plan.billingPeriod ?? "monthly")
  };
}

function quotaError(error: unknown): never {
  const message = error instanceof Error ? error.message : String(error);
  if (message.startsWith("LIMIT_EXCEEDED:")) {
    const [, field, current, limit] = message.split(":");
    throw new HttpsError(
      "resource-exhausted",
      `Your plan limit for ${field} is ${limit} (currently ${current}). Upgrade to continue.`,
      { field, current: Number(current), limit: Number(limit) }
    );
  }
  throw error;
}

export const upsertSaasPlan = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = saasPlanSchema.parse(request.data);
    const ref = db.doc(`saas_plans/${input.planId}`);
    let version = 1;
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      version = Number(current.get("version") ?? 0) + 1;
      tx.set(ref, {
        ...input,
        currency: input.currency.toUpperCase(),
        version,
        createdAt: current.exists ? current.get("createdAt") : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: request.auth!.uid
      });
    });
    return { planId: input.planId, version };
  }
);

const startTrialSchema = z.object({
  name: z.string().trim().min(2).max(100),
  phone: z.string().min(8).max(20).optional(),
  city: z.string().trim().max(80).optional(),
  currency: z.string().length(3).default("INR"),
  timezone: z.string().min(1).max(80).default("Asia/Kolkata"),
  locale: z.string().min(2).max(20).default("en-IN")
});

export const startGymTrial = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const input = startTrialSchema.parse(request.data);
    const emailVerified = request.auth.token.email_verified === true;
    if (!emailVerified && !request.auth.token.phone_number) {
      throw new HttpsError("failed-precondition", "Verify your email or phone before starting a trial.");
    }
    const planRef = db.doc("saas_plans/trial");
    const claimRef = db.doc(`trial_claims/${request.auth.uid}`);
    const gymRef = db.collection("gyms").doc();
    const membershipRef = db.doc(`gym_memberships/${gymRef.id}_${request.auth.uid}`);
    const endsAtMillis = Date.now();

    await db.runTransaction(async (tx) => {
      const [planDoc, claimDoc] = await Promise.all([tx.get(planRef), tx.get(claimRef)]);
      if (claimDoc.exists) {
        throw new HttpsError("already-exists", "This account has already used its free gym trial.");
      }
      if (!planDoc.exists || planDoc.get("status") !== "active" || planDoc.get("isTrial") !== true) {
        throw new HttpsError("failed-precondition", "Self-service trials are currently unavailable.");
      }
      const plan = planSnapshot(planDoc.id, planDoc.data()!);
      const trialEndsAtMillis = endsAtMillis + Number(planDoc.get("trialDays")) * 86400000;
      const now = FieldValue.serverTimestamp();
      tx.create(claimRef, { uid: request.auth!.uid, gymId: gymRef.id, createdAt: now });
      tx.create(gymRef, {
        name: input.name,
        status: "trial",
        platformPlan: "trial",
        platformPlanEndsAt: Timestamp.fromMillis(trialEndsAtMillis),
        currency: input.currency.toUpperCase(),
        timezone: input.timezone,
        locale: input.locale,
        city: input.city ?? null,
        phone: input.phone ? normalizePhone(input.phone) : null,
        branding: {
          primaryColor: "#2563EB",
          secondaryColor: "#0F172A",
          accentColor: "#F97316",
          tagline: "Stronger every day"
        },
        features: plan.features,
        createdBy: request.auth!.uid,
        createdAt: now,
        updatedAt: now
      });
      tx.create(membershipRef, {
        gymId: gymRef.id, uid: request.auth!.uid, role: "owner", status: "active",
        permissions: ROLE_PERMISSIONS.owner, createdAt: now, updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/staff/${request.auth!.uid}`), {
        gymId: gymRef.id, uid: request.auth!.uid, role: "owner", status: "active",
        displayName: request.auth!.token.name ?? null,
        email: request.auth!.token.email ? normalizeEmail(String(request.auth!.token.email)) : null,
        phone: request.auth!.token.phone_number ?? input.phone ?? null,
        createdAt: now, updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/platform_subscription/current`), {
        ...plan, status: "trial", startsAt: now,
        endsAt: Timestamp.fromMillis(trialEndsAtMillis), createdAt: now, updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/entitlements/current`), {
        ...plan, status: "active", endsAt: Timestamp.fromMillis(trialEndsAtMillis), updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/usage/current`), {
        activeMembers: 0, activeTrainers: 0, activeStaff: 0, scheduledClasses: 0, updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/dashboard_metrics/current`), {
        activeMembers: 0, expiringSoon: 0, todayAttendance: 0,
        monthlyRevenueMinor: 0, updatedAt: now
      });
    });
    await db.doc(`users/${request.auth.uid}`).set({
      gymConnectionCount: FieldValue.increment(1),
      hasGymConnection: true,
      ownsGym: true,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    await writeAudit(db, gymRef.id, request.auth.uid, "gym.self_service_trial_started", {});
    await recordPlatformMilestone("gymCreation", "owner", "gym", gymRef.id);
    return { gymId: gymRef.id };
  }
);

export const provisionGym = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = gymSchema.parse(request.data);
    let ownerUid: string;
    try {
      const owner = input.ownerUid
        ? await getAuth().getUser(input.ownerUid)
        : await getAuth().getUserByEmail(normalizeEmail(input.ownerEmail!));
      ownerUid = owner.uid;
    } catch {
      throw new HttpsError(
        "not-found",
        "No Firebase identity matches this owner. Ask them to register first."
      );
    }
    const gymRef = db.collection("gyms").doc();
    const membershipRef = db.doc(
      `gym_memberships/${membershipDocumentId(gymRef.id, ownerUid)}`
    );
    const now = FieldValue.serverTimestamp();

    await db.runTransaction(async (tx) => {
      const planDoc = await tx.get(db.doc("saas_plans/trial"));
      if (!planDoc.exists || planDoc.get("status") !== "active") {
        throw new HttpsError("failed-precondition", "Configure the trial SaaS plan first.");
      }
      const plan = planSnapshot(planDoc.id, planDoc.data()!);
      const trialEndsAt = Timestamp.fromMillis(Date.now() + Number(planDoc.get("trialDays")) * 86400000);
      tx.create(gymRef, {
        name: input.name,
        status: "trial",
        platformPlan: "trial",
        platformPlanEndsAt: trialEndsAt,
        currency: input.currency,
        timezone: input.timezone,
        locale: input.locale,
        city: input.city ?? null,
        phone: input.phone ? normalizePhone(input.phone) : null,
        branding: {
          primaryColor: input.primaryColor,
          secondaryColor: input.secondaryColor,
          accentColor: input.accentColor,
          tagline: input.tagline
        },
        features: plan.features,
        createdBy: request.auth!.uid,
        createdAt: now,
        updatedAt: now
      });
      tx.create(membershipRef, {
        gymId: gymRef.id,
        uid: ownerUid,
        role: "owner",
        status: "active",
        permissions: ROLE_PERMISSIONS.owner,
        createdAt: now,
        updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/staff/${ownerUid}`), {
        gymId: gymRef.id,
        uid: ownerUid,
        role: "owner",
        status: "active",
        createdAt: now,
        updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/dashboard_metrics/current`), {
        activeMembers: 0,
        expiringSoon: 0,
        todayAttendance: 0,
        monthlyRevenueMinor: 0,
        updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/platform_subscription/current`), {
        ...plan, status: "trial", startsAt: now, endsAt: trialEndsAt,
        createdAt: now, updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/entitlements/current`), {
        ...plan, status: "active", endsAt: trialEndsAt, updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/usage/current`), {
        activeMembers: 0, activeTrainers: 0, activeStaff: 0, scheduledClasses: 0, updatedAt: now
      });
    });

    await writeAudit(db, gymRef.id, request.auth!.uid, "gym.provisioned", {
      gymId: gymRef.id,
      ownerUid
    });
    return { gymId: gymRef.id };
  }
);

const invitationSchema = z.object({
  gymId: z.string().min(1),
  role: z.enum(["owner", "manager", "receptionist", "trainer", "accountant", "member"]),
  email: z.string().email().optional(),
  phone: z.string().min(8).optional(),
  expiresInHours: z.number().int().min(1).max(168).default(72)
}).refine((value) => value.email || value.phone, "Email or phone is required.");

export const createInvitation = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = invitationSchema.parse(request.data);
    await requireGymPermission(request, input.gymId, input.role === "member" ? "members.write" : "staff.manage");
    const token = secureToken();
    const tokenHash = hashToken(token);
    await db.doc(`gyms/${input.gymId}/invitations/${tokenHash}`).set({
      gymId: input.gymId,
      role: input.role,
      email: input.email ? normalizeEmail(input.email) : null,
      phone: input.phone ? normalizePhone(input.phone) : null,
      status: "pending",
      createdBy: request.auth!.uid,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + input.expiresInHours * 3600000)
    });
    await writeAudit(db, input.gymId, request.auth!.uid, "invitation.created", {
      role: input.role,
      email: input.email ? normalizeEmail(input.email) : null
    });
    return { token, expiresInHours: input.expiresInHours };
  }
);

export const acceptInvitation = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const { gymId, token } = z.object({ gymId: z.string(), token: z.string().min(20) }).parse(request.data);
    const inviteRef = db.doc(`gyms/${gymId}/invitations/${hashToken(token)}`);
    const memberRef = db.doc(
      `gym_memberships/${membershipDocumentId(gymId, request.auth.uid)}`
    );
    const identity = await userIdentity(
      request.auth.uid,
      request.auth.token as Record<string, unknown>
    );
    const entitlementRef = db.doc(`gyms/${gymId}/entitlements/current`);
    const usageRef = db.doc(`gyms/${gymId}/usage/current`);
    let acceptedRole = "member";
    try {
      await db.runTransaction(async (tx) => {
      const [invite, entitlement, usage, existingMembership] = await Promise.all([
        tx.get(inviteRef), tx.get(entitlementRef), tx.get(usageRef), tx.get(memberRef)
      ]);
      if (!invite.exists || invite.get("status") !== "pending") {
        throw new HttpsError("not-found", "Invitation is invalid or already used.");
      }
      if (invite.get("expiresAt").toMillis() <= Date.now()) {
        throw new HttpsError("deadline-exceeded", "Invitation has expired.");
      }
      const tokenEmail = identity.email;
      const tokenPhone = identity.phone;
      if ((invite.get("email") && invite.get("email") !== tokenEmail) ||
          (invite.get("phone") && invite.get("phone") !== tokenPhone)) {
        throw new HttpsError("permission-denied", "Invitation does not match this account.");
      }
      const role = String(invite.get("role"));
      acceptedRole = role;
      if (existingMembership.exists && existingMembership.get("status") === "active") {
        throw new HttpsError("already-exists", "This account is already active in the gym.");
      }
      if (existingMembership.exists &&
          !canSelfServiceReactivateMembership(existingMembership.get("status"))) {
        throw new HttpsError(
          "failed-precondition",
          "This membership was disabled by gym staff and cannot be reactivated by invitation."
        );
      }
      if (existingMembership.exists && existingMembership.get("role") !== role) {
        throw new HttpsError(
          "failed-precondition",
          "A retained membership cannot be reactivated with a different role."
        );
      }
      const usageField = usageFieldForRole(role);
      if (usageField) {
        if (!entitlement.exists || !usage.exists) {
          throw new HttpsError("failed-precondition", "Gym plan entitlements are not configured.");
        }
        const next = assertWithinLimit(
          usageField,
          Number(usage.get(usageField) ?? 0),
          1,
          entitlement.get("limits") ?? {}
        );
        tx.update(usageRef, { [usageField]: next, updatedAt: FieldValue.serverTimestamp() });
      }
      tx.set(memberRef, {
        gymId,
        uid: request.auth!.uid,
        role,
        status: "active",
        permissions: ROLE_PERMISSIONS[role] ?? {},
        ...(existingMembership.exists
          ? { reactivatedAt: FieldValue.serverTimestamp() }
          : { createdAt: FieldValue.serverTimestamp() }),
        leftAt: null,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      const profileCollection = role === "member" ? "members" : "staff";
      tx.set(db.doc(`gyms/${gymId}/${profileCollection}/${request.auth!.uid}`), {
        gymId,
        uid: request.auth!.uid,
        role,
        status: "active",
        displayName: identity.displayName,
        email: tokenEmail,
        phone: tokenPhone,
        ...(existingMembership.exists
          ? { reactivatedAt: FieldValue.serverTimestamp() }
          : { createdAt: FieldValue.serverTimestamp() }),
        leftAt: null,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      if (role === "member") {
        tx.set(db.doc(`gyms/${gymId}/dashboard_metrics/current`), {
          activeMembers: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
      tx.update(inviteRef, {
        status: "accepted",
        acceptedBy: request.auth!.uid,
        acceptedAt: FieldValue.serverTimestamp()
      });
      tx.set(db.doc(`users/${request.auth!.uid}`), {
        displayName: identity.displayName,
        email: tokenEmail,
        phone: tokenPhone,
        gymConnectionCount: FieldValue.increment(1),
        hasGymConnection: true,
        ...(role === "owner" ? { ownsGym: true } : {}),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      });
    } catch (error) {
      quotaError(error);
    }
    await recordPlatformMilestone("invitationAcceptance", acceptedRole, "gym", gymId);
    return { gymId };
  }
);

export const hydrateMemberProfiles = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = z.object({ gymId: z.string().min(1) }).parse(request.data);
    await requireGymPermission(request, input.gymId, "members.read");
    const snapshot = await db.collection(`gyms/${input.gymId}/members`).limit(100).get();
    const incomplete = snapshot.docs.filter((document) => {
      const data = document.data();
      return !data.displayName || !data.email;
    });
    if (incomplete.length === 0) return { updated: 0 };

    const identities = await Promise.all(
      incomplete.map((document) => userIdentity(String(document.get("uid") ?? document.id)))
    );
    const batch = db.batch();
    let updated = 0;
    incomplete.forEach((document, index) => {
      const existing = document.data();
      const identity = identities[index];
      const update: Record<string, unknown> = {
        updatedAt: FieldValue.serverTimestamp()
      };
      if (!existing.displayName && identity.displayName) update.displayName = identity.displayName;
      if (!existing.email && identity.email) update.email = identity.email;
      if (!existing.phone && identity.phone) update.phone = identity.phone;
      if (Object.keys(update).length > 1) {
        batch.set(document.ref, update, { merge: true });
        updated += 1;
      }
    });
    if (updated > 0) await batch.commit();
    return { updated };
  }
);

export const updateGymStatus = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      gymId: z.string().min(1),
      status: z.enum(["trial", "active", "suspended"]),
      platformPlan: z.string().min(1).max(40).optional(),
      planEndsAtMillis: z.number().int().optional()
    }).parse(request.data);
    await db.doc(`gyms/${input.gymId}`).update({
      status: input.status,
      ...(input.platformPlan ? { platformPlan: input.platformPlan } : {}),
      ...(input.planEndsAtMillis ? { platformPlanEndsAt: Timestamp.fromMillis(input.planEndsAtMillis) } : {}),
      updatedAt: FieldValue.serverTimestamp()
    });
    await writeAudit(db, input.gymId, request.auth!.uid, "gym.status_updated", input);
    return { updated: true };
  }
);

export const requestPlatformUpgrade = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = z.object({
      gymId: z.string().min(1),
      planId: z.string().regex(/^[a-z0-9-]{2,40}$/),
      note: z.string().trim().max(500).optional()
    }).parse(request.data);
    const actor = await requireGymPermission(request, input.gymId, "dashboard.read");
    if (actor.role !== "owner") {
      throw new HttpsError("permission-denied", "Only the gym owner can request a plan change.");
    }
    const plan = await db.doc(`saas_plans/${input.planId}`).get();
    if (!plan.exists || plan.get("status") !== "active" || plan.get("isPublic") !== true || plan.get("isTrial") === true) {
      throw new HttpsError("failed-precondition", "Select an available paid plan.");
    }
    await db.doc(`platform_upgrade_requests/${input.gymId}`).set({
      gymId: input.gymId,
      gymName: actor.gym.name,
      ownerUid: request.auth!.uid,
      requestedPlanId: input.planId,
      requestedPlanName: plan.get("name"),
      note: input.note ?? "",
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });
    await writeAudit(db, input.gymId, request.auth!.uid, "platform.upgrade_requested", { planId: input.planId });
    return { requested: true };
  }
);

export const reviewPlatformUpgrade = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      gymId: z.string().min(1),
      decision: z.enum(["approved", "rejected"]),
      note: z.string().trim().max(500).optional()
    }).parse(request.data);
    const requestRef = db.doc(`platform_upgrade_requests/${input.gymId}`);
    await db.runTransaction(async (tx) => {
      const upgrade = await tx.get(requestRef);
      if (!upgrade.exists || upgrade.get("status") !== "pending") {
        throw new HttpsError("failed-precondition", "There is no pending request for this gym.");
      }
      const planId = String(upgrade.get("requestedPlanId"));
      const planDoc = await tx.get(db.doc(`saas_plans/${planId}`));
      if (!planDoc.exists || planDoc.get("status") !== "active") {
        throw new HttpsError("failed-precondition", "The requested plan is unavailable.");
      }
      const now = FieldValue.serverTimestamp();
      tx.update(requestRef, {
        status: input.decision, reviewNote: input.note ?? "",
        reviewedBy: request.auth!.uid, reviewedAt: now, updatedAt: now
      });
      if (input.decision === "approved") {
        const plan = planSnapshot(planDoc.id, planDoc.data()!);
        const periodDays = planDoc.get("billingPeriod") === "annual" ? 365 : 30;
        const endsAt = Timestamp.fromMillis(Date.now() + periodDays * 86400000);
        tx.update(db.doc(`gyms/${input.gymId}`), {
          status: "active", platformPlan: planId, platformPlanEndsAt: endsAt,
          features: plan.features, updatedAt: now
        });
        tx.set(db.doc(`gyms/${input.gymId}/platform_subscription/current`), {
          ...plan, status: "active", startsAt: now, endsAt, updatedAt: now
        }, { merge: true });
        tx.set(db.doc(`gyms/${input.gymId}/entitlements/current`), {
          ...plan, status: "active", endsAt, updatedAt: now
        });
      }
    });
    await writeAudit(db, input.gymId, request.auth!.uid, `platform.upgrade_${input.decision}`, {});
    return { reviewed: true };
  }
);

export const createClassSession = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = z.object({
      gymId: z.string().min(1),
      name: z.string().trim().min(2).max(100),
      capacity: z.number().int().min(1).max(500),
      startsAtMillis: z.number().int().min(Date.now() - 300000),
      trainerUid: z.string().optional()
    }).parse(request.data);
    await requireGymPermission(request, input.gymId, "classes.manage");
    const sessionRef = db.collection(`gyms/${input.gymId}/class_sessions`).doc();
    const usageRef = db.doc(`gyms/${input.gymId}/usage/current`);
    const entitlementRef = db.doc(`gyms/${input.gymId}/entitlements/current`);
    try {
      await db.runTransaction(async (tx) => {
        const [usage, entitlement] = await Promise.all([tx.get(usageRef), tx.get(entitlementRef)]);
        if (!usage.exists || !entitlement.exists) {
          throw new HttpsError("failed-precondition", "Gym plan entitlements are not configured.");
        }
        const next = assertWithinLimit(
          "scheduledClasses", Number(usage.get("scheduledClasses") ?? 0), 1,
          entitlement.get("limits") ?? {}
        );
        tx.update(usageRef, { scheduledClasses: next, updatedAt: FieldValue.serverTimestamp() });
        tx.create(sessionRef, {
          gymId: input.gymId, name: input.name, capacity: input.capacity,
          bookedCount: 0, trainerUid: input.trainerUid ?? null, status: "scheduled",
          startsAt: Timestamp.fromMillis(input.startsAtMillis), createdBy: request.auth!.uid,
          createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()
        });
      });
    } catch (error) {
      quotaError(error);
    }
    return { sessionId: sessionRef.id };
  }
);

export const updateGymConfiguration = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = gymConfigurationSchema.parse(request.data);
    await requireGymPermission(request, input.gymId, "staff.manage");
    await db.doc(`gyms/${input.gymId}`).set(configurationUpdate(input), { merge: true });
    await writeAudit(db, input.gymId, request.auth!.uid, "gym.configuration_updated", {});
    return { updated: true };
  }
);

export const updateGymAsPlatformAdmin = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = platformGymConfigurationSchema.parse(request.data);
    const gymRef = db.doc(`gyms/${input.gymId}`);
    if (!(await gymRef.get()).exists) {
      throw new HttpsError("not-found", "Gym tenant was not found.");
    }
    await gymRef.set(configurationUpdate(input), { merge: true });
    await writeAudit(db, input.gymId, request.auth!.uid, "gym.platform_configuration_updated", {});
    return { updated: true };
  }
);

export const setGymSubscription = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      gymId: z.string().min(1),
      planId: z.string().regex(/^[a-z0-9-]{2,40}$/),
      status: z.enum(["trial", "active", "suspended"]),
      durationDays: z.number().int().min(1).max(3660),
      featureOverrides: planFeaturesSchema.partial().default({})
    }).parse(request.data);
    const gymRef = db.doc(`gyms/${input.gymId}`);
    const planRef = db.doc(`saas_plans/${input.planId}`);
    const subscriptionRef = db.doc(`gyms/${input.gymId}/platform_subscription/current`);
    const entitlementRef = db.doc(`gyms/${input.gymId}/entitlements/current`);
    const endsAt = Timestamp.fromMillis(Date.now() + input.durationDays * 86400000);

    await db.runTransaction(async (tx) => {
      const [gym, plan] = await Promise.all([tx.get(gymRef), tx.get(planRef)]);
      if (!gym.exists) throw new HttpsError("not-found", "Gym tenant was not found.");
      if (!plan.exists || plan.get("status") !== "active") {
        throw new HttpsError("failed-precondition", "Select an active SaaS plan.");
      }
      const snapshot = planSnapshot(plan.id, plan.data()!);
      const effectiveFeatures = {
        ...(snapshot.features as Record<string, boolean>),
        ...input.featureOverrides
      };
      const now = FieldValue.serverTimestamp();
      tx.set(gymRef, {
        status: input.status,
        platformPlan: plan.id,
        platformPlanEndsAt: endsAt,
        features: effectiveFeatures,
        featureOverrides: input.featureOverrides,
        updatedAt: now
      }, { merge: true });
      tx.set(subscriptionRef, {
        ...snapshot,
        features: effectiveFeatures,
        featureOverrides: input.featureOverrides,
        status: input.status,
        startsAt: now,
        endsAt,
        updatedAt: now,
        updatedBy: request.auth!.uid
      }, { merge: true });
      tx.set(entitlementRef, {
        ...snapshot,
        features: effectiveFeatures,
        featureOverrides: input.featureOverrides,
        status: input.status === "suspended" ? "suspended" : "active",
        endsAt,
        updatedAt: now
      }, { merge: true });
    });
    await writeAudit(db, input.gymId, request.auth!.uid, "gym.subscription_updated", {
      planId: input.planId,
      status: input.status,
      durationDays: input.durationDays,
      featureOverrides: input.featureOverrides
    });
    return { updated: true };
  }
);

export const getPlatformDashboard = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const [gyms, consumerCount, onboardedCount, connectedCount, ownerCount] = await Promise.all([
      db.collection("gyms").orderBy("createdAt", "desc").limit(200).get(),
      db.collection("users").count().get(),
      db.collection("users").where("onboardingCompletedAt", "!=", null).count().get(),
      db.collection("users").where("hasGymConnection", "==", true).count().get(),
      db.collection("users").where("ownsGym", "==", true).count().get()
    ]);
    const usageSnapshots = gyms.empty
      ? []
      : await db.getAll(...gyms.docs.map((gym) => db.doc(`gyms/${gym.id}/usage/current`)));
    let members = 0;
    let trainers = 0;
    let staff = 0;
    const tenants = gyms.docs.map((gym, index) => {
      const usage = usageSnapshots[index]?.data() ?? {};
      const activeMembers = Number(usage.activeMembers ?? 0);
      const activeTrainers = Number(usage.activeTrainers ?? 0);
      const activeStaff = Number(usage.activeStaff ?? 0);
      members += activeMembers;
      trainers += activeTrainers;
      staff += activeStaff;
      return {
        gymId: gym.id,
        name: String(gym.get("name") ?? "Gym"),
        status: String(gym.get("status") ?? "unknown"),
        planId: String(gym.get("platformPlan") ?? "manual"),
        activeMembers,
        activeTrainers,
        activeStaff,
        totalUsers: activeMembers + activeTrainers + activeStaff + 1
      };
    });
    const featureMetrics = await db.collection("platform_feature_metrics")
      .orderBy("totalEvents", "desc").limit(20).get();
    const consumers = consumerCount.data().count;
    const connectedConsumers = connectedCount.data().count;
    return {
      totals: {
        gyms: gyms.size,
        activeGyms: gyms.docs.filter((gym) => gym.get("status") === "active").length,
        trialGyms: gyms.docs.filter((gym) => gym.get("status") === "trial").length,
        members,
        trainers,
        staff,
        users: members + trainers + staff + gyms.size,
        consumers,
        standaloneConsumers: Math.max(0, consumers - connectedConsumers),
        gymConnectedConsumers: connectedConsumers,
        consumerOwners: ownerCount.data().count,
        onboardingCompleted: onboardedCount.data().count
      },
      tenants,
      features: featureMetrics.docs.map((metric) => ({ id: metric.id, ...metric.data() }))
    };
  }
);

async function recordPlatformMilestone(
  featureId: string,
  audience: string,
  scopeType: "personal" | "gym",
  gymId?: string
) {
  const now = FieldValue.serverTimestamp();
  const batch = db.batch();
  batch.set(db.doc(`platform_feature_metrics/${featureId}`), {
    featureId,
    totalEvents: FieldValue.increment(1),
    [`audience_${audience}`]: FieldValue.increment(1),
    [`scope_${scopeType}`]: FieldValue.increment(1),
    updatedAt: now
  }, { merge: true });
  if (gymId) {
    batch.set(db.doc(`gyms/${gymId}/feature_metrics/${featureId}`), {
      gymId,
      featureId,
      totalEvents: FieldValue.increment(1),
      [`audience_${audience}`]: FieldValue.increment(1),
      scopeType: "gym",
      updatedAt: now
    }, { merge: true });
  }
  await batch.commit();
}

export const trackFeatureUsage = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const input = z.object({
      scopeType: z.enum(["personal", "gym"]).default("gym"),
      gymId: z.string().min(1).optional(),
      featureId: featureIdSchema
    }).parse(request.data);
    if (input.scopeType === "gym" && !input.gymId) {
      throw new HttpsError("invalid-argument", "gymId is required for gym scope.");
    }
    let role = "standalone";
    if (input.scopeType === "gym") {
      const [membership, gym] = await Promise.all([
        db.doc(`gym_memberships/${input.gymId}_${request.auth.uid}`).get(),
        db.doc(`gyms/${input.gymId}`).get()
      ]);
      if (!membership.exists || membership.get("status") !== "active") {
        throw new HttpsError("permission-denied", "Active gym membership is required.");
      }
      if (!gym.exists) throw new HttpsError("failed-precondition", "This gym is not currently active.");
      const planEndsAt = gym.get("platformPlanEndsAt") as Timestamp | undefined;
      if (!["trial", "active"].includes(String(gym.get("status"))) ||
          (planEndsAt && planEndsAt.toMillis() <= Date.now())) {
        throw new HttpsError("failed-precondition", "This gym is not currently active.");
      }
      role = String(membership.get("role") ?? "member");
    } else {
      const [account, memberships] = await Promise.all([
        db.doc(`users/${request.auth.uid}`).get(),
        db.collection("gym_memberships")
          .where("uid", "==", request.auth.uid)
          .where("status", "==", "active")
          .limit(20)
          .get()
      ]);
      if (account.get("status") === "suspended") {
        throw new HttpsError("permission-denied", "This account is suspended.");
      }
      const roles = memberships.docs.map((item) => String(item.get("role")));
      role = roles.includes("owner")
        ? "owner"
        : roles.includes("trainer")
        ? "trainer"
        : roles.includes("member")
        ? "member"
        : roles.length > 0
        ? "staff"
        : "standalone";
    }
    const scopeKey = input.scopeType === "gym" ? input.gymId! : "personal";
    const throttleRef = db.doc(
      `users/${request.auth.uid}/feature_usage_state/${scopeKey}_${input.featureId}`
    );
    const tracked = await db.runTransaction(async (tx) => {
      const state = await tx.get(throttleRef);
      const lastTrackedAt = state.get("lastTrackedAt") as Timestamp | undefined;
      if (lastTrackedAt && lastTrackedAt.toMillis() > Date.now() - 15 * 60 * 1000) {
        return false;
      }
      const now = FieldValue.serverTimestamp();
      tx.set(throttleRef, {
        scopeType: input.scopeType,
        ...(input.gymId ? { gymId: input.gymId } : {}),
        featureId: input.featureId,
        lastTrackedAt: now
      });
      tx.set(db.doc(`platform_feature_metrics/${input.featureId}`), {
        featureId: input.featureId,
        totalEvents: FieldValue.increment(1),
        [`audience_${role}`]: FieldValue.increment(1),
        [`scope_${input.scopeType}`]: FieldValue.increment(1),
        updatedAt: now
      }, { merge: true });
      if (input.gymId) {
        tx.set(db.doc(`gyms/${input.gymId}/feature_metrics/${input.featureId}`), {
          gymId: input.gymId,
          scopeType: "gym",
          featureId: input.featureId,
          totalEvents: FieldValue.increment(1),
          [`audience_${role}`]: FieldValue.increment(1),
          updatedAt: now
        }, { merge: true });
      }
      return true;
    });
    return { tracked };
  }
);

export const submitFeatureFeedback = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const input = z.object({
      gymId: z.string().min(1),
      featureId: featureIdSchema,
      rating: z.number().int().min(1).max(5),
      message: z.string().trim().min(3).max(1000)
    }).parse(request.data);
    const [membership, gym] = await Promise.all([
      db.doc(`gym_memberships/${input.gymId}_${request.auth.uid}`).get(),
      db.doc(`gyms/${input.gymId}`).get()
    ]);
    if (!membership.exists || membership.get("status") !== "active") {
      throw new HttpsError("permission-denied", "Active gym membership is required.");
    }
    if (!gym.exists) throw new HttpsError("failed-precondition", "This gym is not currently active.");
    const planEndsAt = gym.get("platformPlanEndsAt") as Timestamp | undefined;
    if (!["trial", "active"].includes(String(gym.get("status"))) ||
        (planEndsAt && planEndsAt.toMillis() <= Date.now())) {
      throw new HttpsError("failed-precondition", "This gym is not currently active.");
    }
    const role = String(membership.get("role") ?? "member");
    const feedback = db.collection("platform_feedback").doc();
    const throttleRef = db.doc(
      `users/${request.auth.uid}/feedback_state/${input.gymId}_${input.featureId}`
    );
    await db.runTransaction(async (tx) => {
      const state = await tx.get(throttleRef);
      const lastSubmittedAt = state.get("lastSubmittedAt") as Timestamp | undefined;
      if (lastSubmittedAt && lastSubmittedAt.toMillis() > Date.now() - 5 * 60 * 1000) {
        throw new HttpsError("resource-exhausted", "Please wait before submitting more feedback.");
      }
      const now = FieldValue.serverTimestamp();
      tx.set(throttleRef, {
        gymId: input.gymId,
        featureId: input.featureId,
        lastSubmittedAt: now
      });
      tx.create(feedback, {
        gymId: input.gymId,
        uid: request.auth.uid,
        role,
        featureId: input.featureId,
        rating: input.rating,
        message: input.message,
        status: "new",
        createdAt: now
      });
      tx.set(db.doc(`platform_feature_metrics/${input.featureId}`), {
        featureId: input.featureId,
        feedbackCount: FieldValue.increment(1),
        ratingTotal: FieldValue.increment(input.rating),
        updatedAt: now
      }, { merge: true });
    });
    return { submitted: true };
  }
);

export const updateGymMembership = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = z.object({
      gymId: z.string().min(1),
      uid: z.string().min(1),
      role: z.enum(["manager", "receptionist", "trainer", "accountant", "member"]),
      status: z.enum(["active", "inactive"]),
      permissionOverrides: z.record(z.string(), z.boolean()).optional()
    }).parse(request.data);
    requireAuth(request);
    if (input.uid === request.auth!.uid) {
      throw new HttpsError("failed-precondition", "You cannot change your own membership.");
    }
    const targetRef = db.doc(`gym_memberships/${input.gymId}_${input.uid}`);
    const target = await targetRef.get();
    if (!target.exists) throw new HttpsError("not-found", "Membership was not found.");
    const oldRole = String(target.get("role"));
    const requiredPermission = oldRole === "member" && input.role === "member"
      ? "members.write"
      : "staff.manage";
    const actor = await requireGymPermission(request, input.gymId, requiredPermission);
    if (target.get("role") === "owner") {
      throw new HttpsError("permission-denied", "The gym owner membership is immutable.");
    }
    if (actor.role !== "owner" && ["owner", "manager"].includes(String(target.get("role")))) {
      throw new HttpsError("permission-denied", "Only the owner can manage managers.");
    }
    const knownPermissions = new Set(Object.values(ROLE_PERMISSIONS).flatMap(Object.keys));
    const permissionOverrides = input.permissionOverrides ??
      (target.get("permissionOverrides") as Record<string, boolean> | undefined) ?? {};
    if (Object.keys(permissionOverrides).some((key) => !knownPermissions.has(key))) {
      throw new HttpsError("invalid-argument", "Unknown permission override.");
    }
    if (requiredPermission === "members.write" && input.permissionOverrides &&
        Object.keys(input.permissionOverrides).length > 0) {
      throw new HttpsError("permission-denied", "Permission overrides require staff-management access.");
    }
    const ownerOnly = ["staff.manage", "members.delete", "audit.read"];
    if (actor.role !== "owner" && ownerOnly.some((key) => permissionOverrides[key] === true)) {
      throw new HttpsError("permission-denied", "Only the owner can grant sensitive permissions.");
    }
    const identity = await userIdentity(input.uid);
    const permissions = {
      ...ROLE_PERMISSIONS[input.role],
      ...permissionOverrides
    };
    const entitlementRef = db.doc(`gyms/${input.gymId}/entitlements/current`);
    const usageRef = db.doc(`gyms/${input.gymId}/usage/current`);
    try {
      await db.runTransaction(async (tx) => {
        const [current, entitlement, usage] = await Promise.all([
          tx.get(targetRef), tx.get(entitlementRef), tx.get(usageRef)
        ]);
        if (!current.exists) throw new HttpsError("not-found", "Membership was not found.");
        const currentRole = String(current.get("role"));
        const wasActive = current.get("status") === "active";
        const willBeActive = input.status === "active";
        const oldField = wasActive ? usageFieldForRole(currentRole) : null;
        const newField = willBeActive ? usageFieldForRole(input.role) : null;
        if ((oldField || newField) && (!entitlement.exists || !usage.exists)) {
          throw new HttpsError("failed-precondition", "Gym plan entitlements are not configured.");
        }
        const changes = new Map<string, number>();
        if (oldField) changes.set(oldField, (changes.get(oldField) ?? 0) - 1);
        if (newField) changes.set(newField, (changes.get(newField) ?? 0) + 1);
        const usageUpdate: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };
        for (const [field, change] of changes) {
          if (change === 0) continue;
          usageUpdate[field] = assertWithinLimit(
            field as UsageField,
            Number(usage.get(field) ?? 0), change, entitlement.get("limits") ?? {}
          );
        }
        if (changes.size > 0) tx.update(usageRef, usageUpdate);

        const profileCollection = input.role === "member" ? "members" : "staff";
        const oldProfileCollection = currentRole === "member" ? "members" : "staff";
        tx.update(targetRef, {
          role: input.role, status: input.status, permissions, permissionOverrides,
          ...(willBeActive ? { leftAt: null } : {}),
          updatedAt: FieldValue.serverTimestamp(), updatedBy: request.auth!.uid
        });
        tx.set(db.doc(`gyms/${input.gymId}/${profileCollection}/${input.uid}`), {
          gymId: input.gymId, uid: input.uid, role: input.role, status: input.status,
          ...(willBeActive ? { leftAt: null } : {}),
          ...(identity.displayName ? { displayName: identity.displayName } : {}),
          ...(identity.email ? { email: identity.email } : {}),
          ...(identity.phone ? { phone: identity.phone } : {}),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
        if (oldProfileCollection !== profileCollection) {
          tx.delete(db.doc(`gyms/${input.gymId}/${oldProfileCollection}/${input.uid}`));
        }
        const wasActiveMember = currentRole === "member" && wasActive;
        const isActiveMember = input.role === "member" && willBeActive;
        if (wasActiveMember !== isActiveMember) {
          tx.set(db.doc(`gyms/${input.gymId}/dashboard_metrics/current`), {
            activeMembers: FieldValue.increment(isActiveMember ? 1 : -1),
            updatedAt: FieldValue.serverTimestamp()
          }, { merge: true });
        }
      });
    } catch (error) {
      quotaError(error);
    }
    await writeAudit(db, input.gymId, request.auth!.uid, "membership.updated", {
      uid: input.uid,
      role: input.role,
      status: input.status,
      permissionOverrides
    });
    return { updated: true };
  }
);

const membershipPlanSchema = z.object({
  gymId: z.string().min(1),
  planId: z.string().regex(/^[A-Za-z0-9_-]{1,40}$/).optional(),
  name: z.string().trim().min(2).max(80),
  description: z.string().trim().max(300).default(""),
  durationDays: z.number().int().min(1).max(3660),
  priceMinor: z.number().int().nonnegative(),
  status: z.enum(["active", "inactive"]).default("active")
});

export const upsertMembershipPlan = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = membershipPlanSchema.parse(request.data);
    const { gym } = await requireGymPermission(request, input.gymId, "plans.manage");
    const planRef = input.planId
      ? db.doc(`gyms/${input.gymId}/membership_plans/${input.planId}`)
      : db.collection(`gyms/${input.gymId}/membership_plans`).doc();
    const existing = await planRef.get();
    await planRef.set({
      gymId: input.gymId,
      name: input.name,
      description: input.description,
      durationDays: input.durationDays,
      priceMinor: input.priceMinor,
      currency: gym.currency ?? "INR",
      status: input.status,
      updatedBy: request.auth!.uid,
      updatedAt: FieldValue.serverTimestamp(),
      ...(!existing.exists
        ? { createdBy: request.auth!.uid, createdAt: FieldValue.serverTimestamp() }
        : {})
    }, { merge: true });
    await writeAudit(db, input.gymId, request.auth!.uid, existing.exists ? "plan.updated" : "plan.created", {
      planId: planRef.id,
      name: input.name,
      status: input.status
    });
    return { planId: planRef.id };
  }
);

const paymentSchema = z.object({
  gymId: z.string(),
  memberUid: z.string(),
  planId: z.string(),
  amountMinor: z.number().int().nonnegative(),
  method: z.enum(["cash", "upi", "card", "bank_transfer", "other"]),
  paidAtMillis: z.number().int(),
  requestedStartMillis: z.number().int(),
  reference: z.string().trim().max(120).optional(),
  notes: z.string().trim().max(500).optional()
});

export const recordPayment = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = paymentSchema.parse(request.data);
    const { gym } = await requireGymPermission(request, input.gymId, "payments.write");
    const paymentRef = db.collection(`gyms/${input.gymId}/payments`).doc();
    const subscriptionRef = db.doc(`gyms/${input.gymId}/subscriptions/${input.memberUid}`);
    const planRef = db.doc(`gyms/${input.gymId}/membership_plans/${input.planId}`);
    const memberRef = db.doc(`gyms/${input.gymId}/members/${input.memberUid}`);
    const renewalRequestRef = db.doc(`gyms/${input.gymId}/renewal_requests/${input.memberUid}`);
    let receiptNumber = "";
    let startsAtMillis = input.requestedStartMillis;
    let endsAtMillis = input.requestedStartMillis;
    await db.runTransaction(async (tx) => {
      const [plan, member, existingSubscription, renewalRequest] = await Promise.all([
        tx.get(planRef),
        tx.get(memberRef),
        tx.get(subscriptionRef),
        tx.get(renewalRequestRef)
      ]);
      if (!plan.exists || plan.get("status") !== "active") {
        throw new HttpsError("failed-precondition", "Select an active membership plan.");
      }
      if (!member.exists || member.get("status") !== "active" || member.get("role") !== "member") {
        throw new HttpsError("failed-precondition", "Select an active gym member.");
      }
      if (input.amountMinor !== Number(plan.get("priceMinor")) && !input.notes) {
        throw new HttpsError(
          "invalid-argument",
          "Add an internal note when the received amount differs from the plan price."
        );
      }
      const durationDays = Number(plan.get("durationDays"));
      const currentEnd = existingSubscription.exists && existingSubscription.get("status") === "active"
        ? (existingSubscription.get("endAt") as Timestamp | undefined)?.toMillis() ?? null
        : null;
      const window = renewalWindow(input.requestedStartMillis, currentEnd, durationDays);
      startsAtMillis = window.startsAtMillis;
      endsAtMillis = window.endsAtMillis;
      receiptNumber = `PAY-${paymentRef.id.slice(0, 8).toUpperCase()}`;
      tx.create(paymentRef, {
        ...input,
        receiptNumber,
        status: "paid",
        memberName: member.get("displayName") ?? member.get("email") ?? input.memberUid,
        planName: plan.get("name"),
        listPriceMinor: plan.get("priceMinor"),
        durationDays,
        currency: gym.currency ?? "INR",
        recordedBy: request.auth!.uid,
        paidAt: Timestamp.fromMillis(input.paidAtMillis),
        subscriptionStartsAt: Timestamp.fromMillis(startsAtMillis),
        subscriptionEndsAt: Timestamp.fromMillis(endsAtMillis),
        createdAt: FieldValue.serverTimestamp()
      });
      tx.set(subscriptionRef, {
        gymId: input.gymId,
        memberUid: input.memberUid,
        memberName: member.get("displayName") ?? member.get("email") ?? input.memberUid,
        planId: input.planId,
        planName: plan.get("name"),
        status: "active",
        startAt: Timestamp.fromMillis(startsAtMillis),
        endAt: Timestamp.fromMillis(endsAtMillis),
        lastPaymentId: paymentRef.id,
        lastPaymentAmountMinor: input.amountMinor,
        currency: gym.currency ?? "INR",
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      if (renewalRequest.exists && renewalRequest.get("status") === "pending") {
        tx.update(renewalRequestRef, {
          status: "completed",
          paymentId: paymentRef.id,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      }
    });
    await writeAudit(db, input.gymId, request.auth!.uid, "payment.recorded", {
      paymentId: paymentRef.id,
      memberUid: input.memberUid,
      amountMinor: input.amountMinor
    });
    return { paymentId: paymentRef.id, receiptNumber, startsAtMillis, endsAtMillis };
  }
);

export const requestMembershipRenewal = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const input = z.object({
      gymId: z.string().min(1),
      planId: z.string().min(1).max(80)
    }).parse(request.data);
    const { role } = await requireGymPermission(request, input.gymId, "fitness.read");
    if (role !== "member") {
      throw new HttpsError("permission-denied", "Only members can request their own renewal.");
    }
    const [plan, member] = await Promise.all([
      db.doc(`gyms/${input.gymId}/membership_plans/${input.planId}`).get(),
      db.doc(`gyms/${input.gymId}/members/${request.auth.uid}`).get()
    ]);
    if (!plan.exists || plan.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "This membership plan is unavailable.");
    }
    const requestRef = db.doc(`gyms/${input.gymId}/renewal_requests/${request.auth.uid}`);
    const existing = await requestRef.get();
    if (existing.exists && existing.get("status") === "pending") {
      throw new HttpsError("already-exists", "A renewal request is already pending.");
    }
    await requestRef.set({
      gymId: input.gymId,
      memberUid: request.auth.uid,
      memberName: member.get("displayName") ?? member.get("email") ?? request.auth.uid,
      planId: plan.id,
      planName: plan.get("name"),
      amountMinor: plan.get("priceMinor"),
      currency: plan.get("currency") ?? "INR",
      status: "pending",
      channel: "member_app",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp()
    });
    await db.collection(`gyms/${input.gymId}/notifications`).add({
      gymId: input.gymId,
      recipientUid: request.auth.uid,
      type: "renewal_request",
      title: "Renewal request received",
      body: `Your request for ${String(plan.get("name"))} was sent to the gym.`,
      read: false,
      createdAt: FieldValue.serverTimestamp()
    });
    await writeAudit(db, input.gymId, request.auth.uid, "renewal.requested", {
      planId: plan.id
    });
    return { requestId: requestRef.id, status: "pending" };
  }
);

export const createAttendanceQr = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const { gymId } = z.object({ gymId: z.string() }).parse(request.data);
    await requireGymPermission(request, gymId, "attendance.manage");
    const token = secureToken(24);
    const expiresAt = Timestamp.fromMillis(Date.now() + 60000);
    await db.doc(`gyms/${gymId}/qr_sessions/${hashToken(token)}`).set({
      gymId,
      status: "active",
      expiresAt,
      createdBy: request.auth!.uid,
      createdAt: FieldValue.serverTimestamp()
    });
    return { token, expiresAtMillis: expiresAt.toMillis() };
  }
);

export const checkIn = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const { gymId, token } = z.object({ gymId: z.string(), token: z.string() }).parse(request.data);
    const { gym } = await requireGymPermission(request, gymId, "fitness.read");
    const qrRef = db.doc(`gyms/${gymId}/qr_sessions/${hashToken(token)}`);
    const dateKey = new Intl.DateTimeFormat("en-CA", {
      timeZone: String(gym.timezone ?? "Asia/Kolkata")
    }).format(new Date());
    const attendanceRef = db.doc(`gyms/${gymId}/attendance/${attendanceDocumentId(request.auth.uid, dateKey)}`);
    await db.runTransaction(async (tx) => {
      const [qr, existing] = await Promise.all([tx.get(qrRef), tx.get(attendanceRef)]);
      if (!qr.exists || qr.get("status") !== "active" || qr.get("expiresAt").toMillis() <= Date.now()) {
        throw new HttpsError("deadline-exceeded", "QR code is invalid or expired.");
      }
      if (existing.exists) throw new HttpsError("already-exists", "You are already checked in today.");
      tx.create(attendanceRef, {
        gymId,
        memberUid: request.auth!.uid,
        source: "qr",
        dateKey,
        checkedInAt: FieldValue.serverTimestamp()
      });
    });
    return { checkedIn: true };
  }
);

export const correctAttendance = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    const input = z.object({
      gymId: z.string().min(1),
      memberUid: z.string().min(1),
      dateKey: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
      present: z.boolean(),
      reason: z.string().min(3).max(240)
    }).parse(request.data);
    await requireGymPermission(request, input.gymId, "attendance.manage");
    const attendanceRef = db.doc(
      `gyms/${input.gymId}/attendance/${attendanceDocumentId(input.memberUid, input.dateKey)}`
    );
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(attendanceRef);
      if (input.present) {
        tx.set(attendanceRef, {
          gymId: input.gymId,
          memberUid: input.memberUid,
          dateKey: input.dateKey,
          source: "manual",
          correctionReason: input.reason,
          correctedBy: request.auth!.uid,
          checkedInAt: existing.exists
            ? existing.get("checkedInAt")
            : FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      } else if (existing.exists) {
        tx.delete(attendanceRef);
      }
    });
    await writeAudit(db, input.gymId, request.auth!.uid, "attendance.corrected", input);
    return { updated: true };
  }
);

export const onAttendanceCreated = onDocumentCreated(
  { region: REGION, document: "gyms/{gymId}/attendance/{attendanceId}" },
  async (event) => {
    const dateKey = String(event.data?.get("dateKey") ?? "");
    const metricRef = db.doc(`gyms/${event.params.gymId}/dashboard_metrics/current`);
    await db.runTransaction(async (tx) => {
      const metric = await tx.get(metricRef);
      const sameDay = metric.get("attendanceDateKey") === dateKey;
      tx.set(metricRef, {
        attendanceDateKey: dateKey,
        todayAttendance: sameDay ? Number(metric.get("todayAttendance") ?? 0) + 1 : 1,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    });
  }
);

export const onAttendanceDeleted = onDocumentDeleted(
  { region: REGION, document: "gyms/{gymId}/attendance/{attendanceId}" },
  async (event) => {
    const dateKey = String(event.data?.get("dateKey") ?? "");
    const metricRef = db.doc(`gyms/${event.params.gymId}/dashboard_metrics/current`);
    await db.runTransaction(async (tx) => {
      const metric = await tx.get(metricRef);
      if (metric.get("attendanceDateKey") !== dateKey) return;
      tx.set(metricRef, {
        todayAttendance: Math.max(0, Number(metric.get("todayAttendance") ?? 0) - 1),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    });
  }
);

export const onPaymentCreated = onDocumentCreated(
  { region: REGION, document: "gyms/{gymId}/payments/{paymentId}" },
  async (event) => {
    const payment = event.data?.data();
    if (!payment) return;
    const paidAt = (payment.paidAt as Timestamp).toDate();
    const monthKey = paidAt.toISOString().slice(0, 7);
    const metricRef = db.doc(`gyms/${event.params.gymId}/dashboard_metrics/current`);
    await db.runTransaction(async (tx) => {
      const metric = await tx.get(metricRef);
      const sameMonth = metric.get("revenueMonthKey") === monthKey;
      tx.set(metricRef, {
        revenueMonthKey: monthKey,
        monthlyRevenueMinor: (sameMonth ? Number(metric.get("monthlyRevenueMinor") ?? 0) : 0) +
          Number(payment.amountMinor ?? 0),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    });
  }
);

export const bookClass = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const { gymId, sessionId } = z.object({ gymId: z.string(), sessionId: z.string() }).parse(request.data);
    await requireGymPermission(request, gymId, "fitness.read");
    const sessionRef = db.doc(`gyms/${gymId}/class_sessions/${sessionId}`);
    const bookingRef = db.doc(`gyms/${gymId}/class_bookings/${bookingDocumentId(sessionId, request.auth.uid)}`);
    await db.runTransaction(async (tx) => {
      const [session, existing] = await Promise.all([tx.get(sessionRef), tx.get(bookingRef)]);
      if (!session.exists || session.get("status") !== "scheduled") {
        throw new HttpsError("not-found", "Class is unavailable.");
      }
      if (existing.exists && existing.get("status") === "booked") {
        throw new HttpsError("already-exists", "Class is already booked.");
      }
      const bookedCount = Number(session.get("bookedCount") ?? 0);
      const capacity = Number(session.get("capacity"));
      if (bookedCount >= capacity) throw new HttpsError("resource-exhausted", "Class is full.");
      tx.set(bookingRef, {
        gymId,
        sessionId,
        memberUid: request.auth!.uid,
        status: "booked",
        bookedAt: FieldValue.serverTimestamp()
      });
      tx.update(sessionRef, { bookedCount: FieldValue.increment(1) });
    });
    return { booked: true };
  }
);

export const cancelClassBooking = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const { gymId, sessionId } = z.object({ gymId: z.string(), sessionId: z.string() }).parse(request.data);
    await requireGymPermission(request, gymId, "fitness.read");
    const sessionRef = db.doc(`gyms/${gymId}/class_sessions/${sessionId}`);
    const bookingRef = db.doc(`gyms/${gymId}/class_bookings/${bookingDocumentId(sessionId, request.auth.uid)}`);
    await db.runTransaction(async (tx) => {
      const booking = await tx.get(bookingRef);
      if (!booking.exists || booking.get("status") !== "booked") {
        throw new HttpsError("not-found", "Active booking was not found.");
      }
      tx.update(bookingRef, { status: "cancelled", cancelledAt: FieldValue.serverTimestamp() });
      tx.update(sessionRef, { bookedCount: FieldValue.increment(-1) });
    });
    return { cancelled: true };
  }
);

export const createConversation = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const { gymId, targetUid } = z.object({
      gymId: z.string().min(1),
      targetUid: z.string().min(1)
    }).parse(request.data);
    const { role } = await requireGymPermission(request, gymId, "fitness.read");
    const targetMembership = await db.doc(`gym_memberships/${gymId}_${targetUid}`).get();
    if (!targetMembership.exists || targetMembership.get("status") !== "active") {
      throw new HttpsError("not-found", "The other participant is not active in this gym.");
    }
    const targetRole = String(targetMembership.get("role"));
    if (!([role, targetRole].includes("member") && [role, targetRole].includes("trainer"))) {
      throw new HttpsError("permission-denied", "Direct support chat is limited to members and trainers.");
    }
    const participantUids = [request.auth.uid, targetUid].sort();
    const conversationId = participantUids.join("_");
    await db.doc(`gyms/${gymId}/conversations/${conversationId}`).set({
      gymId,
      participantUids,
      type: "member_trainer",
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp()
    }, { merge: true });
    return { conversationId };
  }
);

export const onMessageCreated = onDocumentCreated(
  { region: REGION, document: "gyms/{gymId}/conversations/{conversationId}/messages/{messageId}" },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;
    const { gymId, conversationId } = event.params;
    const conversationRef = db.doc(`gyms/${gymId}/conversations/${conversationId}`);
    const conversation = await conversationRef.get();
    const recipients = (conversation.get("participantUids") as string[]).filter((uid) => uid !== message.senderUid);
    await conversationRef.update({
      lastMessage: message.text ?? "Attachment",
      lastMessageAt: FieldValue.serverTimestamp()
    });
    for (const uid of recipients) {
      await db.collection(`gyms/${gymId}/notifications`).add({
        gymId,
        recipientUid: uid,
        type: "chat",
        title: "New message",
        body: message.text ?? "Sent an attachment",
        data: { conversationId },
        read: false,
        createdAt: FieldValue.serverTimestamp()
      });
      const tokens = await db.collection(`users/${uid}/device_tokens`).get();
      if (!tokens.empty) {
        await getMessaging().sendEachForMulticast({
          tokens: tokens.docs.map((doc) => doc.id),
          notification: { title: "New message", body: message.text ?? "Sent an attachment" },
          data: { gymId, conversationId }
        });
      }
    }
  }
);

export const sendExpiryReminders = onSchedule(
  { region: REGION, schedule: "every day 09:00", timeZone: "Asia/Kolkata" },
  async () => {
    const now = Date.now();
    const cutoff = Timestamp.fromMillis(now + 7 * 86400000);
    const previousDay = Timestamp.fromMillis(now - 86400000);
    const expiring = await db.collectionGroup("subscriptions")
      .where("status", "==", "active")
      .where("endAt", ">=", previousDay)
      .where("endAt", "<=", cutoff)
      .get();
    for (const subscription of expiring.docs) {
      const data = subscription.data();
      const remainingMillis = data.endAt.toMillis() - now;
      const daysRemaining = Math.max(0, Math.ceil(remainingMillis / 86400000));
      const reminderWindow = expiryReminderWindow(daysRemaining);
      const expired = daysRemaining === 0;
      const notificationId = `expiry_${subscription.id}_${data.endAt.toMillis()}_${reminderWindow}`;
      const notificationRef = subscription.ref.parent.parent!.collection("notifications").doc(notificationId);
      if ((await notificationRef.get()).exists) continue;
      const title = expired ? "Membership expired" : "Membership expiring soon";
      const body = expired
        ? "Renew your plan to continue your gym membership."
        : `Your membership expires in ${daysRemaining} day${daysRemaining === 1 ? "" : "s"}.`;
      await notificationRef.create({
        gymId: data.gymId,
        recipientUid: data.memberUid,
        type: expired ? "subscription_expired" : "subscription_expiry",
        title,
        body,
        data: { endAtMillis: data.endAt.toMillis(), daysRemaining },
        read: false,
        createdAt: FieldValue.serverTimestamp()
      });
      await sendPush(data.memberUid, title, body, {
        gymId: String(data.gymId),
        type: expired ? "subscription_expired" : "subscription_expiry"
      });
    }
    logger.info("Subscription expiry reminders generated", { count: expiring.size });
  }
);

export const sendClassReminders = onSchedule(
  { region: REGION, schedule: "every 30 minutes", timeZone: "Asia/Kolkata" },
  async () => {
    const now = Timestamp.now();
    const cutoff = Timestamp.fromMillis(Date.now() + 60 * 60000);
    const sessions = await db.collectionGroup("class_sessions")
      .where("status", "==", "scheduled")
      .where("startsAt", ">", now)
      .where("startsAt", "<=", cutoff)
      .get();
    for (const session of sessions.docs) {
      const gymRef = session.ref.parent.parent;
      if (!gymRef) continue;
      const bookings = await gymRef.collection("class_bookings")
        .where("sessionId", "==", session.id)
        .where("status", "==", "booked")
        .get();
      for (const booking of bookings.docs) {
        const uid = String(booking.get("memberUid"));
        const notificationId = `class_${session.id}_${session.get("startsAt").toMillis()}_${uid}`;
        const notificationRef = gymRef.collection("notifications").doc(notificationId);
        if ((await notificationRef.get()).exists) continue;
        await notificationRef.create({
          gymId: gymRef.id,
          recipientUid: uid,
          type: "class_reminder",
          title: "Class starting soon",
          body: `${session.get("name") ?? "Your class"} starts within an hour.`,
          data: { sessionId: session.id },
          read: false,
          createdAt: FieldValue.serverTimestamp()
        });
        await sendPush(uid, "Class starting soon", `${session.get("name") ?? "Your class"} starts within an hour.`, {
          gymId: gymRef.id,
          sessionId: session.id
        });
      }
    }
    logger.info("Class reminders generated", { sessions: sessions.size });
  }
);

export const closeStartedClassSessions = onSchedule(
  { region: REGION, schedule: "every 30 minutes", timeZone: "Asia/Kolkata" },
  async () => {
    const sessions = await db.collectionGroup("class_sessions")
      .where("status", "==", "scheduled")
      .where("startsAt", "<=", Timestamp.now())
      .limit(500)
      .get();
    for (const session of sessions.docs) {
      const gymRef = session.ref.parent.parent;
      if (!gymRef) continue;
      const usageRef = gymRef.collection("usage").doc("current");
      await db.runTransaction(async (tx) => {
        const [current, usage] = await Promise.all([tx.get(session.ref), tx.get(usageRef)]);
        if (!current.exists || current.get("status") !== "scheduled") return;
        tx.update(session.ref, {
          status: "completed", completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
        if (usage.exists) {
          tx.update(usageRef, {
            scheduledClasses: Math.max(0, Number(usage.get("scheduledClasses") ?? 0) - 1),
            updatedAt: FieldValue.serverTimestamp()
          });
        }
      });
    }
    logger.info("Started class sessions closed", { count: sessions.size });
  }
);

async function sendPush(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  const tokens = await db.collection(`users/${uid}/device_tokens`).get();
  if (tokens.empty) return;
  await getMessaging().sendEachForMulticast({
    tokens: tokens.docs.map((document) => document.id),
    notification: { title, body },
    data
  });
}

export const exportMyData = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const memberships = await db.collection("gym_memberships").where("uid", "==", request.auth.uid).get();
    const profile = await db.doc(`users/${request.auth.uid}`).get();
    const personalCollections = [
      "fitness_profile", "routines", "workout_logs", "measurements", "goals",
      "personal_records", "progress_photos", "notifications", "gym_shares",
      "entitlements", "support_history"
    ];
    const personalData: Record<string, unknown[]> = {};
    for (const collection of personalCollections) {
      const snapshot = await db.collection(`users/${request.auth.uid}/${collection}`)
        .limit(5000).get();
      personalData[collection] = snapshot.docs.map((document) => ({
        id: document.id,
        ...document.data()
      }));
    }
    const gymData = [];
    const memberCollections = [
      "subscriptions", "payments", "attendance", "class_bookings",
      "workout_assignments", "diet_assignments", "goals", "measurements",
      "personal_records", "workout_logs", "progress_photos", "member_routines"
    ];
    for (const membership of memberships.docs) {
      const gymId = String(membership.get("gymId"));
      const role = String(membership.get("role"));
      const ownProfile = await db.doc(
        `gyms/${gymId}/${role === "member" ? "members" : "staff"}/${request.auth.uid}`
      ).get();
      const records: Record<string, unknown[]> = {};
      for (const collection of memberCollections) {
        const snapshot = await db.collection(`gyms/${gymId}/${collection}`)
          .where("memberUid", "==", request.auth.uid)
          .limit(5000)
          .get();
        records[collection] = snapshot.docs.map((document) => ({
          id: document.id,
          ...document.data()
        }));
      }
      gymData.push({ gymId, role, profile: ownProfile.data() ?? {}, records });
    }
    return {
      profile: profile.data() ?? {},
      personalData,
      memberships: memberships.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
      gymData,
      exportedAt: new Date().toISOString()
    };
  }
);

export const requestAccountDeletion = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    await db.doc(`users/${request.auth.uid}`).set({
      deletionRequestedAt: FieldValue.serverTimestamp(),
      deletionScheduledFor: Timestamp.fromMillis(Date.now() + 30 * 86400000),
      status: "deletion_requested"
    }, { merge: true });
    const shares = await db.collection(`users/${request.auth.uid}/gym_shares`).get();
    for (const share of shares.docs) {
      const root = db.doc(`gyms/${share.id}/shared_fitness/${request.auth.uid}`);
      for (const collection of [
        "profile", "goals", "workout_logs", "personal_records",
        "measurements", "progress_photos"
      ]) {
        await deleteProjectedCollection(`${root.path}/${collection}`);
      }
      await root.delete().catch(() => undefined);
    }
    await getAuth().revokeRefreshTokens(request.auth.uid);
    await getAuth().updateUser(request.auth.uid, { disabled: true });
    return { requested: true, deletionAfterDays: 30 };
  }
);

const sharingCategories = [
  "profile",
  "goals",
  "workoutSummaries",
  "measurements",
  "progress"
] as const;

type SharingCategory = typeof sharingCategories[number];

const sharingSchema = z.object({
  gymId: z.string().min(1),
  categories: z.object({
    profile: z.boolean(),
    goals: z.boolean(),
    workoutSummaries: z.boolean(),
    measurements: z.boolean(),
    progress: z.boolean()
  })
});

const defaultConsumerFeatures = {
  routines: true,
  workoutLogging: true,
  progress: true,
  exerciseLibrary: true,
  progressPhotos: true,
  gymConnections: true
};

export const ensureConsumerAccount = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const uid = request.auth.uid;
    const identity = await userIdentity(uid, request.auth.token);
    const userRef = db.doc(`users/${uid}`);
    const entitlementRef = db.doc(`users/${uid}/entitlements/current`);
    const planRef = db.doc("consumer_plans/free");
    await db.runTransaction(async (tx) => {
      const [user, entitlement, plan] = await Promise.all([
        tx.get(userRef),
        tx.get(entitlementRef),
        tx.get(planRef)
      ]);
      if (!user.exists) {
        tx.create(userRef, {
          uid,
          displayName: identity.displayName,
          email: identity.email,
          phone: identity.phone,
          status: "active",
          consumerPlanId: "free",
          registrationTrackedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      } else {
        tx.set(userRef, {
          displayName: user.get("displayName") ?? identity.displayName,
          email: identity.email,
          phone: identity.phone,
          status: user.get("status") ?? "active",
          consumerPlanId: user.get("consumerPlanId") ?? "free",
          lastSeenAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
        if (!user.get("registrationTrackedAt")) {
          tx.set(userRef, {
            registrationTrackedAt: FieldValue.serverTimestamp()
          }, { merge: true });
        }
      }
      if (!user.exists || !user.get("registrationTrackedAt")) {
        tx.set(db.doc("platform_feature_metrics/registration"), {
          featureId: "registration",
          totalEvents: FieldValue.increment(1),
          audience_standalone: FieldValue.increment(1),
          scope_personal: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
      if (!entitlement.exists) {
        tx.create(entitlementRef, {
          ownerUid: uid,
          planId: "free",
          planVersion: Number(plan.get("version") ?? 1),
          features: plan.get("features") ?? defaultConsumerFeatures,
          overrides: {},
          status: "active",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp()
        });
      }
    });
    return { uid, planId: "free" };
  }
);

function categoryForCollection(collection: string): SharingCategory | null {
  if (collection === "fitness_profile") return "profile";
  if (collection === "goals") return "goals";
  if (collection === "workout_logs" || collection === "personal_records") {
    return "workoutSummaries";
  }
  if (collection === "measurements") return "measurements";
  if (collection === "progress_photos") return "progress";
  return null;
}

function safeProjection(
  category: SharingCategory,
  data: Record<string, unknown>
): Record<string, unknown> {
  const allowed: Record<SharingCategory, string[]> = {
    profile: ["displayName", "fitnessGoals", "experienceLevel", "workoutDaysPerWeek"],
    goals: ["name", "target", "unit", "status", "targetAt", "createdAt", "updatedAt"],
    workoutSummaries: [
      "name", "title", "goal", "durationMinutes", "durationSeconds", "completedAt", "totalVolumeKg",
      "movementCount", "personalRecords", "origin", "createdAt", "updatedAt"
    ],
    measurements: [
      "weightKg", "bodyFatPercent", "chestCm", "waistCm", "hipsCm",
      "armsCm", "measuredAt", "createdAt", "updatedAt"
    ],
    progress: ["caption", "capturedAt", "createdAt", "updatedAt"]
  };
  const projection = Object.fromEntries(
    allowed[category]
      .filter((key) => data[key] !== undefined)
      .map((key) => [key, data[key]])
  );
  if (category === "workoutSummaries" && Array.isArray(data.exercises)) {
    projection.movementCount = data.exercises.length;
    projection.completedSets = data.exercises.reduce(
      (sum: number, exercise: unknown) => sum + Number(
        typeof exercise === "object" && exercise !== null && "completedSets" in exercise
          ? (exercise as Record<string, unknown>).completedSets ?? 0
          : 0
      ),
      0
    );
  }
  return projection;
}

async function deleteProjectedCollection(path: string) {
  const snapshot = await db.collection(path).limit(500).get();
  if (snapshot.empty) return;
  const batch = db.batch();
  snapshot.docs.forEach((document) => batch.delete(document.ref));
  await batch.commit();
  if (snapshot.size === 500) await deleteProjectedCollection(path);
}

const SHARING_PROJECTION_SOURCES: ReadonlyArray<{
  category: SharingCategory;
  sourceCollection: string;
  targetCollection: string;
}> = [
  { category: "goals", sourceCollection: "goals", targetCollection: "goals" },
  {
    category: "workoutSummaries",
    sourceCollection: "workout_logs",
    targetCollection: "workout_logs"
  },
  {
    category: "workoutSummaries",
    sourceCollection: "personal_records",
    targetCollection: "personal_records"
  },
  {
    category: "measurements",
    sourceCollection: "measurements",
    targetCollection: "measurements"
  },
  {
    category: "progress",
    sourceCollection: "progress_photos",
    targetCollection: "progress_photos"
  }
];

const SHARING_PROJECTION_COLLECTIONS = [
  ...new Set(SHARING_PROJECTION_SOURCES.map((source) => source.targetCollection)),
  "profile"
];

async function deleteSharingProjection(uid: string, gymId: string) {
  const root = db.doc(`gyms/${gymId}/shared_fitness/${uid}`);
  await Promise.all(
    SHARING_PROJECTION_COLLECTIONS.map((collection) =>
      deleteProjectedCollection(`${root.path}/${collection}`)
    )
  );
  await root.delete();
}

async function refreshSharingProjection(
  uid: string,
  gymId: string,
  categories: Record<SharingCategory, boolean>
) {
  const root = db.doc(`gyms/${gymId}/shared_fitness/${uid}`);
  await root.set({
    uid,
    gymId,
    categories: {
      profile: false,
      goals: false,
      workoutSummaries: false,
      measurements: false,
      progress: false
    },
    revokedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });

  for (const source of SHARING_PROJECTION_SOURCES) {
    await deleteProjectedCollection(`${root.path}/${source.targetCollection}`);
    if (!categories[source.category]) continue;
    const records = await db.collection(`users/${uid}/${source.sourceCollection}`).limit(250).get();
    if (records.empty) continue;
    const batch = db.batch();
    records.docs.forEach((document) => {
      batch.set(root.collection(source.targetCollection).doc(document.id), {
        ...safeProjection(source.category, document.data()),
        sourceId: document.id,
        projectedAt: FieldValue.serverTimestamp()
      });
    });
    await batch.commit();
  }
  await deleteProjectedCollection(`${root.path}/profile`);
  if (categories.profile) {
    const profile = await db.doc(`users/${uid}/fitness_profile/current`).get();
    if (profile.exists) {
      await root.collection("profile").doc("current").set({
        ...safeProjection("profile", profile.data()!),
        projectedAt: FieldValue.serverTimestamp()
      });
    }
  }
  await root.set({
    categories,
    revokedAt: null,
    updatedAt: FieldValue.serverTimestamp()
  }, { merge: true });
}

export const updateGymSharing = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const input = sharingSchema.parse(request.data);
    const uid = request.auth.uid;
    const membership = await db.doc(`gym_memberships/${membershipDocumentId(input.gymId, uid)}`).get();
    if (!membership.exists || membership.get("status") !== "active") {
      throw new HttpsError("permission-denied", "An active gym membership is required.");
    }
    await db.doc(`users/${uid}/gym_shares/${input.gymId}`).set({
      ownerUid: uid,
      gymId: input.gymId,
      categories: input.categories,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    await refreshSharingProjection(uid, input.gymId, input.categories);
    await writeAudit(
      db,
      input.gymId,
      uid,
      "consumer.sharing_updated",
      { type: "member", id: uid },
      { categories: input.categories }
    );
    return { gymId: input.gymId, categories: input.categories };
  }
);

export const leaveGymMembership = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requireAuth(request);
    const input = z.object({ gymId: z.string().min(1) }).parse(request.data);
    const uid = request.auth.uid;
    const membershipRef = db.doc(
      `gym_memberships/${membershipDocumentId(input.gymId, uid)}`
    );
    const memberRef = db.doc(`gyms/${input.gymId}/members/${uid}`);
    const usageRef = db.doc(`gyms/${input.gymId}/usage/current`);
    const metricsRef = db.doc(`gyms/${input.gymId}/dashboard_metrics/current`);
    const sharingRef = db.doc(`users/${uid}/gym_shares/${input.gymId}`);
    const projectionRoot = db.doc(`gyms/${input.gymId}/shared_fitness/${uid}`);
    const userRef = db.doc(`users/${uid}`);
    const activeMembershipsQuery = db.collection("gym_memberships")
      .where("uid", "==", uid)
      .where("status", "==", "active");
    const cleanupRef = db.doc(
      `privacy_cleanup_jobs/${membershipDocumentId(input.gymId, uid)}`
    );
    const auditRef = db.collection(`gyms/${input.gymId}/audit_logs`).doc();

    await db.runTransaction(async (tx) => {
      const [membership, usage, metrics, activeMemberships] = await Promise.all([
        tx.get(membershipRef),
        tx.get(usageRef),
        tx.get(metricsRef),
        tx.get(activeMembershipsQuery)
      ]);
      if (!membership.exists || membership.get("status") !== "active") {
        throw new HttpsError("failed-precondition", "This gym membership is not active.");
      }
      if (membership.get("role") !== "member") {
        throw new HttpsError(
          "permission-denied",
          "Operational gym roles must be transferred or removed by an authorized administrator."
        );
      }
      const now = FieldValue.serverTimestamp();
      tx.update(membershipRef, { status: "left", leftAt: now, updatedAt: now });
      tx.set(memberRef, { status: "left", leftAt: now, updatedAt: now }, { merge: true });
      tx.delete(sharingRef);
      tx.set(projectionRoot, {
        uid,
        gymId: input.gymId,
        categories: {
          profile: false,
          goals: false,
          workoutSummaries: false,
          measurements: false,
          progress: false
        },
        revokedAt: now,
        updatedAt: now
      }, { merge: true });
      tx.set(cleanupRef, {
        type: "gymSharingProjection",
        gymId: input.gymId,
        uid,
        status: "pending",
        attempts: 0,
        createdAt: now,
        updatedAt: now
      });
      const nextConnectionCount = Math.max(0, activeMemberships.size - 1);
      tx.set(userRef, {
        gymConnectionCount: nextConnectionCount,
        hasGymConnection: nextConnectionCount > 0,
        updatedAt: now
      }, { merge: true });
      tx.set(auditRef, {
        gymId: input.gymId,
        actorUid: uid,
        action: "membership.left",
        target: { type: "member", id: uid },
        metadata: {},
        createdAt: now
      });
      if (usage.exists) {
        tx.update(usageRef, {
          activeMembers: Math.max(0, Number(usage.get("activeMembers") ?? 0) - 1),
          updatedAt: now
        });
      }
      if (metrics.exists) {
        tx.update(metricsRef, {
          activeMembers: Math.max(0, Number(metrics.get("activeMembers") ?? 0) - 1),
          updatedAt: now
        });
      }
    });

    let cleanupPending = false;
    try {
      await deleteSharingProjection(uid, input.gymId);
      await cleanupRef.delete();
    } catch (error) {
      cleanupPending = true;
      logger.error("Gym sharing projection cleanup was queued for retry.", {
        gymId: input.gymId,
        uid,
        error: String(error)
      });
      await cleanupRef.set({
        status: "pending",
        attempts: FieldValue.increment(1),
        lastError: String(error).slice(0, 500),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true }).catch((jobError) => logger.error(
        "Unable to annotate the already-durable privacy cleanup job.",
        { gymId: input.gymId, uid, error: String(jobError) }
      ));
    }
    await recordPlatformMilestone("membershipLeave", "member", "gym", input.gymId)
      .catch((error) => logger.warn("Unable to record membership leave milestone.", {
        gymId: input.gymId,
        uid,
        error: String(error)
      }));
    return { gymId: input.gymId, status: "left", cleanupPending };
  }
);

export const retryPrivacyCleanup = onSchedule(
  { region: REGION, schedule: "every 60 minutes" },
  async () => {
    const jobs = await db.collection("privacy_cleanup_jobs")
      .where("status", "==", "pending")
      .limit(25)
      .get();
    for (const job of jobs.docs) {
      const gymId = String(job.get("gymId") ?? "");
      const uid = String(job.get("uid") ?? "");
      if (!gymId || !uid) {
        await job.ref.set({
          status: "invalid",
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
        continue;
      }
      try {
        await deleteSharingProjection(uid, gymId);
        await job.ref.delete();
      } catch (error) {
        logger.error("Scheduled privacy cleanup failed.", {
          jobId: job.id,
          gymId,
          uid,
          error: String(error)
        });
        await job.ref.set({
          attempts: FieldValue.increment(1),
          lastError: String(error).slice(0, 500),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
    }
  }
);

export const projectPersonalFitnessChange = onDocumentWritten(
  { region: REGION, document: "users/{uid}/{collection}/{documentId}" },
  async (event) => {
    const category = categoryForCollection(event.params.collection);
    if (!category) return;
    const shares = await db.collection(`users/${event.params.uid}/gym_shares`)
      .where(`categories.${category}`, "==", true)
      .get();
    for (const share of shares.docs) {
      const gymId = share.id;
      const targetCollection = event.params.collection === "fitness_profile"
        ? "profile"
        : event.params.collection;
      const target = db.doc(
        `gyms/${gymId}/shared_fitness/${event.params.uid}/${targetCollection}/${event.params.documentId}`
      );
      if (!event.data?.after.exists) {
        await target.delete().catch(() => undefined);
        continue;
      }
      await target.set({
        ...safeProjection(category, event.data.after.data()!),
        sourceId: event.params.documentId,
        projectedAt: FieldValue.serverTimestamp()
      });
    }
  }
);

export const aggregateConsumerGymConnections = onDocumentWritten(
  { region: REGION, document: "gym_memberships/{membershipId}" },
  async (event) => {
    const beforeUid = event.data?.before.get("uid") as string | undefined;
    const afterUid = event.data?.after.get("uid") as string | undefined;
    for (const uid of new Set([beforeUid, afterUid].filter(Boolean) as string[])) {
      const memberships = await db.collection("gym_memberships")
        .where("uid", "==", uid)
        .where("status", "==", "active")
        .limit(100)
        .get();
      await db.doc(`users/${uid}`).set({
        gymConnectionCount: memberships.size,
        hasGymConnection: !memberships.empty,
        ownsGym: memberships.docs.some((item) => item.get("role") === "owner"),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    }
  }
);

const supportCategories = ["account", "onboarding", "sharing", "memberships", "usage"] as const;
const supportCategorySchema = z.enum(supportCategories);

export const startConsumerSupportSession = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      targetUid: z.string().min(1),
      reason: z.string().trim().min(12).max(500),
      categories: z.array(supportCategorySchema).min(1).max(supportCategories.length)
    }).parse(request.data);
    const target = await db.doc(`users/${input.targetUid}`).get();
    if (!target.exists) throw new HttpsError("not-found", "Consumer was not found.");
    const grant = db.collection("platform_consumer_support_grants").doc();
    const expiresAt = Timestamp.fromMillis(Date.now() + 15 * 60_000);
    await grant.create({
      targetUid: input.targetUid,
      administratorUid: request.auth!.uid,
      reason: input.reason,
      categories: input.categories,
      status: "active",
      createdAt: FieldValue.serverTimestamp(),
      expiresAt
    });
    await db.doc(`users/${input.targetUid}/support_history/${grant.id}`).set({
      administratorUid: request.auth!.uid,
      reason: input.reason,
      categories: input.categories,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt
    });
    return { grantId: grant.id, expiresAt: expiresAt.toDate().toISOString() };
  }
);

export const getConsumerSupportData = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      grantId: z.string().min(1),
      targetUid: z.string().min(1),
      categories: z.array(supportCategorySchema).min(1).max(supportCategories.length)
    }).parse(request.data);
    const grant = await db.doc(`platform_consumer_support_grants/${input.grantId}`).get();
    if (!grant.exists) {
      throw new HttpsError("permission-denied", "The support grant is invalid or expired.");
    }
    const permitted = grant.get("categories") as string[] | undefined;
    if (grant.get("status") !== "active" ||
        grant.get("administratorUid") !== request.auth!.uid ||
        grant.get("targetUid") !== input.targetUid ||
        !(grant.get("expiresAt") as Timestamp | undefined) ||
        (grant.get("expiresAt") as Timestamp).toMillis() <= Date.now() ||
        input.categories.some((category) => !permitted?.includes(category))) {
      throw new HttpsError("permission-denied", "The support grant is invalid or expired.");
    }
    const result: Record<string, unknown> = {};
    if (input.categories.includes("account")) {
      const account = await db.doc(`users/${input.targetUid}`).get();
      result.account = account.data() ?? {};
    }
    if (input.categories.includes("onboarding")) {
      const profile = await db.doc(`users/${input.targetUid}/fitness_profile/current`).get();
      result.onboarding = safeProjection("profile", profile.data() ?? {});
    }
    if (input.categories.includes("sharing")) {
      const shares = await db.collection(`users/${input.targetUid}/gym_shares`).limit(50).get();
      result.sharing = shares.docs.map((document) => ({ id: document.id, ...document.data() }));
    }
    if (input.categories.includes("memberships")) {
      const memberships = await db.collection("gym_memberships")
        .where("uid", "==", input.targetUid).limit(50).get();
      result.memberships = memberships.docs.map((document) => ({ id: document.id, ...document.data() }));
    }
    if (input.categories.includes("usage")) {
      const [routines, workouts, measurements] = await Promise.all([
        db.collection(`users/${input.targetUid}/routines`).count().get(),
        db.collection(`users/${input.targetUid}/workout_logs`).count().get(),
        db.collection(`users/${input.targetUid}/measurements`).count().get()
      ]);
      result.usage = {
        routines: routines.data().count,
        workouts: workouts.data().count,
        measurements: measurements.data().count
      };
    }
    const audit = {
      grantId: input.grantId,
      targetUid: input.targetUid,
      administratorUid: request.auth!.uid,
      reason: grant.get("reason"),
      categories: input.categories,
      viewedAt: FieldValue.serverTimestamp()
    };
    const auditRef = db.collection("platform_consumer_support_audit").doc();
    await Promise.all([
      auditRef.create(audit),
      db.doc(`users/${input.targetUid}/support_history/${auditRef.id}`).create(audit)
    ]);
    return result;
  }
);

export const listConsumers = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({ limit: z.number().int().min(1).max(200).default(100) })
      .parse(request.data ?? {});
    const consumers = await db.collection("users").limit(input.limit).get();
    return {
      consumers: consumers.docs.map((document) => {
        const data = document.data();
        return {
          uid: document.id,
          displayName: data.displayName ?? null,
          email: data.email ?? null,
          phone: data.phone ?? null,
          status: data.status ?? "active",
          planId: data.consumerPlanId ?? "free",
          onboardingCompleted: Boolean(data.onboardingCompletedAt),
          lastSeenAt: data.lastSeenAt ?? null
        };
      })
    };
  }
);

export const setConsumerStatus = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      uid: z.string().min(1),
      status: z.enum(["active", "suspended"]),
      reason: z.string().trim().min(8).max(500)
    }).parse(request.data);
    await db.doc(`users/${input.uid}`).set({
      status: input.status,
      statusReason: input.reason,
      statusUpdatedBy: request.auth!.uid,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    if (input.status === "suspended") await getAuth().revokeRefreshTokens(input.uid);
    await db.collection("platform_consumer_audit").add({
      action: "consumer.status_updated",
      targetUid: input.uid,
      administratorUid: request.auth!.uid,
      status: input.status,
      reason: input.reason,
      createdAt: FieldValue.serverTimestamp()
    });
    return { uid: input.uid, status: input.status };
  }
);

export const setConsumerEntitlementOverrides = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      uid: z.string().min(1),
      overrides: z.record(z.string(), z.boolean()),
      reason: z.string().trim().min(8).max(500)
    }).parse(request.data);
    await db.doc(`users/${input.uid}/entitlements/current`).set({
      overrides: input.overrides,
      updatedBy: request.auth!.uid,
      updateReason: input.reason,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    await db.collection("platform_consumer_audit").add({
      action: "consumer.entitlements_updated",
      targetUid: input.uid,
      administratorUid: request.auth!.uid,
      overrides: input.overrides,
      reason: input.reason,
      createdAt: FieldValue.serverTimestamp()
    });
    return { uid: input.uid, overrides: input.overrides };
  }
);

export const updatePlatformBranding = onCall(
  { region: REGION, enforceAppCheck: ENFORCE_APP_CHECK },
  async (request) => {
    requirePlatformAdmin(request);
    const input = z.object({
      name: z.string().trim().min(2).max(80),
      logoUrl: z.string().url().nullable(),
      primaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
      secondaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
      accentColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
      termsUrl: z.string().url(),
      privacyUrl: z.string().url(),
      introduction: z.array(z.object({
        title: z.string().trim().min(2).max(100),
        body: z.string().trim().min(2).max(300),
        imageUrl: z.string().url().nullable()
      })).length(3),
      consumerFeatures: z.record(z.string(), z.boolean())
    }).parse(request.data);
    await db.doc("platform_public/app_branding").set({
      ...input,
      updatedBy: request.auth!.uid,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    return { updated: true };
  }
);

async function deleteConsumerData(uid: string) {
  const userRef = db.doc(`users/${uid}`);
  const collections = await userRef.listCollections();
  for (const collection of collections) {
    while (true) {
      const snapshot = await collection.limit(400).get();
      if (snapshot.empty) break;
      const batch = db.batch();
      snapshot.docs.forEach((document) => batch.delete(document.ref));
      await batch.commit();
    }
  }
  await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
  await userRef.delete();
  await getAuth().deleteUser(uid).catch((error: unknown) => {
    logger.warn("Auth user deletion failed after data deletion", { uid, error });
  });
}

export const purgeExpiredConsumerDeletionRequests = onSchedule(
  { region: REGION, schedule: "every day 02:30", timeZone: "Asia/Kolkata" },
  async () => {
    const requests = await db.collection("users")
      .where("status", "==", "deletion_requested")
      .where("deletionScheduledFor", "<=", Timestamp.now())
      .limit(100)
      .get();
    for (const account of requests.docs) {
      await deleteConsumerData(account.id);
    }
    logger.info("Expired consumer deletion requests purged", {
      count: requests.size
    });
  }
);
