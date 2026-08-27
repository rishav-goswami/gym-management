export const id = "002_backfill_member_identity";
export const description = "Backfill member profile names and contact identity from Firebase Auth";

export async function apply({ db, auth, FieldPath, FieldValue }) {
  let cursor;
  for (;;) {
    let query = db
      .collectionGroup("members")
      .orderBy(FieldPath.documentId())
      .limit(100);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const members = snapshot.docs.filter((document) => {
      const parts = document.ref.path.split("/");
      const data = document.data();
      return parts.length === 4 &&
        parts[0] === "gyms" &&
        parts[2] === "members" &&
        (!data.displayName || !data.email);
    });
    if (members.length > 0) {
      const uids = members.map((document) => String(document.get("uid") || document.id));
      const [authResult, userProfiles] = await Promise.all([
        auth.getUsers(uids.map((uid) => ({ uid }))),
        db.getAll(...uids.map((uid) => db.doc(`users/${uid}`))),
      ]);
      const authUsers = new Map(authResult.users.map((user) => [user.uid, user]));
      const rootUsers = new Map(userProfiles.map((profile) => [profile.id, profile.data() || {}]));
      const batch = db.batch();
      let writes = 0;
      members.forEach((document, index) => {
        const uid = uids[index];
        const existing = document.data();
        const authUser = authUsers.get(uid);
        const rootUser = rootUsers.get(uid) || {};
        const displayName = authUser?.displayName || rootUser.displayName || rootUser.name;
        const email = authUser?.email || rootUser.email;
        const phone = authUser?.phoneNumber || rootUser.phone;
        const update = { updatedAt: FieldValue.serverTimestamp() };
        if (!existing.displayName && displayName) update.displayName = String(displayName).trim();
        if (!existing.email && email) update.email = String(email).trim().toLowerCase();
        if (!existing.phone && phone) update.phone = String(phone).trim();
        if (Object.keys(update).length > 1) {
          batch.set(document.ref, update, { merge: true });
          writes += 1;
        }
      });
      if (writes > 0) await batch.commit();
    }
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < 100) break;
  }
}
