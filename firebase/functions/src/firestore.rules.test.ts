import { readFileSync } from "node:fs";
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, Timestamp, updateDoc } from "firebase/firestore";
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
    await setDoc(doc(store, "users/member-a"), {
      uid: "member-a", displayName: "Member A", status: "active",
      ageConfirmedAt: Timestamp.now(), termsAcceptedAt: Timestamp.now(), termsVersion: "test"
    });
    await setDoc(doc(store, "users/member-b"), {
      uid: "member-b", displayName: "Member B", status: "active",
      ageConfirmedAt: Timestamp.now(), termsAcceptedAt: Timestamp.now(), termsVersion: "test"
    });
    await setDoc(doc(store, "users/unconsented-user"), {
      uid: "unconsented-user", status: "active"
    });
    await setDoc(doc(store, "users/suspended-user"), {
      uid: "suspended-user", status: "suspended"
    });
    await setDoc(doc(store, "users/member-a/workout_logs/log-a"), {
      ownerUid: "member-a", name: "Private workout"
    });
    await setDoc(doc(store, "users/member-a/gym_shares/gym-a"), {
      ownerUid: "member-a", gymId: "gym-a", categories: { workoutSummaries: false }
    });
    await setDoc(doc(store, "users/suspended-user/routines/routine-a"), {
      ownerUid: "suspended-user", name: "Blocked"
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
    await setDoc(doc(store, "gyms/gym-a/member_routines/member-b-routine"), {
      gymId: "gym-a", memberUid: "member-b", name: "Private routine", movements: []
    });
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
    await setDoc(doc(store, "gyms/gym-a/shared_fitness/member-a/workout_logs/log-a"), {
      sourceId: "log-a", name: "Shared summary"
    });
    await setDoc(doc(store, "gyms/gym-a/shared_fitness/member-a"), {
      uid: "member-a", gymId: "gym-a", categories: { workoutSummaries: true }
    });
    await setDoc(doc(store, "platform_feature_metrics/training"), {
      featureId: "training", totalEvents: 12
    });
    await setDoc(doc(store, "platform_feedback/feedback-a"), {
      gymId: "gym-a", uid: "member-a", rating: 5, message: "Useful"
    });
  });
});

afterAll(async () => environment.cleanup());

describe("Firestore tenant isolation", () => {
  it("keeps personal fitness private from other consumers and platform admins", async () => {
    const owner = environment.authenticatedContext("member-a").firestore();
    const other = environment.authenticatedContext("member-b").firestore();
    const admin = environment.authenticatedContext(
      "platform-admin", { platformAdmin: true }
    ).firestore();
    const record = doc(owner, "users/member-a/workout_logs/log-a");
    await assertSucceeds(getDoc(record));
    await assertFails(getDoc(doc(other, record.path)));
    await assertFails(getDoc(doc(admin, record.path)));
  });

  it("allows owner-scoped personal writes but rejects forged ownership", async () => {
    const owner = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(setDoc(doc(owner, "users/member-a/routines/own"), {
      ownerUid: "member-a", name: "Upper body", movements: []
    }));
    await assertFails(setDoc(doc(owner, "users/member-a/routines/forged"), {
      ownerUid: "member-b", name: "Forged", movements: []
    }));
    await assertFails(setDoc(doc(owner, "users/member-a/gym_shares/gym-a"), {
      ownerUid: "member-a", categories: { workoutSummaries: true }
    }));
  });

  it("blocks personal access for suspended consumers", async () => {
    const store = environment.authenticatedContext("suspended-user").firestore();
    await assertFails(getDoc(doc(store, "users/suspended-user/routines/routine-a")));
    await assertFails(setDoc(doc(store, "users/suspended-user/goals/goal-a"), {
      ownerUid: "suspended-user", name: "Blocked"
    }));
  });

  it("blocks personal fitness writes until age and policy consent", async () => {
    const store = environment.authenticatedContext("unconsented-user").firestore();
    await assertFails(setDoc(doc(store, "users/unconsented-user/routines/routine-a"), {
      ownerUid: "unconsented-user", name: "Too early", movements: []
    }));
  });

  it("exposes server-owned projections only inside the active gym", async () => {
    const trainer = environment.authenticatedContext("trainer-a").firestore();
    const outsider = environment.authenticatedContext("member-b").firestore();
    const path = "gyms/gym-a/shared_fitness/member-a/workout_logs/log-a";
    await assertSucceeds(getDoc(doc(trainer, path)));
    await assertFails(getDoc(doc(outsider, path)));
    await assertFails(setDoc(doc(trainer, path), { name: "Tampered" }));
  });

  it("immediately hides retained projections after the member leaves", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "gym_memberships/gym-a_member-a"), {
        status: "left"
      });
    });
    const trainer = environment.authenticatedContext("trainer-a").firestore();
    await assertFails(getDoc(doc(
      trainer,
      "gyms/gym-a/shared_fitness/member-a/workout_logs/log-a"
    )));
  });

  it("hides projections as soon as the server writes the revocation tombstone", async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "gyms/gym-a/shared_fitness/member-a"), {
        revokedAt: Timestamp.now()
      });
    });
    const trainer = environment.authenticatedContext("trainer-a").firestore();
    await assertFails(getDoc(doc(
      trainer,
      "gyms/gym-a/shared_fitness/member-a/workout_logs/log-a"
    )));
  });

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

  it("allows a member to complete only their own recommendation profile", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(updateDoc(doc(store, "gyms/gym-a/members/member-a"), {
      displayName: "Member A",
      experienceLevel: "beginner",
      fitnessGoals: ["improveFitness"],
      workoutDaysPerWeek: 3,
      equipmentAccess: ["fullGym"],
      photoPath: "gyms/gym-a/profiles/member-a/avatar.jpg",
      updatedAt: Timestamp.now()
    }));
    await assertFails(updateDoc(doc(store, "gyms/gym-a/members/member-a"), {
      role: "owner"
    }));
  });

  it("allows member routines without permitting ownership takeover", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    const own = doc(store, "gyms/gym-a/member_routines/member-a-routine");
    await assertSucceeds(setDoc(own, {
      gymId: "gym-a", memberUid: "member-a", name: "Push day", movements: []
    }));
    await assertSucceeds(updateDoc(own, { name: "Updated push day" }));
    await assertFails(updateDoc(
      doc(store, "gyms/gym-a/member_routines/member-b-routine"),
      { memberUid: "member-a", name: "Taken over" }
    ));
    await assertSucceeds(deleteDoc(own));
  });

  it("keeps product analytics and feedback private to platform administrators", async () => {
    const member = environment.authenticatedContext("member-a").firestore();
    const admin = environment.authenticatedContext(
      "platform-admin", { platformAdmin: true }
    ).firestore();
    await assertFails(getDoc(doc(member, "platform_feature_metrics/training")));
    await assertFails(getDoc(doc(member, "platform_feedback/feedback-a")));
    await assertSucceeds(getDoc(doc(admin, "platform_feature_metrics/training")));
    await assertSucceeds(getDoc(doc(admin, "platform_feedback/feedback-a")));
  });
});

describe("Storage tenant isolation", () => {
  it("keeps personal media private and blocks suspended accounts", async () => {
    const image = new Uint8Array([137, 80, 78, 71]);
    const owner = environment.authenticatedContext("member-a").storage();
    const other = environment.authenticatedContext("member-b").storage();
    const admin = environment.authenticatedContext(
      "platform-admin", { platformAdmin: true }
    ).storage();
    const suspended = environment.authenticatedContext("suspended-user").storage();
    const path = "users/member-a/progress/photo.png";
    await assertSucceeds(uploadBytes(ref(owner, path), image, { contentType: "image/png" }));
    await assertSucceeds(getBytes(ref(owner, path)));
    await assertFails(getBytes(ref(other, path)));
    await assertFails(getBytes(ref(admin, path)));
    await assertFails(uploadBytes(
      ref(suspended, "users/suspended-user/progress/photo.png"), image,
      { contentType: "image/png" }
    ));
  });

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

  it("allows profile images only in the member's own tenant path", async () => {
    const storage = environment.authenticatedContext("member-a").storage();
    const image = new Uint8Array([137, 80, 78, 71]);
    await assertSucceeds(uploadBytes(
      ref(storage, "gyms/gym-a/profiles/member-a/avatar.png"), image,
      { contentType: "image/png" }
    ));
    await assertFails(uploadBytes(
      ref(storage, "gyms/gym-a/profiles/member-b/avatar.png"), image,
      { contentType: "image/png" }
    ));
  });
});
