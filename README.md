# Gym Management multi-tenant gym platform

Two independently built Flutter clients use Firebase as their shared system of record:

- `apps/gym_app`: the customer product for members, trainers, staff, and gym owners on iOS, Android, and web.
- `apps/platform_console`: a web-only control plane for trusted Gym Management platform operators.

Platform code is not imported into the customer application. A separate Firebase Web App registration and Hosting target are used for each web client. Actual authorization remains enforced by the `platformAdmin` custom claim, Cloud Functions, and Firestore rules.

AI agents and contributors should start with [`AGENTS.md`](AGENTS.md). It maps
the product boundaries, verification baseline, and canonical project documents.

## What is implemented

- Firebase Auth with email/password and phone OTP, invitation-only gym roles, and platform-admin custom claims.
- Firestore tenant data under `gyms/{gymId}` and memberships at `gym_memberships/{gymId_uid}`.
- Runtime gym logo, name, tagline and color branding with responsive staff,
  trainer, and member workspaces.
- A separately deployed platform console for tenant provisioning and status control, with no public registration or customer-app route.
- Callable Functions for gym provisioning, invitations, recorded renewals, rotating QR attendance, atomic class booking, safe chat creation, export/deletion requests, FCM notifications, and expiry reminders.
- Verified self-service owner trials with versioned SaaS plans, transactional usage limits, upgrade requests, and platform-admin approval.
- Firestore and Storage rules that deny cross-gym access and stop access to suspended gyms.
- Development/staging/production aliases, tracked rules/indexes, Emulator Suite configuration, and a repeatable pilot seed.
- Existing Express/MongoDB code remains in `backend/` for temporary comparison only. The Flutter entrypoint no longer uses it.

Feature screens currently provide the Firebase foundation and bounded operational lists. Continue customer product work in `apps/gym_app/lib/firebase/` and platform operations in `apps/platform_console/lib/`; do not add new dependencies on the legacy REST repositories.

For a click-by-click verification of every implemented role, use
[`docs/MANUAL_TESTING.md`](docs/MANUAL_TESTING.md). It separates finished
foundation flows from later product work, so an empty seeded list is not
mistaken for a broken feature.

The owner-facing payment, membership-plan, and subscription workflow is
documented in [`docs/BILLING.md`](docs/BILLING.md).
The member-facing plan, receipt, renewal-request, and reminder flow is in
[`docs/MEMBER_BILLING.md`](docs/MEMBER_BILLING.md).
Platform-console access, local operation, and deployment are documented in
[`docs/PLATFORM_CONSOLE.md`](docs/PLATFORM_CONSOLE.md).
Owner onboarding, quotas, and upgrades are documented in
[`docs/SAAS_TRIALS.md`](docs/SAAS_TRIALS.md).
Project provisioning, infrastructure ownership, backups, and account-to-account
migration are documented in
[`docs/INFRASTRUCTURE_AND_MIGRATION.md`](docs/INFRASTRUCTURE_AND_MIGRATION.md).
Platform and owner branding workflows are documented in
[`docs/TENANT_BRANDING.md`](docs/TENANT_BRANDING.md).
Feature analytics, product feedback, and member recommendation onboarding are
documented in
[`docs/PRODUCT_ANALYTICS_AND_ONBOARDING.md`](docs/PRODUCT_ANALYTICS_AND_ONBOARDING.md).

## Prerequisites

- FVM (Flutter is pinned by `.fvmrc`)
- Node.js 22 or 24 (Firebase Functions targets Node 22)
- Java 21+ for the Firestore and Storage emulators
- Xcode and CocoaPods for iOS

Install dependencies:

```sh
cd apps/gym_app && fvm flutter pub get
cd ../platform_console && fvm flutter pub get
cd ../../packages/gym_core && fvm dart pub get
cd ../..
npm install
npm --prefix firebase/functions install
```

The repository-level npm scripts are the easiest way to check both clients:

```sh
npm run app:test
npm run console:test
npm run build:web
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
cd apps/gym_app
fvm flutter run -d chrome \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

Run on the iOS simulator with the same flags. For a connected iPhone, `127.0.0.1` points at the phone, so expose the emulator ports on your Mac LAN and pass its address:

```sh
cd apps/gym_app
fvm flutter devices
fvm flutter run -d YOUR_DEVICE_ID \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=EMULATOR_HOST=192.168.1.20
```

macOS Firewall must allow the emulator processes, and the phone and Mac must share a network. For everyday physical-device work, a dedicated Firebase development project is often simpler than exposing local emulators.

## Real Firebase projects

The development build is currently connected to Firebase project
`createmix-in`. The Firebase project ID is immutable, but the registered
apps and the product shown to users are named **Gym Management**. The configured
development identifiers are:

- Flutter/Dart package: `gym_management`
- Android, iOS, and macOS: `com.rishva.gymmanagement`
- Product/display name: `Gym Management`

Run directly against the development Firebase project with:

```sh
cd apps/gym_app
fvm flutter run -d chrome
# or
fvm flutter run -d YOUR_IOS_DEVICE_ID
```

The development cloud project is on Blaze. It has its Firestore database in
`asia-south1` with deletion protection enabled, tenant rules and indexes
released, invitation/QR TTL enabled, Remote Config published, Authentication
configured, and the Node.js 22 Functions deployed in `asia-south1`. The
customer and platform web applications are live on their dedicated Hosting
sites. Firebase Storage is provisioned in `asia-south1`, its security rules are
deployed, and the versioned exercise catalog is synchronized.

### Reapply the `createmix-in` Storage setup

Storage provisioning is idempotent and tracked as a repository command:

```sh
npm run storage:provision -- --project createmix-in --existing-only
npx firebase deploy --project createmix-in --only storage
npm run catalog:sync -- --project createmix-in --confirm createmix-in
```

For a fresh Firebase environment, run the secure bootstrap from the repository
root before deploying backend configuration:

```sh
node scripts/bootstrap-cloud.mjs \
  createmix-in \
  1:996305810467:web:769c342a5836b4ef7bad96 \
  rishva343@gmail.com

npx firebase deploy --project createmix-in \
  --only functions,firestore:indexes,storage
```

The bootstrap is deliberately narrow: it enables the Identity Toolkit and
Compute APIs required by Auth and second-generation Functions, enables
email/password authentication, creates or updates only the named platform
administrator, adds the `platformAdmin: true` claim, sends that address a
password-reset email, and writes only the `trial` and `starter` SaaS plan
documents. It does not create prototype gyms, members, trainers, or payments.
It is safe to rerun for the same administrator.

The customer app can create ordinary identities and verified owners may use one
self-service gym trial. A trusted CLI or server process must add the
`platformAdmin: true` custom claim to platform maintainers; no public app can
grant platform administrator access.

Before publishing, replace `com.rishva` if a different company-owned namespace
is required. Android's application ID and Apple's bundle ID should be treated as
permanent after their first store release.

To regenerate Firebase configuration on macOS, ensure FlutterFire and its Xcode
project dependency are available:

```sh
export PATH="/opt/homebrew/opt/ruby/bin:$HOME/.pub-cache/bin:$PATH"
/opt/homebrew/opt/ruby/bin/gem install xcodeproj --user-install
cd apps/gym_app
flutterfire configure \
  --project=createmix-in \
  --platforms=android,ios,macos,web,windows \
  --android-package-name=com.rishva.gymmanagement \
  --ios-bundle-id=com.rishva.gymmanagement \
  --macos-bundle-id=com.rishva.gymmanagement \
  --web-app-id=1:996305810467:web:b20ab104434075da7bad96 \
  --windows-app-id=1:996305810467:web:94b70b5a5c2f885f7bad96 \
  --yes --overwrite-firebase-options
```

Run the platform console locally against the development Firebase project:

```sh
cd apps/platform_console
fvm flutter run -d chrome
```

The console uses Firebase Web App ID
`1:996305810467:web:769c342a5836b4ef7bad96`. It intentionally supports only
email/password sign-in and rejects every authenticated identity whose refreshed
token does not contain `platformAdmin: true`.

Create dedicated staging and production Firebase projects before release and
replace their placeholders in `.firebaserc`. Register Android, Apple, web, and
Windows apps in each project, then enable email/password and phone providers and
create Firestore and Storage.

The checked-in `firebase_options.dart` contains only the development Firebase
client configuration (these client values are not service-account secrets).
Pass staging or production values as CI secrets or local `--dart-define` values:

```sh
cd apps/gym_app
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

- `apps/gym_app/ios/Runner/GoogleService-Info.plist`
- `apps/gym_app/android/app/google-services.json`

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
cd apps/gym_app
fvm flutter test
fvm flutter analyze lib test

cd ../platform_console
fvm flutter test
fvm flutter analyze lib test

cd ../../packages/gym_core
fvm dart test

# Functions compiler and fast domain tests
npm run functions:build
npm run functions:test

# Firestore tenant/security tests (requires Java)
npm run emulators:test

# Release compilation
cd ../../apps/gym_app
fvm flutter build web --release --dart-define=APP_FLAVOR=staging ...
fvm flutter build apk --release --dart-define=APP_FLAVOR=staging ...
fvm flutter build ios --release --no-codesign --dart-define=APP_FLAVOR=staging ...
```

## Web deployment

The development Firebase project has two mapped Hosting targets:

| Target | Application | URL |
|---|---|---|
| `gym-app` | Customer web app | `https://createmix-gym-app.web.app` |
| `platform-console` | Private platform console | `https://createmix-gym-admin.web.app` |

Build and deploy both from the repository root:

```sh
npm run deploy:web
```

The production web build commands include the domain-restricted reCAPTCHA
Enterprise site keys used by Firebase App Check. These keys identify the web
clients and are safe to include in frontend builds; authorization still comes
from Firebase Auth, Firestore rules, and callable Function permission checks.
To recreate the App Check registrations for a replacement Firebase project,
run:

```sh
node scripts/configure-web-app-check.mjs PROJECT_ID CUSTOMER_WEB_APP_ID CONSOLE_WEB_APP_ID
```

Then replace the two `FIREBASE_APPCHECK_SITE_KEY` values in `package.json` with
the keys printed by the script before deploying.

Deploy one site without affecting the other:

```sh
npm run app:build:web
firebase deploy --project createmix-in --only hosting:gym-app

npm run console:build:web
firebase deploy --project createmix-in --only hosting:platform-console
```

Creating a separate frontend does not make privileged operations safe by
itself. Never place Admin SDK credentials in either web build, and keep every
platform mutation protected by claim checks in Functions and rules.

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
apps/gym_app/                 Customer Flutter app (mobile and web)
apps/platform_console/        Private Flutter web platform console
packages/gym_core/            Shared models, validation, and contracts
firebase/functions/src/      privileged backend and seed
firebase/firestore.rules     tenant authorization
firebase/storage.rules       tenant media authorization
firebase/firestore.indexes.json
firebase.json                emulator/deploy configuration
backend/                     temporary legacy Express comparison backend
```

Retire `backend/`, Docker MongoDB, old REST auth models, and `.env` API configuration after Firebase auth and member-profile parity has been verified on development, staging, and all three customer Flutter targets.
