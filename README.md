# FitLife multi-tenant gym platform

One responsive Flutter app for gym members, trainers, staff, owners, and FitLife platform administrators. Firebase is the system of record. A user signs in once and then selects one of their gym/role memberships.

## What is implemented

- Firebase Auth with email/password and phone OTP, invitation-only gym roles, and platform-admin custom claims.
- Firestore tenant data under `gyms/{gymId}` and memberships at `gym_memberships/{gymId_uid}`.
- Runtime gym name/color branding and responsive platform, staff, trainer, and member workspaces.
- Callable Functions for gym provisioning, invitations, recorded renewals, rotating QR attendance, atomic class booking, safe chat creation, export/deletion requests, FCM notifications, and expiry reminders.
- Firestore and Storage rules that deny cross-gym access and stop access to suspended gyms.
- Development/staging/production aliases, tracked rules/indexes, Emulator Suite configuration, and a repeatable pilot seed.
- Existing Express/MongoDB code remains in `backend/` for temporary comparison only. The Flutter entrypoint no longer uses it.

Feature screens currently provide the Firebase foundation and bounded operational lists. Continue product work in `lib/firebase/`; do not add new dependencies on the legacy REST repositories.

For a click-by-click verification of every implemented role, use
[`docs/MANUAL_TESTING.md`](docs/MANUAL_TESTING.md). It separates finished
foundation flows from later product work, so an empty seeded list is not
mistaken for a broken feature.

## Prerequisites

- FVM (Flutter is pinned by `.fvmrc`)
- Node.js 22 or 24 (Firebase Functions targets Node 22)
- Java 21+ for the Firestore and Storage emulators
- Xcode and CocoaPods for iOS

Install dependencies:

```sh
fvm flutter pub get
npm install
npm --prefix firebase/functions install
```

On macOS, `brew install openjdk@21` is sufficient. The repository emulator
scripts detect Homebrew's keg-only JDK, so no global Java symlink is required.

## Local Firebase development

Terminal 1:

```sh
npm run emulators
```

The Emulator UI is at `http://127.0.0.1:4000`. Auth, Functions, Firestore, and Storage use ports 9099, 5001, 8080, and 9199.

Seed the running emulators in terminal 2:

```sh
npm run seed
```

The seed refuses to touch a real project unless `SEED_CONFIRM_PRODUCTION=true` is deliberately provided.

Local accounts:

| Context | Email | Password |
|---|---|---|
| Platform admin | `platform.admin@example.com` | `LocalAdmin!2026` |
| Pilot owner | `owner@pilotgym.example.com` | `PilotOwner!2026` |
| Pilot trainer | `trainer@pilotgym.example.com` | `PilotTrainer!2026` |
| Pilot member | `member@pilotgym.example.com` | `PilotMember!2026` |

These credentials exist only in the Emulator Suite. Never reuse them in a deployed project.

Run Flutter web against the emulators:

```sh
fvm flutter run -d chrome \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

Run on the iOS simulator with the same flags. For a connected iPhone, `127.0.0.1` points at the phone, so expose the emulator ports on your Mac LAN and pass its address:

```sh
fvm flutter devices
fvm flutter run -d YOUR_DEVICE_ID \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=EMULATOR_HOST=192.168.1.20
```

macOS Firewall must allow the emulator processes, and the phone and Mac must share a network. For everyday physical-device work, a dedicated Firebase development project is often simpler than exposing local emulators.

## Real Firebase projects

Create three Firebase projects and replace the staging/production placeholders in `.firebaserc`. Register the iOS, Android, and web apps in each project, enable email/password and phone providers, and create Firestore and Storage.

Pass each app's Firebase values as CI secrets or local `--dart-define` values:

```sh
fvm flutter run -d chrome \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=FIREBASE_PROJECT_ID=your-staging-project \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_WEB_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=... \
  --dart-define=FIREBASE_APPCHECK_SITE_KEY=...
```

Use `FIREBASE_IOS_APP_ID` and `FIREBASE_ANDROID_APP_ID` for their respective builds.

Also add the downloaded native files for full iOS/Android services:

- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`

Configure APNs for FCM, App Check providers, Crashlytics symbol upload, budgets, backups, and retention in each Firebase project before release. Do not commit production secrets or service-account keys.

Deploy tracked backend configuration:

```sh
npx firebase use staging
npx firebase deploy --only firestore:rules,firestore:indexes,storage,functions,remoteconfig
```

Only a trusted server/CLI process should set `platformAdmin: true`. Gym roles are never custom claims; they are Firestore memberships created by provisioning/invitation Functions.

## Tests and checks

```sh
# Flutter unit and widget tests
fvm flutter test
fvm flutter analyze lib test

# Functions compiler and fast domain tests
npm run functions:build
npm run functions:test

# Firestore tenant/security tests (requires Java)
npm run emulators:test

# Release compilation
fvm flutter build web --release --dart-define=APP_FLAVOR=staging ...
fvm flutter build apk --release --dart-define=APP_FLAVOR=staging ...
fvm flutter build ios --release --no-codesign --dart-define=APP_FLAVOR=staging ...
```

The rules suite covers own-tenant access, cross-tenant attacks, suspended tenants, fitness-record privacy, and client privilege escalation. Add role/override cases whenever a new collection or permission is introduced.

## Data and cost rules

- Keep realtime listeners bounded to operational screens, chat, and notifications.
- Paginate history and use `dashboard_metrics/current` rather than counting full collections in clients.
- Store money as integer minor units and record payments manually; release one does not process money.
- Writes that affect money, capacity, attendance, roles, or tenant status belong in Cloud Functions transactions.
- Member-owned offline data is cached for reading. UI writes should require connectivity and clearly report failure.
- Store progress photos at `gyms/{gymId}/progress/{uid}` and chat attachments under their conversation. Storage rules enforce ownership, participant access, MIME types, and size limits.

## Repository map

```text
lib/firebase/                 Firebase domain, repositories, session, and UI
firebase/functions/src/      privileged backend and seed
firebase/firestore.rules     tenant authorization
firebase/storage.rules       tenant media authorization
firebase/firestore.indexes.json
firebase.json                emulator/deploy configuration
backend/                     temporary legacy Express comparison backend
```

Retire `backend/`, Docker MongoDB, old REST auth models, and `.env` API configuration after Firebase auth and member-profile parity has been verified on development, staging, and all three Flutter targets.
