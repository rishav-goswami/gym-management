# Manual testing guide

This guide verifies the Firebase foundation on web, iOS, or Android without
deploying anything. The Emulator Suite is the safest default because its users
and data are disposable.

## 1. Start a clean local environment

Requirements: FVM, Node.js 22 or 24, and Java 21 or newer. From the repository
root, install dependencies once:

```sh
npm run app:pubget
npm run console:pubget
npm install
npm --prefix firebase/functions install
```

On macOS, install Java with `brew install openjdk@21`. The npm emulator commands
automatically find Homebrew's keg-only JDK.

Use three terminals:

```sh
# Terminal 1: keep this running
npm run emulators

# Terminal 2: run after the emulators report that they are ready
npm run seed

# Terminal 3: start the web app
cd apps/gym_app
fvm flutter run -d chrome \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

Platform administrators no longer enter through the customer application.
Start the console in a fourth terminal when testing platform operations:

```sh
cd apps/platform_console
fvm flutter run -d chrome \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

Open the Emulator UI at <http://127.0.0.1:4000>. Use it to inspect Auth users,
Firestore documents, Storage objects, and Function logs. Stopping the emulator
terminal clears data unless import/export persistence is deliberately added.

## 2. Seeded test identities

| Role | Email | Password |
|---|---|---|
| Platform admin | `platform.admin@example.com` | `LocalAdmin!2026` |
| Gym owner | `owner@pilotgym.example.com` | `PilotOwner!2026` |
| Trainer | `trainer@pilotgym.example.com` | `PilotTrainer!2026` |
| Member | `member@pilotgym.example.com` | `PilotMember!2026` |

These accounts only exist locally. The pilot gym ID is `pilot-gym`.

## 3. Consumer authentication and personal-space checks

For the owner, trainer, and member accounts in the customer app:

1. Sign in with the seeded email and password.
2. Confirm the launch opens **My Fitness**, not a role or workspace chooser.
3. Confirm **Home, Training, Progress, Profile** work without opening Pilot Gym.
4. Open **Profile → My gyms & spaces**, select Pilot Gym, and confirm the role
   chip and tenant brand only appear inside that gym space.
5. Return to **My Fitness** and confirm the platform brand is restored.
5. Use **Log out** and confirm that the login page returns.

For a fresh identity, verify the three skippable introduction screens, Google/
Apple buttons, phone under **More ways to sign in**, mandatory 18+/policy
confirmation, and skippable goal/experience/equipment steps. A fresh standalone
user must be able to create a routine and log a workout without a gym.

For `platform.admin@example.com`, use the separate platform console. Confirm
that the tenant list opens and that the customer app does not offer a platform
administration route.

Expected security behavior:

- A member must not see staff, payments, tenant settings, or platform controls.
- A trainer must not see platform controls or owner-only operations.
- Only the platform-admin identity sees **Platform administration**.
- Registering a public account does not create an owner, trainer, or admin role.
- A verified public account may start one limited gym trial; it cannot choose an
  arbitrary privileged role or start a second free trial.

### Self-service owner trial

1. Register a fresh customer identity and open its verification link from the
   Auth emulator.
2. Select **Start my gym**, confirm the displayed limits, and create the tenant.
3. On the owner dashboard, confirm days remaining and usage counters appear.
4. Invite members/trainers to the displayed limit. The next invitation can be
   created, but accepting it must fail atomically with a plan-limit message.
5. Select **Upgrade**, request Starter, then approve it in the platform console.
6. Return to the owner dashboard and confirm the new plan snapshot and limits.

See [`SAAS_TRIALS.md`](SAAS_TRIALS.md) for the data model and security guarantees.

## 4. Platform administrator

Sign in as `platform.admin@example.com` and open **Platform administration**.

- Confirm that Pilot Gym appears in the tenant list.
- Open the status menu and switch between trial and active.
- Confirm SaaS plans can be versioned and pending upgrade requests can be
  approved or rejected.
- Open **Consumers**, verify only account summaries appear, and confirm private
  fitness collections cannot be browsed. Enter a meaningful reason, open the
  audited diagnostics session, then verify the affected user's Profile shows
  that support-history entry.
- Open **Platform brand**, edit introduction copy/colors, save, and verify a
  fresh installation loads it. Keep `personalSpacesV1` disabled until the
  migration/security checklist passes in non-local environments.
- Temporarily selecting suspended should block normal tenant access. Restore the
  tenant to active before testing other roles.
- To test provisioning, copy an Auth UID from the Emulator UI, select
  **Provision gym**, enter a name and that UID, and create a trial gym.
- Sign in as that user and confirm the new owner workspace appears.

Provisioning creates the gym and owner membership transactionally. Delete an
experimental tenant from the Emulator UI if it is no longer needed.

## 5. Gym owner and staff workspace

Sign in as `owner@pilotgym.example.com` and select Pilot Gym.

- **Dashboard:** confirm the live Firebase connection card and seeded metrics.
- **Members:** confirm each row shows a name or verified contact rather than a
  raw Firebase UID, search by name/email/phone, inspect plan and profile status,
  then open a row and change only an intended
  role/status value. Test CSV export.
- **Attendance:** generate a 60-second QR and confirm it renders. Attendance CSV
  export should complete even when the list is small.
- **Classes:** schedule a class with a positive capacity and confirm it appears.
- **Payments:** open **Plans** and confirm the three seeded offerings. Use
  **Record renewal** to select the seeded member and a plan, then enter the
  received amount and method. Confirm the receipt, payment, renewed subscription,
  and audit event in Firestore. See [`BILLING.md`](BILLING.md) for renewal rules.
- **Staff:** create an invitation using a valid email and role. Confirm the
  invitation-ready sheet offers the native share action and a copy-link
  fallback. Only the token hash is stored by the backend.
- **Notices:** publish a notice and confirm it appears in the bounded list.
- **Settings:** change the gym name or primary color, save it, switch context,
  and reopen Pilot Gym to reload runtime branding.

Do not use production personal data during local testing.

## 6. Invitation and multi-gym flow

1. As owner, create an invitation for an email address that matches the account
   that will accept it.
2. Tap **Share invitation** and confirm the platform share sheet opens. Also
   test **Copy invitation link** as the fallback.
3. Log out, then open the shared link in a new browser or on another device.
4. Register or sign in with the invited identity. Confirm the invitation gym
   and role remain visible through authentication.
5. Confirm the invitation page contains only the gym, invited role, matched
   identity and **Join gym** action. It must not show **My Fitness**, existing
   spaces, **Own a gym**, or a gym-ID/token input.
6. Tap **Join gym** and confirm the success view says member services are active
   while personal fitness remains private. Continue without choosing sharing.
7. Confirm the existing customer shell now uses the gym logo/colors and merges
   gym content into Home and Training without changing personal workout paths.
   From **Profile → My gym membership**, open the gym profile and confirm the
   Profile/Membership/Settings view opens inside the current app—not a separate
   member workspace.
8. Confirm the person appears in the owner's
   member/staff list but their personal workouts are absent from gym projections.
9. Enable only workout summaries from **Profile → Fitness data sharing**. Confirm
   the UI explains that consent affects authorized staff visibility, not member
   feature access. Log a
   personal workout, verify its bounded projection, then revoke it and confirm
   the projection is removed without changing payments or attendance.
10. Try reusing the link and confirm it is rejected.
11. From the gym membership Settings, choose **Leave gym**. Confirm the app
    returns to platform branding, personal workouts/progress remain, sharing
    projections are deleted, the deterministic membership/member profile has
    status `left`, and tenant payments/attendance/audits remain. Create a fresh
    invitation and confirm the same membership record can be reactivated.

There is no customer-facing gym-ID/token form. Owners distribute a branded
universal link or QR; support staff must not ask users to copy technical IDs.

The backend normalizes identity matching, checks expiry, and creates membership
server-side. A user with memberships in multiple gyms can switch context without
signing into a second account.

## 7. Trainer workspace

Sign in as `trainer@pilotgym.example.com`.

- Confirm **Members**, **Plans**, **Classes**, and **Support** are present.
- In **Plans**, assign a workout using a valid member UID and confirm the new
  assignment in Firestore.
- Confirm scheduled classes are visible.
- Start a support conversation with a valid participant UID, send a message,
  and confirm it appears in the bounded realtime message view.

Templates, plan revision UX, adherence summaries, and full member timelines are
later product-stage work; the secure storage and assignment foundation is what
this pass verifies.

## 8. Personal fitness and member gym workspace

Sign in as `member@pilotgym.example.com`. Confirm the gym brand and services are
merged into the same Home/Training/Progress/Profile shell. Open
**Profile → My gym membership** for the gym-owned profile and billing details.

- **Home:** confirm the tenant-branded summary and five-day expiry banner load.
- **Exercise media:** confirm the recommended workout and Training catalog show
  guidance images instead of dumbbell placeholders. On web, verify the Storage
  image response includes an `Access-Control-Allow-Origin` header. Temporarily
  blocking Storage should make the app retry its pinned catalog source.
- **Profile:** edit the member photo and recommendation profile, then open its
  **Membership** area to inspect the current plan, payment receipt, and unread
  reminder from the header bell. Confirm the unread badge, single-message read,
  mark-all-read, and responsive notification drawer. Confirm **Settings**
  contains gym switching, export, logout, and deletion controls and that
  Membership is no longer a separate bottom tab.
- **Home scrolling:** on a narrow mobile viewport, scroll repeatedly from top
  to bottom and back while profile, subscription, workout summary, exercise
  media and announcements load. The page must keep its position without
  jumping, snapping, or fighting upward scroll gestures.
  Send a renewal request and confirm the selected plan becomes pending. Log in
  as owner and confirm it appears under **Payments → Overview**.
- **Workout:** confirm assigned workouts appear after the trainer test.
- **Workout:** start a guided session, enter working weight and completed reps,
  complete sets, and finish it. Open **Progress → Exercises**, select that
  exercise, and confirm its history, chart, volume, and record values reflect the
  saved session. A bodyweight exercise should show rep records instead of fake
  weight records.
- **Custom routine:** create a routine assigned to at least two weekdays. Add a
  cardio movement, bodyweight movement, and a strength exercise. Edit the
  routine, reopen it, and confirm schedule/movements persist. Start it and log a
  treadmill interval of 15 minutes, 12 km/h, 6% incline, and 1 kg added load;
  three push-up sets of 15; and bench-press sets of 40 kg × 15, 50 kg × 15, and
  70 kg × 8. Finish the workout and verify each movement's correct metrics under
  **Progress → Exercises**. Deleting the routine must retain completed history.
- **Quick log:** use **Log today's workout**, add a custom movement, save it, and
  confirm it appears in recent workouts without first creating a routine.
- **Progress:** confirm Overview shows the workout in its recent history and
  eight-week consistency chart. Log weight and optional body fat and confirm the
  Body charts update. Upload a small image, verify its authenticated thumbnail,
  and confirm the private object exists under the gym/member Storage path without
  a permanent public URL.
- **Check in:** scan the owner's current QR before its 60-second expiry. Confirm
  the attendance document. A second scan must not create a duplicate check-in.
- **Classes:** book a scheduled class and confirm its booked count changes. A
  full class must reject another booking atomically.
- **Support:** create/open the trainer conversation and exchange a message.
- Open the account menu and test **Export my data**. For **Delete my account**,
  cancel at the confirmation dialog unless deletion behavior is the test target.

Camera scanning is best tested on a physical phone. For two-account QR testing,
display the owner QR in one browser/device and scan it from the member's phone.

## 9. Connected iPhone with local emulators

The phone cannot use the Mac's `127.0.0.1`. Find the Mac's LAN address, keep the
phone and Mac on the same network, and run:

```sh
cd apps/gym_app
fvm flutter devices
fvm flutter run -d YOUR_DEVICE_ID \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=EMULATOR_HOST=YOUR_MAC_LAN_IP
```

Allow incoming connections in macOS Firewall. For routine device testing, use a
dedicated deployed development Firebase project rather than exposing emulators.

## 10. Automated verification

Run before committing a feature:

```sh
npm run app:analyze
npm run app:test
npm run console:analyze
npm run console:test
npm run functions:build
npm run functions:test
npm run emulators:test
```

`npm run emulators:test` requires Java. Also verify the platform you changed:

```sh
npm run build:web
cd apps/gym_app
fvm flutter build ios --release --no-codesign --dart-define=APP_FLAVOR=development
```

## 11. Real Firebase project checklist

Do not reuse an unrelated Firebase project. Create dedicated development,
staging, and production projects so rules and test data cannot affect another
application. For the development project:

1. Enable email/password and phone authentication.
2. Create Firestore and Storage in an India-appropriate supported region.
3. Register the web, iOS, and Android applications.
4. Replace the `development`/`default` placeholders in `.firebaserc`.
5. Add native Firebase configuration files locally; do not commit secrets.
6. Deploy rules, indexes, Functions, Storage rules, and Remote Config only after
   reviewing the selected alias with `npx firebase use`.
7. Provision the first platform admin from a trusted CLI/server process; never
   expose platform-admin claim assignment in either frontend.

The root README documents the required Dart defines and deployment command.
