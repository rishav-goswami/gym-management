import { readFileSync } from "node:fs";
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import {
  collection, deleteDoc, doc, getDoc, getDocs, limit, orderBy, query,
  setDoc, Timestamp, updateDoc, where, type Firestore
} from "firebase/firestore";
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
    await setDoc(doc(store, "gym_memberships/gym-a_suspended-user"), {
      gymId: "gym-a", uid: "suspended-user", role: "member", status: "active",
      permissions: { "fitness.read": true }
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
      permissions: {
        "plans.manage": true, "payments.write": true, "payments.read": true
      }
    });
    await setDoc(doc(store, "gym_memberships/gym-a_restricted-owner"), {
      gymId: "gym-a", uid: "restricted-owner", role: "owner", status: "active",
      permissions: { "support.manage": false }
    });
    await setDoc(doc(store, "gym_memberships/gym-a_trainer-a"), {
      gymId: "gym-a", uid: "trainer-a", role: "trainer", status: "active",
      permissions: { "fitness.manage": true, "support.coaching": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-a_reception-a"), {
      gymId: "gym-a", uid: "reception-a", role: "receptionist", status: "active",
      permissions: { "support.manage": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-a_accountant-a"), {
      gymId: "gym-a", uid: "accountant-a", role: "accountant", status: "active",
      permissions: { "support.billing": true }
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
    await setDoc(doc(store, "gyms/gym-a/trainer_assignments/member-a"), {
      gymId: "gym-a", memberUid: "member-a", primaryTrainerUid: "trainer-a", status: "active"
    });
    await setDoc(doc(store, "gyms/gym-a/support_threads/coaching-a"), {
      gymId: "gym-a", memberUid: "member-a", category: "coaching", status: "open",
      lastMessageAt: Timestamp.now()
    });
    await setDoc(doc(store, "gyms/gym-a/support_threads/operations-a"), {
      gymId: "gym-a", memberUid: "member-a", category: "attendance", status: "open",
      lastMessageAt: Timestamp.now()
    });
    await setDoc(doc(store, "gyms/gym-a/support_threads/payment-a"), {
      gymId: "gym-a", memberUid: "member-a", category: "payment", status: "open",
      lastMessageAt: Timestamp.now()
    });
    await setDoc(doc(store, "gyms/gym-a/support_threads/coaching-a/messages/message-a"), {
      gymId: "gym-a", threadId: "coaching-a", senderUid: "member-a", text: "Help"
    });
    await setDoc(doc(store, "users/member-a/support_cases/case-a"), {
      caseId: "case-a", targetUid: "member-a", category: "account", subject: "Login", status: "open"
    });
    await setDoc(doc(store, "users/member-a/support_cases/case-a/messages/message-a"), {
      senderUid: "member-a", text: "Help"
    });
    await setDoc(doc(store, "users/member-a/support_inbox/platform_case-a"), {
      scopeType: "platform", threadId: "case-a", unread: true
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
    const suspended = environment.authenticatedContext("suspended-user").firestore();
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

  it("routes gym support reads by member identity and staff permissions", async () => {
    const member = environment.authenticatedContext("member-a").firestore();
    const trainer = environment.authenticatedContext("trainer-a").firestore();
    const reception = environment.authenticatedContext("reception-a").firestore();
    const accountant = environment.authenticatedContext("accountant-a").firestore();
    const owner = environment.authenticatedContext("owner-a").firestore();
    const restrictedOwner = environment
      .authenticatedContext("restricted-owner")
      .firestore();
    const outsider = environment.authenticatedContext("member-b").firestore();
    const suspended = environment
      .authenticatedContext("suspended-user")
      .firestore();
    await assertSucceeds(getDoc(doc(member, "gyms/gym-a/support_threads/coaching-a")));
    await assertSucceeds(getDoc(doc(trainer, "gyms/gym-a/support_threads/coaching-a")));
    await assertFails(getDoc(doc(trainer, "gyms/gym-a/support_threads/operations-a")));
    await assertSucceeds(getDoc(doc(reception, "gyms/gym-a/support_threads/operations-a")));
    await assertFails(getDoc(doc(reception, "gyms/gym-a/support_threads/payment-a")));
    await assertSucceeds(getDoc(doc(accountant, "gyms/gym-a/support_threads/payment-a")));
    await assertFails(getDoc(doc(accountant, "gyms/gym-a/support_threads/coaching-a")));
    await assertSucceeds(getDoc(doc(owner, "gyms/gym-a/support_threads/coaching-a")));
    await assertSucceeds(getDoc(doc(owner, "gyms/gym-a/support_threads/operations-a")));
    await assertSucceeds(getDoc(doc(owner, "gyms/gym-a/support_threads/payment-a")));
    await assertFails(getDoc(doc(
      restrictedOwner,
      "gyms/gym-a/support_threads/operations-a"
    )));
    await assertFails(getDoc(doc(outsider, "gyms/gym-a/support_threads/coaching-a")));
    await assertFails(getDoc(doc(suspended, "gyms/gym-a/support_threads/coaching-a")));
    await assertFails(setDoc(doc(member, "gyms/gym-a/support_threads/forged"), {
      gymId: "gym-a", memberUid: "member-a", category: "coaching"
    }));
    await assertFails(setDoc(doc(
      member,
      "gyms/gym-a/support_threads/coaching-a/messages/forged"
    ), { senderUid: "member-a", text: "Bypass" }));
  });

  it("allows bounded inbox queries only for categories the helper can handle", async () => {
    const owner = environment.authenticatedContext("owner-a").firestore();
    const trainer = environment.authenticatedContext("trainer-a").firestore();
    const reception = environment.authenticatedContext("reception-a").firestore();
    const accountant = environment.authenticatedContext("accountant-a").firestore();
    const bounded = (store: Firestore, categories: string[]) => query(
      collection(store, "gyms/gym-a/support_threads"),
      where("category", "in", categories),
      orderBy("lastMessageAt", "desc"),
      limit(50)
    );

    await assertSucceeds(getDocs(bounded(owner, [
      "coaching", "payment", "membership", "attendance", "classes", "facility", "other"
    ])));
    await assertSucceeds(getDocs(bounded(trainer, ["coaching"])));
    await assertSucceeds(getDocs(bounded(reception, [
      "membership", "attendance", "classes", "facility", "other"
    ])));
    await assertSucceeds(getDocs(bounded(accountant, ["payment"])));
    await assertFails(getDocs(bounded(trainer, ["coaching", "attendance"])));
  });

  it("keeps platform cases user-scoped while allowing audited operator work", async () => {
    const owner = environment.authenticatedContext("member-a").firestore();
    const other = environment.authenticatedContext("member-b").firestore();
    const admin = environment.authenticatedContext(
      "platform-admin", { platformAdmin: true }
    ).firestore();
    await assertSucceeds(getDoc(doc(owner, "users/member-a/support_cases/case-a")));
    await assertSucceeds(getDoc(doc(owner, "users/member-a/support_inbox/platform_case-a")));
    await assertSucceeds(getDoc(doc(admin, "users/member-a/support_cases/case-a")));
    await assertFails(getDoc(doc(other, "users/member-a/support_cases/case-a")));
    await assertFails(setDoc(doc(owner, "users/member-a/support_cases/forged"), {
      targetUid: "member-a", status: "open"
    }));
    await assertFails(setDoc(doc(admin, "users/member-a/support_cases/forged"), {
      targetUid: "member-a", status: "open"
    }));
  });
});

describe("Fitness record field validation", () => {
  it("range-checks personal measurement fields", async () => {
    const owner = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(setDoc(doc(owner, "users/member-a/measurements/valid"), {
      ownerUid: "member-a", weightKg: 80, bodyFatPercent: 18
    }));
    await assertSucceeds(setDoc(doc(owner, "users/member-a/measurements/no-optional"), {
      ownerUid: "member-a", weightKg: 80
    }));
    await assertFails(setDoc(doc(owner, "users/member-a/measurements/too-heavy"), {
      ownerUid: "member-a", weightKg: 5000
    }));
    await assertFails(setDoc(doc(owner, "users/member-a/measurements/bad-fat"), {
      ownerUid: "member-a", weightKg: 80, bodyFatPercent: 99
    }));
  });

  it("range-checks personal goal fields", async () => {
    const owner = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(setDoc(doc(owner, "users/member-a/goals/valid"), {
      ownerUid: "member-a", name: "Reach 75kg", target: 75, unit: "kg",
      startValue: 80, currentValue: 80, status: "active"
    }));
    await assertFails(setDoc(doc(owner, "users/member-a/goals/bad-target"), {
      ownerUid: "member-a", name: "Impossible", target: -5, unit: "kg",
      startValue: 80, currentValue: 80, status: "active"
    }));
    await assertFails(setDoc(doc(owner, "users/member-a/goals/empty-name"), {
      ownerUid: "member-a", name: "", target: 75, unit: "kg",
      startValue: 80, currentValue: 80, status: "active"
    }));
  });

  it("range-checks gym-tenant measurement fields the same way", async () => {
    const member = environment.authenticatedContext("member-a").firestore();
    await assertSucceeds(setDoc(doc(member, "gyms/gym-a/measurements/valid"), {
      gymId: "gym-a", memberUid: "member-a", weightKg: 80
    }));
    await assertFails(setDoc(doc(member, "gyms/gym-a/measurements/too-light"), {
      gymId: "gym-a", memberUid: "member-a", weightKg: 1
    }));
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

  it("limits support attachments to authorized images under five megabytes", async () => {
    const image = new Uint8Array([137, 80, 78, 71]);
    const member = environment.authenticatedContext("member-a").storage();
    const trainer = environment.authenticatedContext("trainer-a").storage();
    const legacyOwner = environment.authenticatedContext("owner-a").storage();
    const outsider = environment.authenticatedContext("member-b").storage();
    const admin = environment.authenticatedContext(
      "platform-admin", { platformAdmin: true }
    ).storage();
    const gymPath = "gyms/gym-a/support/coaching-a/photo.png";
    const platformPath = "users/member-a/support/case-a/screenshot.png";
    await assertSucceeds(uploadBytes(ref(member, gymPath), image, { contentType: "image/png" }));
    await assertSucceeds(getBytes(ref(trainer, gymPath)));
    await assertSucceeds(getBytes(ref(legacyOwner, gymPath)));
    await assertFails(getBytes(ref(outsider, gymPath)));
    await assertFails(uploadBytes(ref(member, gymPath.replace(".png", ".mp4")), image, {
      contentType: "video/mp4"
    }));
    await assertSucceeds(uploadBytes(ref(member, platformPath), image, { contentType: "image/png" }));
    await assertSucceeds(getBytes(ref(admin, platformPath)));
    await assertFails(getBytes(ref(outsider, platformPath)));
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
