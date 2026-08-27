import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  Timestamp,
  getFirestore
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
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
    await writeAudit(db, gymRef.id, request.auth.uid, "gym.self_service_trial_started", {});
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
    const entitlementRef = db.doc(`gyms/${gymId}/entitlements/current`);
    const usageRef = db.doc(`gyms/${gymId}/usage/current`);
    try {
      await db.runTransaction(async (tx) => {
      const [invite, entitlement, usage] = await Promise.all([
        tx.get(inviteRef), tx.get(entitlementRef), tx.get(usageRef)
      ]);
      if (!invite.exists || invite.get("status") !== "pending") {
        throw new HttpsError("not-found", "Invitation is invalid or already used.");
      }
      if (invite.get("expiresAt").toMillis() <= Date.now()) {
        throw new HttpsError("deadline-exceeded", "Invitation has expired.");
      }
      const tokenEmail = request.auth!.token.email ? normalizeEmail(String(request.auth!.token.email)) : null;
      const tokenPhone = request.auth!.token.phone_number ? normalizePhone(String(request.auth!.token.phone_number)) : null;
      if ((invite.get("email") && invite.get("email") !== tokenEmail) ||
          (invite.get("phone") && invite.get("phone") !== tokenPhone)) {
        throw new HttpsError("permission-denied", "Invitation does not match this account.");
      }
      const role = String(invite.get("role"));
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
      tx.create(memberRef, {
        gymId,
        uid: request.auth!.uid,
        role,
        status: "active",
        permissions: ROLE_PERMISSIONS[role] ?? {},
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
      });
      const profileCollection = role === "member" ? "members" : "staff";
      tx.set(db.doc(`gyms/${gymId}/${profileCollection}/${request.auth!.uid}`), {
        gymId,
        uid: request.auth!.uid,
        role,
        status: "active",
        email: tokenEmail,
        phone: tokenPhone,
        createdAt: FieldValue.serverTimestamp(),
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
        email: tokenEmail,
        phone: tokenPhone,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
      });
    } catch (error) {
      quotaError(error);
    }
    return { gymId };
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
          updatedAt: FieldValue.serverTimestamp(), updatedBy: request.auth!.uid
        });
        tx.set(db.doc(`gyms/${input.gymId}/${profileCollection}/${input.uid}`), {
          gymId: input.gymId, uid: input.uid, role: input.role, status: input.status,
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
    const gymData = [];
    const memberCollections = [
      "subscriptions", "payments", "attendance", "class_bookings",
      "workout_assignments", "diet_assignments", "goals", "measurements",
      "personal_records", "workout_logs", "progress_photos"
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
    await getAuth().revokeRefreshTokens(request.auth.uid);
    await getAuth().updateUser(request.auth.uid, { disabled: true });
    return { requested: true, deletionAfterDays: 30 };
  }
);
