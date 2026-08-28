import { getFirestore } from "firebase-admin/firestore";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { ACTIVE_GYM_STATUSES, ROLE_PERMISSIONS } from "./config";

export type AuthenticatedRequest<T> = CallableRequest<T> & {
  auth: NonNullable<CallableRequest<T>["auth"]>;
};

export function requireAuth<T>(request: CallableRequest<T>): asserts request is AuthenticatedRequest<T> {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
}

export function requirePlatformAdmin<T>(request: CallableRequest<T>): void {
  requireAuth(request);
  if (request.auth.token.platformAdmin !== true) {
    throw new HttpsError("permission-denied", "Platform administrator access is required.");
  }
}

export async function requireGymPermission<T>(
  request: CallableRequest<T>,
  gymId: string,
  permission: string
) {
  requireAuth(request);
  const db = getFirestore();
  const [gym, membership] = await Promise.all([
    db.doc(`gyms/${gymId}`).get(),
    db.doc(`gym_memberships/${gymId}_${request.auth.uid}`).get()
  ]);

  if (!gym.exists || !ACTIVE_GYM_STATUSES.includes(gym.get("status"))) {
    throw new HttpsError("failed-precondition", "This gym is not active.");
  }
  const planEndsAt = gym.get("platformPlanEndsAt");
  if (planEndsAt?.toMillis?.() <= Date.now()) {
    throw new HttpsError("failed-precondition", "This gym platform plan has expired. Ask the owner to renew or upgrade.");
  }
  if (!membership.exists || membership.get("status") !== "active") {
    throw new HttpsError("permission-denied", "Active gym membership is required.");
  }

  const role = String(membership.get("role"));
  const overrides = (membership.get("permissions") ?? {}) as Record<string, boolean>;
  const allowed = overrides[permission] ?? ROLE_PERMISSIONS[role]?.[permission] ?? false;
  if (!allowed) throw new HttpsError("permission-denied", `Missing permission: ${permission}`);
  return { gym: gym.data()!, membership: membership.data()!, role };
}
