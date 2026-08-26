import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { ROLE_PERMISSIONS } from "./config";

initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? "demo-gym-dev" });
const db = getFirestore();
const auth = getAuth();

const exercises = [
  ["Barbell Bench Press", "Chest"],
  ["Push-up", "Chest"],
  ["Deadlift", "Back"],
  ["Pull-up", "Back"],
  ["Barbell Back Squat", "Legs"],
  ["Romanian Deadlift", "Legs"],
  ["Overhead Press", "Shoulders"],
  ["Dumbbell Curl", "Arms"],
  ["Plank", "Core"],
  ["Burpee", "Full Body"]
];

async function seed() {
  if (!process.env.FIRESTORE_EMULATOR_HOST && process.env.SEED_CONFIRM_PRODUCTION !== "true") {
    throw new Error("Refusing to seed outside the Emulator Suite. Set SEED_CONFIRM_PRODUCTION=true explicitly.");
  }
  const gymId = "pilot-gym";
  const admin = await ensureUser("platform.admin@example.com", "LocalAdmin!2026", "Platform Admin");
  const owner = await ensureUser("owner@pilotgym.example.com", "PilotOwner!2026", "Pilot Owner");
  const trainer = await ensureUser("trainer@pilotgym.example.com", "PilotTrainer!2026", "Pilot Trainer");
  const member = await ensureUser("member@pilotgym.example.com", "PilotMember!2026", "Pilot Member");
  await auth.setCustomUserClaims(admin.uid, { platformAdmin: true });
  const ownerUid = owner.uid;
  const batch = db.batch();
  batch.set(db.doc(`gyms/${gymId}`), {
    name: "Pilot Fitness",
    status: "trial",
    platformPlan: "trial",
    currency: "INR",
    timezone: "Asia/Kolkata",
    locale: "en-IN",
    branding: { primaryColor: "#2563EB", secondaryColor: "#0F172A" },
    features: {
      classes: true,
      chat: true,
      attendanceQr: true,
      dietPlans: true,
      progressPhotos: true
    },
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });
  for (const [user, role] of [[owner, "owner"], [trainer, "trainer"], [member, "member"]] as const) {
    batch.set(db.doc(`gym_memberships/${gymId}_${user.uid}`), {
      gymId, uid: user.uid, role, status: "active", permissions: ROLE_PERMISSIONS[role],
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()
    });
    batch.set(db.doc(`gyms/${gymId}/${role === "member" ? "members" : "staff"}/${user.uid}`), {
      gymId, uid: user.uid, displayName: user.displayName, email: user.email, role, status: "active",
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()
    });
  }
  batch.set(db.doc(`gyms/${gymId}/dashboard_metrics/current`), {
    activeMembers: 1, expiringSoon: 0, todayAttendance: 0, monthlyRevenueMinor: 0,
    updatedAt: FieldValue.serverTimestamp()
  });
  batch.set(db.doc(`gyms/${gymId}/membership_plans/monthly`), {
    gymId,
    name: "Monthly Unlimited",
    description: "Full gym access for 30 days",
    durationDays: 30,
    priceMinor: 149900,
    currency: "INR",
    status: "active",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });
  batch.set(db.doc(`gyms/${gymId}/membership_plans/quarterly`), {
    gymId,
    name: "Quarterly Value",
    description: "Full gym access for 90 days",
    durationDays: 90,
    priceMinor: 399900,
    currency: "INR",
    status: "active",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });
  batch.set(db.doc(`gyms/${gymId}/membership_plans/annual`), {
    gymId,
    name: "Annual Pro",
    description: "Full gym access for 365 days",
    durationDays: 365,
    priceMinor: 1299900,
    currency: "INR",
    status: "active",
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp()
  });
  const subscriptionEnd = Date.now() + 5 * 86400000;
  batch.set(db.doc(`gyms/${gymId}/subscriptions/${member.uid}`), {
    gymId, memberUid: member.uid, memberName: member.displayName,
    status: "active", planId: "monthly", planName: "Monthly Unlimited",
    currency: "INR",
    startAt: Timestamp.fromMillis(Date.now() - 25 * 86400000),
    endAt: Timestamp.fromMillis(subscriptionEnd),
    lastPaymentId: "pilot-payment",
    lastPaymentAmountMinor: 149900,
    updatedAt: FieldValue.serverTimestamp()
  });
  batch.set(db.doc(`gyms/${gymId}/payments/pilot-payment`), {
    gymId,
    memberUid: member.uid,
    memberName: member.displayName,
    planId: "monthly",
    planName: "Monthly Unlimited",
    receiptNumber: "PAY-PILOT001",
    status: "paid",
    amountMinor: 149900,
    listPriceMinor: 149900,
    currency: "INR",
    method: "upi",
    reference: "DEMO-UPI-001",
    durationDays: 30,
    paidAt: Timestamp.fromMillis(Date.now() - 25 * 86400000),
    subscriptionStartsAt: Timestamp.fromMillis(Date.now() - 25 * 86400000),
    subscriptionEndsAt: Timestamp.fromMillis(subscriptionEnd),
    createdAt: FieldValue.serverTimestamp()
  });
  batch.set(db.doc(`gyms/${gymId}/notifications/pilot-expiry-reminder`), {
    gymId,
    recipientUid: member.uid,
    type: "subscription_expiry",
    title: "Membership expiring soon",
    body: "Your membership expires in 5 days.",
    data: { endAtMillis: subscriptionEnd, daysRemaining: 5 },
    read: false,
    createdAt: FieldValue.serverTimestamp()
  });
  for (const [name, muscleGroup] of exercises) {
    const ref = db.collection(`gyms/${gymId}/exercises`).doc();
    batch.set(ref, {
      gymId,
      name,
      muscleGroup,
      description: `${name} exercise`,
      createdAt: FieldValue.serverTimestamp()
    });
  }
  await batch.commit();
  console.log(`Seeded ${gymId}`);
}

async function ensureUser(email: string, password: string, displayName: string) {
  try {
    return await auth.getUserByEmail(email);
  } catch {
    return auth.createUser({ email, password, displayName, emailVerified: true });
  }
}

seed().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
