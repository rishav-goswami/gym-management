# Gym Management consumer fitness and multi-tenant gym platform

Two independently built Flutter clients use Firebase as their shared system of record:

- `apps/gym_app`: the consumer fitness product with a dynamically merged gym-member overlay plus operational owner/staff/trainer consoles on iOS, Android, and web.
- `apps/platform_console`: a web-only control plane for trusted Gym Management platform operators.

Platform code is not imported into the customer application. A separate Firebase Web App registration and Hosting target are used for each web client. Actual authorization remains enforced by the `platformAdmin` custom claim, Cloud Functions, and Firestore rules.

AI agents and contributors should start with [`AGENTS.md`](AGENTS.md). It maps
the product boundaries, verification baseline, and canonical project documents.

## What is implemented

- A permanent private **My Fitness** space for standalone routines, mixed workout
  logging, exercise guidance, measurements and progress; gym membership is optional.
- Firebase Auth with email/password, phone OTP, Google and Apple entry points,
  18+ and versioned-policy onboarding, invitation-only gym roles, and platform-admin custom claims.
- Explicit per-gym fitness sharing with server-owned projections, revocation,
  consumer entitlements, suspension, export/deletion and audited support grants.
- Firestore tenant data under `gyms/{gymId}` and memberships at `gym_memberships/{gymId_uid}`.
- Runtime gym logo, name, tagline and color branding with responsive staff,
  trainer, and member workspaces.
- A separately deployed platform console for tenant provisioning and status control, with no public registration or customer-app route.
- Callable Functions for gym provisioning, invitations, recorded renewals, rotating QR attendance, atomic class booking, safe chat creation, export/deletion requests, FCM notifications, and expiry reminders.
- Verified self-service owner trials with versioned SaaS plans, transactional usage limits, upgrade requests, and platform-admin approval.
- Firestore and Storage rules that deny cross-gym access and stop access to suspended gyms.
- Development/staging/production aliases, tracked rules/indexes, Emulator Suite configuration, and a repeatable pilot seed.
- The retired Express/MongoDB/Docker prototype and its disconnected Flutter
  client paths have been removed; Firebase is the only runtime backend.

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
The personal-space model, consent bridge, consumer support controls and rollout
are documented in [`docs/CONSUMER_FITNESS.md`](docs/CONSUMER_FITNESS.md).

## Prerequisites

- FVM (Flutter is pinned by `.fvmrc`)
- Node.js 22 or 24 (Firebase Functions targets Node 22)
- Java 21+ for the Firestore and Storage emulators
- Xcode with Swift Package Manager for iOS 15+

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
Windows apps in each project, create Firestore and Storage, and configure
email/password, phone, Google and Apple providers. OAuth/Apple secrets remain in
the provider consoles or an encrypted secret store, never in Git or Terraform
variable files. See [`docs/CONSUMER_FITNESS.md`](docs/CONSUMER_FITNESS.md) for
the required return URLs and native provider setup.

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

## Release and deployment runbook

The commands below deliberately name `createmix-in`; do not rely on whichever
Firebase alias happens to be active in another terminal. At present this is the
live Firebase project for both web clients and the mobile app configuration.

### 1. Pre-release checks

From the repository root, start from a clean branch and run:

```sh
git status --short
npm ci
npm --prefix firebase/functions ci
cd apps/gym_app && fvm flutter pub get && cd ../..
cd apps/platform_console && fvm flutter pub get && cd ../..

npm run security:check
npm run functions:build
npm run functions:test
npm run emulators:test
npm run app:analyze
npm run app:test
npm run console:analyze
npm run console:test
(cd packages/gym_core && fvm dart test)
node scripts/verify-portability.mjs
```

Confirm that the store version in `apps/gym_app/pubspec.yaml` is unique, for
example `version: 1.0.1+2`. The part before `+` is the public version; the number
after `+` must increase for each Android/iOS upload. Also confirm that the
production terms/privacy URLs, icons, splash assets, support contact, Firebase
budgets, App Check, APNs and store privacy declarations are ready.

### 2. Firebase rules, Functions and web

Authenticate and verify the exact account/project:

```sh
firebase login
firebase projects:list
firebase use createmix-in
```

Deploy server configuration first. Firestore/Storage rules in this repository
overwrite console-edited rules, so make the repository the source of truth:

```sh
firebase deploy --project createmix-in \
  --only firestore:rules,firestore:indexes,storage,functions,remoteconfig
```

Build and deploy both Hosting targets:

```sh
npm run deploy:web
```

Or deploy them independently:

```sh
npm run app:build:web
firebase deploy --project createmix-in --only hosting:gym-app

npm run console:build:web
firebase deploy --project createmix-in --only hosting:platform-console
```

Manually open and smoke-test:

- `https://createmix-gym-app.web.app`
- `https://createmix-gym-admin.web.app`

Check Cloud Functions and Scheduler logs after any membership, billing,
notification or privacy-cleanup release. Hosting releases can be rolled back in
the Firebase console. Rules and Functions should be restored by checking out a
known-good commit, rerunning its tests and redeploying it.

Official references: [Firebase CLI deploys](https://firebase.google.com/docs/cli)
and [Firebase deployment targets](https://firebase.google.com/docs/cli/targets).

### 3. Android / Google Play

The production application ID is `com.rishva.gymmanagement`. Treat it as
permanent after the first Play Store release.

Create an upload key once and keep it outside Git and in a backed-up password
manager/secret store:

```sh
keytool -genkeypair -v \
  -keystore "$HOME/gym-management-upload-keystore.jks" \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp apps/gym_app/android/key.properties.example \
  apps/gym_app/android/key.properties
```

Edit the ignored `apps/gym_app/android/key.properties` with the real passwords
and absolute keystore path. The repository's release build intentionally does
not fall back to the debug key.

Build the Play-preferred Android App Bundle:

```sh
cd apps/gym_app
fvm flutter build appbundle --release \
  --dart-define=APP_FLAVOR=production \
  --build-name=1.0.1 \
  --build-number=2
```

The output is `apps/gym_app/build/app/outputs/bundle/release/app-release.aab`.
Create the Play Console app with the same application ID, enable Play App
Signing, and upload the AAB to **Internal testing** first. Add testers, complete
the store listing, content rating, Data safety, health-app disclosures, privacy
policy and account-deletion requirements. Promote the tested artifact through
closed/open testing and production from Play Console; the build command itself
does not publish anything.

Register the Play app-signing and upload SHA-1/SHA-256 fingerprints in the
Firebase Android app, download an updated `google-services.json` when Firebase
requires it, configure Google sign-in, and register Play Integrity in Firebase
App Check before enforcing it for production traffic.

Official reference: [Flutter Android release guide](https://docs.flutter.dev/deployment/android).

### 4. iOS / TestFlight and App Store

The current bundle ID is `com.rishva.gymmanagement`. Membership in the Apple
Developer Program, an explicit App ID, an App Store Connect app record, signing
certificates and a provisioning profile/team are required.

Open `apps/gym_app/ios/Runner.xcworkspace` in Xcode once and select the owned
Apple Team under **Runner → Signing & Capabilities**. Verify the bundle ID and
enable/configure the capabilities used by the app, including Push
Notifications, Sign in with Apple, Associated Domains for invitation links,
and the selected App Check provider. Upload the APNs authentication key to
Firebase Cloud Messaging and configure the Apple sign-in provider in Firebase.

Create the archive and IPA:

```sh
cd apps/gym_app
fvm flutter build ipa --release \
  --dart-define=APP_FLAVOR=production \
  --build-name=1.0.1 \
  --build-number=2
```

The archive is written under `build/ios/archive/` and exported IPAs under
`build/ios/ipa/`. Validate and upload it using Xcode Organizer or Apple's
Transporter. Release to internal TestFlight testers first, complete App Store
privacy/nutrition-label, health-data, export-compliance, support and account
deletion information, then submit that tested build for App Review. The build
command does not publish or submit the app automatically.

Official reference: [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios).

### 5. What must never be committed

- Android `key.properties`, upload keystores and passwords
- Apple certificates, private keys, provisioning profiles and App Store API keys
- Firebase service-account JSON files or migration exports
- `.env` secrets, emulator exports, generated build output or debug logs

Firebase client configuration and web API keys identify the client and are not
Admin SDK credentials; still restrict those keys appropriately and rely on Auth,
App Check, Security Rules and Functions authorization for actual protection.

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
- Store personal progress photos at `users/{uid}/progress`, gym-origin photos at
  `gyms/{gymId}/progress/{uid}`, and chat attachments under their conversation.
  Storage rules enforce ownership, participant access, MIME types, and size limits.

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
firebase/migrations/         numbered, resumable data migrations
infra/terraform/             portable project-service infrastructure
```
