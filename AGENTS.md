# Gym Management contributor guide

This file is the entry point for AI agents and human contributors. Read it
before changing the project. Keep it short; detailed decisions belong in the
linked canonical documents.

## Product and architecture

- The product is a consumer-first fitness platform with optional multi-tenant
  gym affiliation: one Flutter customer app and a separate Flutter web console.
- Every identity owns a permanent private **My Fitness** space. Do not require a
  gym role or invent a tenant for standalone workouts, routines, or progress.
- An active member gym dynamically brands and enriches that same customer app;
  never route ordinary members into a second app/workspace. Keep the personal
  data scope user-owned while merging tenant services into the shared shell.
- Leaving a gym removes its branding and access, revokes sharing projections,
  and preserves personal fitness. Tenant-authored membership, payment and
  attendance history remains with the gym for retention and reactivation.
- Personal data is user-owned and never enters a gym projection without an
  explicit per-category sharing grant. Platform admins have no direct rules
  access to personal fitness data; use short-lived audited support Functions.
- Firebase project `createmix-in` is the current production environment.
- Never restore Express/MongoDB as a system of record. It is legacy comparison
  material only.
- Tenant data belongs under `gyms/{gymId}`. Cross-tenant access is a release
  blocker.
- Platform administrators use Firebase custom claims. Gym roles and permission
  overrides live in Firestore.
- Owners manage gym operations and branding, but SaaS plans, quotas, feature
  entitlements, tenant status, and overrides are platform-admin controlled.
- Member recommendations may use declared goals, experience, schedule and
  equipment. They must not diagnose conditions or generate rehabilitation or
  medical advice.

## Canonical documentation map

Read the documents relevant to the change:

- [README.md](README.md): workspace, commands, environments and current status.
- [docs/PLATFORM_CONSOLE.md](docs/PLATFORM_CONSOLE.md): operator access,
  provisioning, subscriptions and deployments.
- [docs/TENANT_BRANDING.md](docs/TENANT_BRANDING.md): runtime white-label model.
- [docs/SAAS_TRIALS.md](docs/SAAS_TRIALS.md): trials, quotas and upgrades.
- [docs/PRODUCT_ANALYTICS_AND_ONBOARDING.md](docs/PRODUCT_ANALYTICS_AND_ONBOARDING.md):
  feature analytics, feedback and member recommendation profile.
- [docs/CONSUMER_FITNESS.md](docs/CONSUMER_FITNESS.md): personal spaces,
  onboarding, gym sharing, consumer controls and migration rollout.
- [docs/MEMBER_TRAINING.md](docs/MEMBER_TRAINING.md): exercise guidance and safety.
- [docs/BILLING.md](docs/BILLING.md) and
  [docs/MEMBER_BILLING.md](docs/MEMBER_BILLING.md): recorded payments and member
  subscription experience.
- [docs/INFRASTRUCTURE_AND_MIGRATION.md](docs/INFRASTRUCTURE_AND_MIGRATION.md):
  Firebase portability, provisioning and migrations.
- [docs/MANUAL_TESTING.md](docs/MANUAL_TESTING.md): acceptance checklist.

When behavior changes, update its canonical document in the same change.

## Change rules

1. Put privileged, transactional, quota, subscription and aggregation logic in
   Cloud Functions. Flutter must not write privileged documents directly.
2. Update Firestore/Storage rules and Emulator Suite tests for every new data
   path or permission.
3. Keep historical views paginated and realtime listeners bounded.
4. Store media in Firebase Storage, not the application bundle. Store private
   media paths instead of public tokenized URLs where practical.
5. Do not commit credentials, service-account keys, `.env` secrets, build
   output, Firebase export data, or generated platform caches.
6. Keep infrastructure, rules, indexes, seeds and migrations account-portable.
7. Treat observability and feedback as part of every user-facing feature's
   definition of done. Before rollout, give the feature a stable identifier,
   record one or more meaningful privacy-safe outcomes (not noisy tap streams),
   derive audience and `personal`/`gym` scope on the server, throttle or
   deduplicate counters, provide contextual feedback where useful, expose only
   aggregates in the platform console, and update the analytics allowlist,
   dashboard, documentation and Function/rules tests. Never include workout,
   health, message or other private content in analytics or feedback metadata.
   Follow the checklist in
   [docs/PRODUCT_ANALYTICS_AND_ONBOARDING.md](docs/PRODUCT_ANALYTICS_AND_ONBOARDING.md).
8. Run the smallest relevant checks while iterating, then the full release
   checks before deployment.

## Verification baseline

From the repository root:

```sh
npm run security:check
npm run functions:build
npm run functions:test
npm run app:analyze
npm run app:test
npm run console:analyze
npm run console:test
node scripts/verify-portability.mjs
```

Use the Emulator Suite for rules tests. Deploy only to an explicitly selected
Firebase project and verify both Hosting URLs after release.
