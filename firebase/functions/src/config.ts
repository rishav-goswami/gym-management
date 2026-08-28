export const REGION = "asia-south1";

export const ROLE_PERMISSIONS: Record<string, Record<string, boolean>> = {
  owner: {
    "dashboard.read": true,
    "staff.read": true,
    "staff.manage": true,
    "members.read": true,
    "members.write": true,
    "members.delete": true,
    "plans.manage": true,
    "subscriptions.read": true,
    "payments.read": true,
    "payments.write": true,
    "attendance.read": true,
    "attendance.manage": true,
    "classes.manage": true,
    "fitness.read": true,
    "fitness.manage": true,
    "announcements.manage": true,
    "audit.read": true
  },
  manager: {
    "dashboard.read": true,
    "staff.read": true,
    "staff.manage": true,
    "members.read": true,
    "members.write": true,
    "plans.manage": true,
    "subscriptions.read": true,
    "payments.read": true,
    "payments.write": true,
    "attendance.read": true,
    "attendance.manage": true,
    "classes.manage": true,
    "fitness.read": true,
    "fitness.manage": true,
    "announcements.manage": true,
    "audit.read": true
  },
  receptionist: {
    "dashboard.read": true,
    "members.read": true,
    "members.write": true,
    "subscriptions.read": true,
    "payments.read": true,
    "payments.write": true,
    "attendance.read": true,
    "attendance.manage": true,
    "classes.manage": true
  },
  trainer: {
    "dashboard.read": true,
    "members.read": true,
    "attendance.read": true,
    "classes.manage": true,
    "fitness.read": true,
    "fitness.manage": true
  },
  accountant: {
    "dashboard.read": true,
    "subscriptions.read": true,
    "payments.read": true,
    "payments.write": true,
    "audit.read": true
  },
  member: {
    "dashboard.read": true,
    "fitness.read": true
  }
};

export const ACTIVE_GYM_STATUSES = ["trial", "active"];
