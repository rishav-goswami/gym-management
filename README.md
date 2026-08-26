# Gym Management multi-tenant gym platform

One responsive Flutter app for gym members, trainers, staff, owners, and Gym Management platform administrators. Firebase is the system of record. A user signs in once and then selects one of their gym/role memberships.

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

The owner-facing payment, membership-plan, and subscription workflow is
documented in [`docs/BILLING.md`](docs/BILLING.md).
The member-facing plan, receipt, renewal-request, and reminder flow is in
[`docs/MEMBER_BILLING.md`](docs/MEMBER_BILLING.md).

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

The development build is currently connected to Firebase project
`recipe-app-cdeef`. The Firebase project ID is immutable, but the registered
apps and the product shown to users are named **Gym Management**. The configured
development identifiers are:

- Flutter/Dart package: `gym_management`
- Android, iOS, and macOS: `com.rishva.gymmanagement`
- Product/display name: `Gym Management`

Run directly against the development Firebase project with:

```sh
fvm flutter run -d chrome
# or
fvm flutter run -d YOUR_IOS_DEVICE_ID
```

The development cloud project currently has email/password and phone OTP
enabled, Gym Management Firestore/Storage rules released, Remote Config
published, and the required composite indexes building. It is on Firebase's
free Spark plan, so Cloud Functions and Firestore TTL are not deployed. Enable
billing before testing privileged cloud workflows such as tenant provisioning,
invitations, payments, attendance validation, scheduled reminders, and account
export/deletion.

For the first cloud login, select **Create an identity for an invitation** and
register the email that should become the platform maintainer. A trusted CLI or
server process must then add the `platformAdmin: true` custom claim; the public
app intentionally cannot grant itself administrator access.

Before publishing, replace `com.rishva` if a different company-owned namespace
is required. Android's application ID and Apple's bundle ID should be treated as
permanent after their first store release.

To regenerate Firebase configuration on macOS, ensure FlutterFire and its Xcode
project dependency are available:

```sh
export PATH="/opt/homebrew/opt/ruby/bin:$HOME/.pub-cache/bin:$PATH"
/opt/homebrew/opt/ruby/bin/gem install xcodeproj --user-install
flutterfire configure \
  --project=recipe-app-cdeef \
  --platforms=android,ios,macos,web,windows \
  --android-package-name=com.rishva.gymmanagement \
  --ios-bundle-id=com.rishva.gymmanagement \
  --macos-bundle-id=com.rishva.gymmanagement \
  --web-app-id=1:818455248956:web:3e5c0a6f6ad25621ae8339 \
  --windows-app-id=1:818455248956:web:90eb94b8b8717b87ae8339 \
  --yes --overwrite-firebase-options
```

Create dedicated staging and production Firebase projects before release and
replace their placeholders in `.firebaserc`. Register Android, Apple, web, and
Windows apps in each project, then enable email/password and phone providers and
create Firestore and Storage.

The checked-in `firebase_options.dart` contains only the development Firebase
client configuration (these client values are not service-account secrets).
Pass staging or production values as CI secrets or local `--dart-define` values:

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
Use `FIREBASE_WINDOWS_APP_ID` for Windows.

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
