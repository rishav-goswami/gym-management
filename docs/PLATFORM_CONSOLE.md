# Platform console operations

The platform console is a separate web application for the SaaS maintainer. It
is not a gym-owner workspace and is not distributed through Google Play or the
App Store.

## Live applications

| Application | URL |
|---|---|
| Customer Gym Management web app | <https://createmix-gym-app.web.app> |
| Private platform console | <https://createmix-gym-admin.web.app> |

Both use the owned Firebase project `createmix-in`, but each has its own
Firebase Web App registration and Hosting target.

## Access model

- The console has email/password login only and no registration page.
- A valid Firebase identity is not sufficient. Its refreshed ID token must
  contain the trusted custom claim `platformAdmin: true`.
- Claim assignment is performed only by a trusted CLI/server using the Admin
  SDK. It must never be implemented in Flutter, Firestore, or a public
  Function.
- Firestore rules and every privileged callable Function independently verify
  the claim. The separate URL is deployment isolation, not authorization.
- There are no default cloud credentials in the repository. Emulator accounts
  are disposable and must never be copied into a real Firebase project.

After a trusted operator changes a claim, sign out and sign in again so the
browser receives a refreshed Firebase ID token.

## Run locally against Firebase cloud

```sh
cd apps/platform_console
fvm flutter pub get
fvm flutter run -d chrome
```

## Run with the Emulator Suite

From the repository root:

```sh
npm run emulators
npm run seed
```

Then, in another terminal:

```sh
cd apps/platform_console
fvm flutter run -d chrome \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

Use `platform.admin@example.com` / `LocalAdmin!2026` only with the emulators.

## Verify and deploy

From the repository root:

```sh
npm run console:analyze
npm run console:test
npm run console:build:web
firebase deploy --project createmix-in --only hosting:platform-console
```

`npm run deploy:web` builds and deploys both web applications.

## Current Spark-plan behavior

Firebase Hosting, Authentication, and permitted Firestore reads can work on
the Spark plan. The console's privileged mutations—such as gym provisioning or
tenant status changes—call Cloud Functions and will not work in the cloud until
the Firebase project is upgraded to Blaze and those Functions are deployed.
Use the Emulator Suite to exercise these workflows without enabling billing.

Before enabling App Check enforcement, create a dedicated web App Check setup
for the console and compile its site key with
`--dart-define=FIREBASE_APPCHECK_SITE_KEY=...`.
