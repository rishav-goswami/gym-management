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
  bookingDocumentId,
  hashToken,
  membershipDocumentId,
  normalizeEmail,
  normalizePhone,
  secureToken
} from "./domain";

initializeApp();
const db = getFirestore();

const gymSchema = z.object({
  name: z.string().min(2).max(100),
  ownerUid: z.string().min(1),
  currency: z.string().length(3).default("INR"),
  timezone: z.string().default("Asia/Kolkata"),
  locale: z.string().default("en-IN")
});

export const provisionGym = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    requirePlatformAdmin(request);
    const input = gymSchema.parse(request.data);
    const gymRef = db.collection("gyms").doc();
    const membershipRef = db.doc(
      `gym_memberships/${membershipDocumentId(gymRef.id, input.ownerUid)}`
    );
    const now = FieldValue.serverTimestamp();

    await db.runTransaction(async (tx) => {
      tx.create(gymRef, {
        name: input.name,
        status: "trial",
        platformPlan: "trial",
        platformPlanEndsAt: Timestamp.fromMillis(Date.now() + 30 * 86400000),
        currency: input.currency,
        timezone: input.timezone,
        locale: input.locale,
        branding: { primaryColor: "#2563EB", secondaryColor: "#0F172A" },
        features: {
          classes: true,
          chat: true,
          attendanceQr: true,
          dietPlans: true,
          progressPhotos: true
        },
        createdAt: now,
        updatedAt: now
      });
      tx.create(membershipRef, {
        gymId: gymRef.id,
        uid: input.ownerUid,
        role: "owner",
        status: "active",
        permissions: ROLE_PERMISSIONS.owner,
        createdAt: now,
        updatedAt: now
      });
      tx.create(db.doc(`gyms/${gymRef.id}/staff/${input.ownerUid}`), {
        gymId: gymRef.id,
        uid: input.ownerUid,
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
    });

    await writeAudit(db, gymRef.id, request.auth!.uid, "gym.provisioned", {
      gymId: gymRef.id,
      ownerUid: input.ownerUid
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
  { region: REGION, enforceAppCheck: true },
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
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    requireAuth(request);
    const { gymId, token } = z.object({ gymId: z.string(), token: z.string().min(20) }).parse(request.data);
    const inviteRef = db.doc(`gyms/${gymId}/invitations/${hashToken(token)}`);
    const memberRef = db.doc(
      `gym_memberships/${membershipDocumentId(gymId, request.auth.uid)}`
    );
    await db.runTransaction(async (tx) => {
      const invite = await tx.get(inviteRef);
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
    return { gymId };
  }
);

export const updateGymStatus = onCall(
  { region: REGION, enforceAppCheck: true },
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

export const updateGymConfiguration = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const input = z.object({
      gymId: z.string().min(1),
      name: z.string().min(2).max(100).optional(),
      currency: z.string().length(3).optional(),
      timezone: z.string().min(1).optional(),
      locale: z.string().min(2).optional(),
      primaryColor: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
      logoUrl: z.string().url().optional(),
      features: z.object({
        classes: z.boolean(),
        chat: z.boolean(),
        attendanceQr: z.boolean(),
        dietPlans: z.boolean(),
        progressPhotos: z.boolean()
      }).optional()
    }).parse(request.data);
    await requireGymPermission(request, input.gymId, "staff.manage");
    const branding: Record<string, string> = {};
    if (input.primaryColor) branding.primaryColor = input.primaryColor;
    if (input.logoUrl) branding.logoUrl = input.logoUrl;
    await db.doc(`gyms/${input.gymId}`).set({
      ...(input.name ? { name: input.name } : {}),
      ...(input.currency ? { currency: input.currency } : {}),
      ...(input.timezone ? { timezone: input.timezone } : {}),
      ...(input.locale ? { locale: input.locale } : {}),
      ...(Object.keys(branding).length ? { branding } : {}),
      ...(input.features ? { features: input.features } : {}),
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    await writeAudit(db, input.gymId, request.auth!.uid, "gym.configuration_updated", {});
    return { updated: true };
  }
);

export const updateGymMembership = onCall(
  { region: REGION, enforceAppCheck: true },
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
    const profileCollection = input.role === "member" ? "members" : "staff";
    const oldProfileCollection = oldRole === "member" ? "members" : "staff";
    const batch = db.batch();
    batch.update(targetRef, {
      role: input.role,
      status: input.status,
      permissions,
      permissionOverrides,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth!.uid
    });
    batch.set(db.doc(`gyms/${input.gymId}/${profileCollection}/${input.uid}`), {
      gymId: input.gymId,
      uid: input.uid,
      role: input.role,
      status: input.status,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });
    if (oldProfileCollection !== profileCollection) {
      batch.delete(db.doc(`gyms/${input.gymId}/${oldProfileCollection}/${input.uid}`));
    }
    const wasActiveMember = oldRole === "member" && target.get("status") === "active";
    const isActiveMember = input.role === "member" && input.status === "active";
    if (wasActiveMember !== isActiveMember) {
      batch.set(db.doc(`gyms/${input.gymId}/dashboard_metrics/current`), {
        activeMembers: FieldValue.increment(isActiveMember ? 1 : -1),
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    }
    await batch.commit();
    await writeAudit(db, input.gymId, request.auth!.uid, "membership.updated", {
      uid: input.uid,
      role: input.role,
      status: input.status,
      permissionOverrides
    });
    return { updated: true };
  }
);

const paymentSchema = z.object({
  gymId: z.string(),
  memberUid: z.string(),
  planId: z.string(),
  amountMinor: z.number().int().nonnegative(),
  method: z.enum(["cash", "upi", "card", "bank_transfer", "other"]),
  paidAtMillis: z.number().int(),
  startsAtMillis: z.number().int(),
  endsAtMillis: z.number().int(),
  reference: z.string().max(120).optional()
});

export const recordPayment = onCall(
  { region: REGION, enforceAppCheck: true },
  async (request) => {
    const input = paymentSchema.parse(request.data);
    const { gym } = await requireGymPermission(request, input.gymId, "payments.write");
    const paymentRef = db.collection(`gyms/${input.gymId}/payments`).doc();
    const subscriptionRef = db.doc(`gyms/${input.gymId}/subscriptions/${input.memberUid}`);
    await db.runTransaction(async (tx) => {
      tx.create(paymentRef, {
        ...input,
        currency: gym.currency ?? "INR",
        recordedBy: request.auth!.uid,
        paidAt: Timestamp.fromMillis(input.paidAtMillis),
        createdAt: FieldValue.serverTimestamp()
      });
      tx.set(subscriptionRef, {
        gymId: input.gymId,
        memberUid: input.memberUid,
        planId: input.planId,
        status: "active",
        startAt: Timestamp.fromMillis(input.startsAtMillis),
        endAt: Timestamp.fromMillis(input.endsAtMillis),
        lastPaymentId: paymentRef.id,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });
    });
    await writeAudit(db, input.gymId, request.auth!.uid, "payment.recorded", {
      paymentId: paymentRef.id,
      memberUid: input.memberUid,
      amountMinor: input.amountMinor
    });
    return { paymentId: paymentRef.id };
  }
);

export const createAttendanceQr = onCall(
  { region: REGION, enforceAppCheck: true },
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
  { region: REGION, enforceAppCheck: true },
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
  { region: REGION, enforceAppCheck: true },
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
  { region: REGION, enforceAppCheck: true },
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
  { region: REGION, enforceAppCheck: true },
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
  { region: REGION, enforceAppCheck: true },
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
    const expiring = await db.collectionGroup("subscriptions")
      .where("status", "==", "active")
      .where("endAt", "<=", cutoff)
      .get();
    for (const subscription of expiring.docs) {
      const data = subscription.data();
      if (data.endAt.toMillis() < now) continue;
      const notificationId = `expiry_${subscription.id}_${data.endAt.toMillis()}`;
      const notificationRef = subscription.ref.parent.parent!.collection("notifications").doc(notificationId);
      if ((await notificationRef.get()).exists) continue;
      await notificationRef.create({
        gymId: data.gymId,
        recipientUid: data.memberUid,
        type: "subscription_expiry",
        title: "Membership expiring soon",
        body: "Contact your gym to renew your membership.",
        read: false,
        createdAt: FieldValue.serverTimestamp()
      });
      await sendPush(data.memberUid, "Membership expiring soon", "Contact your gym to renew your membership.", {
        gymId: String(data.gymId),
        type: "subscription_expiry"
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
  { region: REGION, enforceAppCheck: true },
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
  { region: REGION, enforceAppCheck: true },
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
