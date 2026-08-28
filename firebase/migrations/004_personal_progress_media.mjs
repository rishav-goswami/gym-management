export const id = "004_personal_progress_media";
export const description =
  "Copy legacy gym progress photos to private user-owned Storage paths while preserving originals";

export async function preview({ db }) {
  const photos = await db.collectionGroup("progress_photos").count().get();
  return {
    candidateDocuments: photos.data().count,
    note: "Only gyms/<gymId>/progress_photos records with valid memberUid and storagePath are copied.",
  };
}

export async function apply({ db, bucket, FieldPath, FieldValue }) {
  if (!bucket) {
    throw new Error(
      "Migration 004 requires --bucket YOUR_FIREBASE_STORAGE_BUCKET; no bucket name is guessed.",
    );
  }
  let cursor;
  for (;;) {
    let query = db.collectionGroup("progress_photos")
      .orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    for (const document of snapshot.docs) {
      const parts = document.ref.path.split("/");
      const data = document.data();
      if (parts.length !== 4 || parts[0] !== "gyms" || parts[2] !== "progress_photos") {
        continue;
      }
      const gymId = parts[1];
      const uid = String(data.memberUid || "");
      const sourcePath = String(data.storagePath || "");
      if (!uid || !sourcePath.startsWith(`gyms/${gymId}/progress/${uid}/`)) continue;

      const suffix = sourcePath.split("/").at(-1) || `${document.id}.jpg`;
      const targetPath = `users/${uid}/progress/gym_${gymId}_${document.id}_${suffix}`;
      const sourceFile = bucket.file(sourcePath);
      const targetFile = bucket.file(targetPath);
      const [sourceExists, targetExists] = await Promise.all([
        sourceFile.exists(),
        targetFile.exists(),
      ]);
      if (!sourceExists[0]) continue;
      if (!targetExists[0]) await sourceFile.copy(targetFile);

      await db.doc(`users/${uid}/progress_photos/gym_${gymId}_${document.id}`).set({
        ...data,
        ownerUid: uid,
        storagePath: targetPath,
        origin: "legacyGym",
        source: { gymId, documentId: document.id, storagePath: sourcePath },
        migratedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    cursor = snapshot.docs.at(-1);
    if (snapshot.size < 100) break;
  }
}
