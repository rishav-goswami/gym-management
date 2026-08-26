import { readFileSync } from "node:fs";
import { assertFails, assertSucceeds, initializeTestEnvironment, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { ref, uploadBytes } from "firebase/storage";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";

let environment: RulesTestEnvironment;

beforeAll(async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-gym-rules",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
    storage: { rules: readFileSync("../storage.rules", "utf8") }
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const store = context.firestore();
    await setDoc(doc(store, "gyms/gym-a"), { name: "Gym A", status: "active" });
    await setDoc(doc(store, "gyms/gym-b"), { name: "Gym B", status: "active" });
    await setDoc(doc(store, "gyms/gym-suspended"), { name: "Suspended", status: "suspended" });
    await setDoc(doc(store, "gym_memberships/gym-a_member-a"), {
      gymId: "gym-a", uid: "member-a", role: "member", status: "active", permissions: { "fitness.read": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-b_member-b"), {
      gymId: "gym-b", uid: "member-b", role: "member", status: "active", permissions: { "fitness.read": true }
    });
    await setDoc(doc(store, "gym_memberships/gym-suspended_member-a"), {
      gymId: "gym-suspended", uid: "member-a", role: "member", status: "active", permissions: { "fitness.read": true }
    });
    await setDoc(doc(store, "gyms/gym-a/members/member-a"), { memberUid: "member-a", name: "A" });
    await setDoc(doc(store, "gyms/gym-b/members/member-b"), { memberUid: "member-b", name: "B" });
    await setDoc(doc(store, "gyms/gym-a/workout_assignments/assignment-a"), { memberUid: "member-a" });
    await setDoc(doc(store, "gyms/gym-a/workout_assignments/assignment-other"), { memberUid: "member-b" });
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

  it("does not allow client-side membership privilege escalation", async () => {
    const store = environment.authenticatedContext("member-a").firestore();
    await assertFails(setDoc(doc(store, "gym_memberships/gym-a_member-a"), {
      gymId: "gym-a", uid: "member-a", role: "owner", status: "active"
    }));
  });
});

describe("Storage tenant isolation", () => {
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
