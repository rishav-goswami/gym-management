import { FieldValue, Firestore } from "firebase-admin/firestore";

export function writeAudit(
  db: Firestore,
  gymId: string,
  actorUid: string,
  action: string,
  target: Record<string, unknown>,
  metadata: Record<string, unknown> = {}
) {
  return db.collection(`gyms/${gymId}/audit_logs`).add({
    gymId,
    actorUid,
    action,
    target,
    metadata,
    createdAt: FieldValue.serverTimestamp()
  });
}
