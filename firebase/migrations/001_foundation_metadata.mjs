export const id = "001_foundation_metadata";
export const description = "Record platform schema defaults for a fresh environment";

export async function apply({ db, FieldValue }) {
  await db.doc("platform_config/defaults").set(
    {
      schemaVersion: 1,
      currency: "INR",
      locale: "en-IN",
      timezone: "Asia/Kolkata",
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}
