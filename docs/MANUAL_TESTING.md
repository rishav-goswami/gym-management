# Manual testing guide

This guide verifies the Firebase foundation on web, iOS, or Android without
deploying anything. The Emulator Suite is the safest default because its users
and data are disposable.

## 1. Start a clean local environment

Requirements: FVM, Node.js 22 or 24, and Java 21 or newer. From the repository
root, install dependencies once:

```sh
fvm flutter pub get
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
fvm flutter run -d chrome \
  --dart-define=APP_FLAVOR=development \
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

For every account:

1. Sign in with the seeded email and password.
2. Confirm that **Choose workspace** appears before tenant data is shown.
3. Select the Pilot Gym context and confirm the role chip in the top bar.
4. Use **Switch gym or role** and confirm that the context chooser returns.
5. Use **Log out** and confirm that the login page returns.

Expected security behavior:

- A member must not see staff, payments, tenant settings, or platform controls.
- A trainer must not see platform controls or owner-only operations.
- Only the platform-admin identity sees **Platform administration**.
- Registering a public account does not create an owner, trainer, or admin role.

## 4. Platform administrator

Sign in as `platform.admin@example.com` and open **Platform administration**.

- Confirm that Pilot Gym appears in the tenant list.
- Open the status menu and switch between trial and active.
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
- **Members:** confirm the member list; open a row and change only an intended
  role/status value. Test CSV export.
- **Attendance:** generate a 60-second QR and confirm it renders. Attendance CSV
  export should complete even when the list is small.
- **Classes:** schedule a class with a positive capacity and confirm it appears.
- **Payments:** record a renewal using a real member UID from Emulator Auth,
  a plan ID, integer/decimal amount, duration, and payment method. Confirm both
  the payment and renewed subscription documents in Firestore.
- **Staff:** create an invitation using a valid email and role. Copy the private
  token shown in the snackbar immediately; only its hash is stored.
- **Notices:** publish a notice and confirm it appears in the bounded list.
- **Settings:** change the gym name or primary color, save it, switch context,
  and reopen Pilot Gym to reload runtime branding.

Do not use production personal data during local testing.

## 6. Invitation and multi-gym flow

1. As owner, create an invitation for an email address that matches the account
   that will accept it. Save the invitation token from the snackbar.
2. Log out. Register or sign in with the invited identity.
3. On **Choose workspace**, expand **Accept a gym invitation**.
4. Enter `pilot-gym` and the token.
5. Confirm that the new gym/role context appears.
6. Try reusing the token and confirm it is rejected.

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

- **Home:** confirm the tenant-branded summary loads.
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
fvm flutter analyze
fvm flutter test
npm run functions:build
npm run functions:test
npm run emulators:test
```

`npm run emulators:test` requires Java. Also verify the platform you changed:

```sh
fvm flutter build web --release --dart-define=APP_FLAVOR=development
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
   expose platform-admin claim assignment in the public app.

The root README documents the required Dart defines and deployment command.
