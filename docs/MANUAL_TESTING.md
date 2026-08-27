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

## 3. Basic authentication and context checks

For the owner, trainer, and member accounts in the customer app:

1. Sign in with the seeded email and password.
2. Confirm that **Choose workspace** appears before tenant data is shown.
3. Select the Pilot Gym context and confirm the role chip in the top bar.
4. Use **Switch gym or role** and confirm that the context chooser returns.
5. Use **Log out** and confirm that the login page returns.

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
5. Tap **Accept and join gym** without manually entering a gym ID or token.
6. Confirm the new gym/role workspace opens and the person appears in the
   owner's member or staff list.
7. Try reusing the link and confirm it is rejected.

The manual gym-ID/token form remains available from **Choose workspace** as a
support fallback, but it is not the normal member onboarding path.

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

## 8. Member workspace

Sign in as `member@pilotgym.example.com`.

- **Home:** confirm the tenant-branded summary and five-day expiry banner load.
- **Profile:** edit the member photo and recommendation profile, then open its
  **Membership** area to inspect the current plan, payment receipt, and unread
  reminder from the header bell. Confirm the unread badge, single-message read,
  mark-all-read, and responsive notification drawer. Confirm **Settings**
  contains gym switching, export, logout, and deletion controls and that
  Membership is no longer a separate bottom tab.
  Send a renewal request and confirm the selected plan becomes pending. Log in
  as owner and confirm it appears under **Payments → Overview**.
- **Workout:** confirm assigned workouts appear after the trainer test.
- **Progress:** log a measurement. Upload a small image and verify that the
  private object appears under the gym/member Storage path without a public URL.
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
