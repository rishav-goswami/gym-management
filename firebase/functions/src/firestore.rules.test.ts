import { readFileSync } from "node:fs";
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, Timestamp, updateDoc } from "firebase/firestore";
import { getBytes, ref, uploadBytes } from "firebase/storage";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

let environment: RulesTestEnvironment;

beforeAll(async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-gym-dev",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
    storage: { rules: readFileSync("../storage.rules", "utf8") }
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.clearStorage();
  await environment.withSecurityRulesDisabled(async (context) => {
    const store = context.firestore();
    await setDoc(doc(store, "gyms/gym-a"), { name: "Gym A", status: "active" });
    await setDoc(doc(store, "gyms/gym-b"), { name: "Gym B", status: "active" });
    await setDoc(doc(store, "gyms/gym-suspended"), { name: "Suspended", status: "suspended" });
    await setDoc(doc(store, "gyms/gym-expired"), {
      name: "Expired Trial", status: "trial", platformPlanEndsAt: Timestamp.fromMillis(Date.now() - 1000)
    });
    await setDoc(doc(store, "saas_plans/trial"), {
      name: "Free trial", status: "active", isPublic: true, isTrial: true
    });
    await setDoc(doc(store, "gym_memberships/gym-a_member-a"), {
      gymId: "gym-a", uid: "member-a", role: "member", status: "active", permissions: { "fitness.read": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-b_member-b"), {
      gymId: "gym-b", uid: "member-b", role: "member", status: "active", permissions: { "fitness.read": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-suspended_member-a"), {
      gymId: "gym-suspended", uid: "member-a", role: "member", status: "active", permissions: { "fitness.read": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-expired_member-a"), {
      gymId: "gym-expired", uid: "member-a", role: "member", status: "active", permissions: {}
    });
    await setDoc(doc(store, "gym_memberships/gym-a_owner-a"), {
      gymId: "gym-a", uid: "owner-a", role: "owner", status: "active",
      permissions: { "plans.manage": true, "payments.write": true, "payments.read": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-a_trainer-a"), {
      gymId: "gym-a", uid: "trainer-a", role: "trainer", status: "active",
      permissions: { "fitness.manage": true }
    });
    await setDoc(doc(store, "gyms/gym-a/members/member-a"), { memberUid: "member-a", name: "A" });
    await setDoc(doc(store, "gyms/gym-b/members/member-b"), { memberUid: "member-b", name: "B" });
    await setDoc(doc(store, "gyms/gym-a/workout_assignments/assignment-a"), { memberUid: "member-a" });
    await setDoc(doc(store, "gyms/gym-a/workout_assignments/assignment-other"), { memberUid: "member-b" });
    await setDoc(doc(store, "gyms/gym-a/subscriptions/member-a"), {
      gymId: "gym-a", memberUid: "member-a", status: "active"
    });
    await setDoc(doc(store, "gyms/gym-a/subscriptions/member-b"), {
      gymId: "gym-a", memberUid: "member-b", status: "active"
    });
    await setDoc(doc(store, "gyms/gym-a/payments/payment-a"), {
      gymId: "gym-a", memberUid: "member-a", amountMinor: 100
    });
    await setDoc(doc(store, "gyms/gym-a/payments/payment-b"), {
      gymId: "gym-a", memberUid: "member-b", amountMinor: 100
    });
    await setDoc(doc(store, "gyms/gym-a/renewal_requests/member-a"), {
      gymId: "gym-a", memberUid: "member-a", status: "pending"
    });
    await setDoc(doc(store, "gyms/gym-a/notifications/reminder-a"), {
      gymId: "gym-a", recipientUid: "member-a", read: false
    });
  });
});

afterAll(async () => environment.cleanup());

describe("Firestore tenant isolation", () => {
  it("lets a member read their own tenant profile", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(getDoc(doc(store, "gyms/gym-a/members/member-a")));
  });

  it("rejects a cross-tenant profile read", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertFails(getDoc(doc(store, "gyms/gym-b/members/member-b")));
  });

  it("does not let the member fitness permission expose another member plan", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(getDoc(doc(store, "gyms/gym-a/workout_assignments/assignment-a")));
    await assertFails(getDoc(doc(store, "gyms/gym-a/workout_assignments/assignment-other")));
  });

  it("blocks all tenant access while a gym is suspended", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertFails(getDoc(doc(store, "gyms/gym-suspended")));
  });

  it("blocks tenant access after a trial expires", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertFails(getDoc(doc(store, "gyms/gym-expired")));
  });

  it("does not allow client-side membership privilege escalation", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertFails(setDoc(doc(store, "gym_memberships/gym-a_member-a"), {
      gymId: "gym-a", uid: "member-a", role: "owner", status: "active"
    }));
  });

  it("keeps plans and payments behind privileged Functions", async () => {
    const store = environment.authenticatedContext("owner-a").firestore();
    await assertFails(setDoc(doc(store, "gyms/gym-a/membership_plans/monthly"), {
      gymId: "gym-a", name: "Unsafe client plan", durationDays: 30, priceMinor: 1
    }));
    await assertFails(setDoc(doc(store, "gyms/gym-a/payments/fake"), {
      gymId: "gym-a", memberUid: "owner-a", amountMinor: 1
    }));
  });

  it("allows signed-in plan discovery but denies all client plan and quota writes", async () => {
    const owner = environment.authenticatedContext("owner-a").firestore();
    await assertSucceeds(getDoc(doc(owner, "saas_plans/trial")));
    await assertFails(setDoc(doc(owner, "saas_plans/trial"), { status: "inactive" }));
    await assertFails(setDoc(doc(owner, "gyms/gym-a/usage/current"), { activeMembers: 0 }));
    await assertFails(setDoc(doc(owner, "gyms/gym-a/class_sessions/forged"), {
      gymId: "gym-a", name: "Bypass", capacity: 999
    }));
    await assertFails(setDoc(doc(owner, "gyms/gym-a/members/forged"), {
      gymId: "gym-a", uid: "forged", status: "active"
    }));
  });

  it("lets members read only their own billing records", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(getDoc(doc(store, "gyms/gym-a/subscriptions/member-a")));
    await assertFails(getDoc(doc(store, "gyms/gym-a/subscriptions/member-b")));
    await assertSucceeds(getDoc(doc(store, "gyms/gym-a/payments/payment-a")));
    await assertFails(getDoc(doc(store, "gyms/gym-a/payments/payment-b")));
    await assertSucceeds(getDoc(doc(store, "gyms/gym-a/renewal_requests/member-a")));
  });

  it("allows read acknowledgement but blocks forged reminders and renewal requests", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(updateDoc(doc(store, "gyms/gym-a/notifications/reminder-a"), {
      read: true
    }));
    await assertFails(setDoc(doc(store, "gyms/gym-a/notifications/fake"), {
      gymId: "gym-a", recipientUid: "member-a", title: "Fake"
    }));
    await assertFails(setDoc(doc(store, "gyms/gym-a/renewal_requests/forged"), {
      gymId: "gym-a", memberUid: "member-a", status: "paid"
    }));
  });
});

describe("Storage tenant isolation", () => {
  it("allows only platform admins and owner/managers to upload gym branding", async () => {
    const image = new Uint8Array([137, 80, 78, 71]);
    const ownerStorage = environment.authenticatedContext("owner-a").storage();
    const trainerStorage = environment.authenticatedContext("trainer-a").storage();
    const memberStorage = environment.authenticatedContext("member-a").storage();
    const platformStorage = environment.authenticatedContext(
      "platform-admin", { platformAdmin: true }
    ).storage();
    await assertSucceeds(uploadBytes(
      ref(ownerStorage, "gyms/gym-a/branding/owner-logo.png"), image,
      { contentType: "image/png" }
    ));
    await assertSucceeds(uploadBytes(
      ref(platformStorage, "gyms/gym-a/branding/platform-logo.png"), image,
      { contentType: "image/png" }
    ));
    await assertFails(uploadBytes(
      ref(trainerStorage, "gyms/gym-a/branding/trainer-logo.png"), image,
      { contentType: "image/png" }
    ));
    await assertFails(uploadBytes(
      ref(memberStorage, "gyms/gym-a/branding/member-logo.png"), image,
      { contentType: "image/png" }
    ));
  });

  it("allows signed-in reads but no client writes for platform exercise media", async () => {
    const path = "platform/exercise-media/v1/Pushups/0.jpg";
    await environment.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), path), new Uint8Array([1, 2, 3]), {
        contentType: "image/jpeg"
      });
    });
    const memberStorage = environment.authenticatedContext("member-a").storage();
    const publicStorage = environment.unauthenticatedContext().storage();
    await assertSucceeds(getBytes(ref(memberStorage, path)));
    await assertFails(getBytes(ref(publicStorage, path)));
    await assertFails(uploadBytes(
      ref(memberStorage, "platform/exercise-media/v1/Pushups/1.jpg"),
      new Uint8Array([1]),
      { contentType: "image/jpeg" }
    ));
  });

  it("allows a member to upload a small image only to their own progress path", async () => {
    const storage = environment.authenticatedContext("member-a").storage();
    const image = new Uint8Array([137, 80, 78, 71]);
    await assertSucceeds(uploadBytes(
      ref(storage, "gyms/gym-a/progress/member-a/photo.png"),
      image,
      { contentType: "image/png" }
    ));
    await assertFails(uploadBytes(
      ref(storage, "gyms/gym-a/progress/member-b/photo.png"),
      image,
      { contentType: "image/png" }
    ));
    await assertFails(uploadBytes(
      ref(storage, "gyms/gym-b/progress/member-a/photo.png"),
      image,
      { contentType: "image/png" }
    ));
  });
});
