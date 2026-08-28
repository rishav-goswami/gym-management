export const id = "003_personal_fitness_spaces";
export const description =
  "Initialize consumer accounts and copy legacy gym fitness history into private personal records";

const fitnessCollections = [
  "member_routines",
  "workout_logs",
  "measurements",
  "goals",
  "personal_records",
  "progress_photos",
];

const personalCollection = (source) =>
  source === "member_routines" ? "routines" : source;

const deterministicId = (gymId, sourceId) =>
  `gym_${gymId.replaceAll("/", "_")}_${sourceId.replaceAll("/", "_")}`;

async function allAuthUsers(auth) {
  const users = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

export async function preview({ db, auth }) {
  const users = await allAuthUsers(auth);
  const memberships = await db.collection("gym_memberships")
    .where("role", "==", "member").get();
  return {
    authenticationUsers: users.length,
    memberMemberships: memberships.size,
    note: "History writes use gym_<gymId>_<sourceId> IDs and never delete tenant records.",
  };
}

export async function apply({ db, auth, FieldValue }) {
  const users = await allAuthUsers(auth);
  for (const user of users) {
    const userRef = db.doc(`users/${user.uid}`);
    const [current, memberships] = await Promise.all([
      userRef.get(),
      db.collection("gym_memberships")
        .where("uid", "==", user.uid)
        .get(),
    ]);
    const currentData = current.data() || {};
    const allMembershipDocs = memberships.docs.filter(
      (document) => document.get("status") === "active",
    );
    const membershipDocs = allMembershipDocs.filter(
      (document) => document.get("role") === "member",
    );
    let legacyProfile = {};
    if (membershipDocs.length > 0) {
      const gymId = String(membershipDocs[0].get("gymId"));
      const profile = await db.doc(`gyms/${gymId}/members/${user.uid}`).get();
      legacyProfile = profile.data() || {};
    }

    await userRef.set({
      uid: user.uid,
      displayName: currentData.displayName || user.displayName || legacyProfile.displayName || null,
      email: currentData.email || user.email?.toLowerCase() || legacyProfile.email || null,
      phone: currentData.phone || user.phoneNumber || legacyProfile.phone || null,
      status: currentData.status || "active",
      consumerPlanId: currentData.consumerPlanId || "free",
      gymConnectionCount: allMembershipDocs.length,
      hasGymConnection: allMembershipDocs.length > 0,
      ownsGym: allMembershipDocs.some((document) => document.get("role") === "owner"),
      updatedAt: FieldValue.serverTimestamp(),
      ...(!current.exists ? { createdAt: FieldValue.serverTimestamp() } : {}),
    }, { merge: true });
    await userRef.collection("entitlements").doc("current").set({
      ownerUid: user.uid,
      planId: "free",
      planVersion: 1,
      status: "active",
      features: {
        routines: true,
        workoutLogging: true,
        progress: true,
        exerciseLibrary: true,
        progressPhotos: true,
        gymConnections: true,
      },
      overrides: {},
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    await userRef.collection("fitness_profile").doc("current").set({
      ownerUid: user.uid,
      displayName: currentData.displayName || user.displayName || legacyProfile.displayName || null,
      ...copyIfPresent(legacyProfile, [
        "fitnessGoals",
        "experienceLevel",
        "workoutDaysPerWeek",
        "equipmentAccess",
        "heightCm",
        "weightKg",
      ]),
      origin: "personal",
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    for (const membership of membershipDocs) {
      const gymId = String(membership.get("gymId"));
      for (const sourceCollection of fitnessCollections) {
        const source = await db.collection(`gyms/${gymId}/${sourceCollection}`)
          .where("memberUid", "==", user.uid).get();
        for (let offset = 0; offset < source.docs.length; offset += 400) {
          const batch = db.batch();
          for (const document of source.docs.slice(offset, offset + 400)) {
            const targetId = deterministicId(gymId, document.id);
            const target = userRef.collection(personalCollection(sourceCollection)).doc(targetId);
            batch.set(target, {
              ...document.data(),
              ownerUid: user.uid,
              origin: "legacyGym",
              source: {
                gymId,
                collection: sourceCollection,
                documentId: document.id,
              },
              migratedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
          }
          await batch.commit();
        }
      }
    }
  }
}

function copyIfPresent(source, keys) {
  return Object.fromEntries(
    keys.filter((key) => source[key] !== undefined).map((key) => [key, source[key]]),
  );
}
