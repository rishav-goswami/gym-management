# Consumer-First Multi-Tenant Fitness Platform

## Summary

Transform the customer app into a standalone fitness product with optional gym connections:

- Every authenticated person automatically receives a permanent, platform-branded **My Fitness** space.
- Normal users can create routines, log workouts, track progress, and use the exercise library without joining a gym.
- Gym memberships become optional spaces that add payments, trainers, classes, attendance, announcements, assignments, and gym branding.
- Gym owners continue using their existing operational workspace.
- Regular launches open **My Fitness**; invitation links can take users directly into a gym-joining flow.
- Personal fitness records remain user-owned. Joining a gym shares nothing by default.
- The platform console manages consumer accounts, entitlements, branding, adoption, and audited support access.

Success means a new Play Store user can register and log a workout without encountering roles, workspace terminology, gym IDs, invitations, or owner-focused copy.

## User Experience

### First launch and authentication

- Use a minimal native splash with the platform logo, followed once per installation by three remotely configurable benefit screens:
  1. Build workouts around your goals.
  2. Log every set and understand your progress.
  3. Connect with your gym whenever you choose.
- Allow skipping the introduction, but require authentication before saving fitness data.
- Provide Google sign-in on Android/web, Apple sign-in on iOS, email/password, and phone OTP under “More ways to sign in.”
- Link providers safely when the same verified email already exists.
- Require self-attested 18+ confirmation and acceptance of versioned terms/privacy before creating personal fitness data.
- After registration, collect goals, experience, workout frequency, and available equipment through short skippable steps, then enter **My Fitness**.

### Spaces and navigation

- Replace `GymMembership` as the universal UI context with:
  - `PersonalSpace`: user-owned fitness data, platform brand, consumer entitlements.
  - `GymSpace`: existing membership, role, permissions, features, and gym brand.
- Regular login always opens `PersonalSpace`.
- Personal navigation remains **Home, Training, Progress, Profile**.
- Profile contains **My gyms & spaces**, with:
  - joined gyms;
  - scan/open invitation;
  - start your own gym;
  - switch to an owner/staff/trainer/member gym space.
- Rename “Choose workspace” to the friendlier “Your fitness spaces.”
- Apply platform colors/logo in personal space and runtime tenant branding only while a gym space is selected.
- Retain existing owner/staff navigation inside gym spaces.

### Gym connection

- Remove the visible gym-ID/token form.
- Owner invitations produce the existing secure expiring token inside a branded universal link and QR code.
- Opening the link shows gym logo, name, invited role, expiry, and one clear **Join gym** action.
- Preserve invitations across registration and social sign-in.
- After acceptance, show an optional sharing screen with every category initially off.
- Users can later share selected profile/goals, workout summaries, measurements, or progress with that gym and revoke access from Profile.
- Gym billing, attendance, classes, notices, and membership information remain available without fitness-data sharing.
- Personal workouts are never automatically exposed. Starting a gym-assigned workout asks whether its result should be shared if permission is currently disabled.

## Architecture and Security

### Personal data model

Add user-owned collections independent of any tenant:

- `users/{uid}/fitness_profile/current`
- `users/{uid}/routines/{id}`
- `users/{uid}/workout_logs/{id}`
- `users/{uid}/measurements/{id}`
- `users/{uid}/goals/{id}`
- `users/{uid}/personal_records/{id}`
- `users/{uid}/progress_photos/{id}`
- `users/{uid}/notifications/{id}`
- `users/{uid}/gym_shares/{gymId}`
- `users/{uid}/entitlements/current`

Personal records include origin metadata such as `personal`, `gymAssignment`, or `legacyGym`, but remain private unless explicitly projected.

Introduce a `FitnessScope` repository interface so routine, workout, progress, profile, and media features operate against either personal paths or an authorized gym source without duplicating UI logic.

Use the existing versioned platform exercise catalog and Storage media in personal space. Gym space merges that catalog with tenant-created exercises using namespaced IDs to prevent collisions.

### Sharing and projections

- `updateGymSharing` is a callable Function that validates the active membership, updates category consent, maintains server-owned gym projections, and audits changes.
- Shared data is projected under `gyms/{gymId}/shared_fitness/{uid}` and bounded subcollections so gym queries remain tenant-scoped and efficient.
- Clients cannot write projections directly.
- Revoking a category deletes its projection while leaving payments, attendance, membership records, and gym-authored operational data intact.
- Firestore and Storage rules deny personal-data access to other users, gyms, and ordinary platform-console queries.

### Consumer plans and account controls

- Add server-managed `consumer_plans` with a default free plan and per-user entitlement snapshot.
- Keep all current personal fitness functionality enabled in the free plan; do not add consumer payment processing yet.
- Platform Functions manage suspension, entitlement overrides, export, deletion, and usage aggregation.
- Suspended users have tokens revoked and rules deny further personal-data access.
- Export includes personal data, sharing grants, memberships, and gym-origin records.
- Account deletion removes personal data and media after the recovery period and revokes all sharing projections; tenant operational records follow their separate retention policy.

### Audited platform support

- Add a **Consumers** area to the platform console with account status, onboarding state, plan, gym connections, aggregate usage, and support controls.
- Private fitness data is never queried directly from Firestore by the console.
- `startConsumerSupportSession` requires a written reason and creates a short-lived server-owned grant.
- `getConsumerSupportData` checks the grant and writes an immutable audit entry for each category viewed.
- Support history records administrator, reason, categories, timestamps, and expiry and is visible to the affected user.
- Access expires automatically and cannot expose another user or tenant through query manipulation.

### Analytics and platform branding

- Extend feature metrics with `scopeType: personal | gym`, optional `gymId`, and audience segments such as standalone, gym member, trainer, and owner.
- Track bounded funnel milestones: registration, onboarding completion, first routine, first workout, first progress entry, invitation acceptance, and gym creation.
- Platform dashboards show total consumers, standalone-only users, gym-connected users, owners, onboarding completion, activation, retention proxies, and feature adoption without exposing health details.
- Add console-managed public platform branding for logo, colors, introduction copy/images, policy URLs, and consumer feature switches.
- Keep **Gym Management** as the temporary platform name; native icon, splash, and store listing remain replaceable before release.

## Delivery Stages and Migration

1. **Personal foundation**
   - Add `AppSpace`, `FitnessScope`, personal rules, repositories, consumer entitlements, and personal Storage paths.
   - Create an idempotent numbered migration that initializes existing users, copies missing profile fields, and copies their gym fitness history into private personal records with deterministic IDs and source references.
   - Add a confirmed, resumable media migration for existing progress photos while preserving originals.

2. **Consumer onboarding and shell**
   - Add platform splash/introduction, Google/Apple provider setup, 18+ consent, progressive profile onboarding, personal home, and friendly space switching.
   - Make normal signup copy fitness-first and remove role-first language.

3. **Gym bridge**
   - Replace manual tokens with link/QR invitation handling.
   - Add category consent, server projections, revocation, gym assignments in personal training, and branded gym spaces.
   - Preserve all existing owner, staff, trainer, billing, attendance, class, and trial functionality.

4. **Platform console**
   - Add consumer dashboard, account controls, personal/gym conversion metrics, platform-brand editor, entitlement overrides, and time-limited audited support sessions.

5. **Tracker refinement**
   - After the personal foundation stabilizes, add previous-set suggestions, rest timers, warm-up/working/drop set types, RPE/RIR, notes, supersets, plate calculation, richer personal records, and routine organization.
   - Use capability inspiration from [Hevy’s advertised planner, timers, records, and exercise history](https://www.hevyapp.com/) without copying its UI, assets, exercise content, or social product.
   - Social feeds, follows, likes, wearable apps, and consumer payments remain outside this release.

Track all new rules, indexes, Functions, migrations, Remote Config defaults, provider setup instructions, and platform-brand configuration in the existing portable Firebase/IaC workflow.

## Test and Acceptance Plan

- Test email, phone, Google, and Apple registration, credential linking, verification, age consent, introduction persistence, and invitation preservation.
- Verify a standalone user can onboard, create routines, log mixed exercises, view progress, receive reminders, export data, and request deletion without any gym membership.
- Verify normal login always opens personal space and gym branding applies only after switching spaces.
- Test invite links and QR codes from cold start, warm start, uninstalled/web fallback, expired token, wrong identity, reused token, and multi-gym accounts.
- Rules tests must cover cross-user personal access, cross-gym attacks, suspended accounts, no-consent gym access, partial consent, revocation, expired support grants, and forged projections.
- Integration-test server projections, entitlement changes, account export/deletion, media access, analytics throttling, and audited support views.
- Migration tests must prove dry-run reporting, deterministic IDs, resumability, no duplicate records, preserved tenant data, and rollback compatibility.
- Widget/golden tests cover personal and multiple gym themes across phone, tablet, and web.
- Run full Flutter, Functions, emulator rules, secret scanning, portability, Android, iOS, and web release checks before enabling the remotely controlled `personalSpacesV1` rollout flag.

## Assumptions

- Personal fitness is the permanent base product; gym services are optional additions.
- Personal space opens by default even after joining gyms.
- Joining a gym initially shares no personal fitness categories.
- Direct consumers receive free core functionality with an entitlement model prepared for later premium plans.
- The first consumer release is 18+.
- Platform administrators may inspect private data only through time-limited, reasoned, fully audited support sessions.
- One customer app continues serving consumers and gym roles; the private platform console remains separate.
