# FitGy Google Play beta release

This checklist covers the customer Android application. The platform console is
web-only and must not be submitted as a second customer application.

## Release identity

- Store name: **FitGy**
- Legal/operator identity: **Gym Management, India**
- Application ID: `com.rishva.gymmanagement` (do not change after the first upload)
- Category: **Health & Fitness**
- Intended audience: adults aged 18 and over
- Ads: none
- In-app purchases: none in the first release; membership payments are recorded
  only after a gym receives them outside the app

Before reserving the store listing, perform formal trademark and company-name
clearance for FitGy. The repository's collision search is not legal clearance.

## Public policy URLs

Deploy the customer Hosting target before completing Play Console:

- Privacy policy: <https://createmix-gym-app.web.app/privacy/>
- Terms: <https://createmix-gym-app.web.app/terms/>
- Account deletion: <https://createmix-gym-app.web.app/delete-account/>
- Android App Links: <https://createmix-gym-app.web.app/.well-known/assetlinks.json>

The policy text must receive owner/legal review before production. In particular,
confirm the public contact email, legal operator name, governing law, gym record
retention, backup rotation, and any country-specific privacy rights.

Run `npm run play:check:live` after Hosting and the public branding document are
updated. Placeholder policy URLs are a release blocker.

## Play Console declarations

### Data safety draft

Confirm this against the final Play SDK Index report and every enabled Firebase
product. The expected declaration for the current build is:

| Play data type | Collected | Shared | Primary purposes |
|---|---:|---:|---|
| Name, email, phone number, user IDs | Yes | With a joined gym where required | Account management, app functionality, security |
| Optional profile photo and other user photos | Yes | Profile images with an active gym; personal progress only by explicit grant | App functionality |
| Health and fitness information | Yes | Only categories explicitly granted to a joined gym | Fitness tracking, personalization, app functionality |
| Purchase/payment history | Yes | With the gym that authored the record | Membership administration; no payment credentials are processed |
| Messages and support attachments | Yes | With the selected gym/trainer or platform support recipient | Support and app functionality |
| App interactions | Yes | No sale or advertising sharing | Analytics, product improvement, fraud prevention |
| Crash logs, diagnostics and performance data | Yes | No sale or advertising sharing | Stability, security and diagnostics |
| Device or other IDs, including app instance and push token | Yes | Service providers only | Notifications, analytics, security and fraud prevention |

Data is encrypted in transit. Users can request deletion. Personal data is
scheduled for deletion within 30 days, while clearly disclosed gym-authored,
audit, accounting, fraud-prevention and legal records may be retained. The app
does not sell data and advertising identifiers are removed from the Android
manifest.

### Health apps declaration

- Select **Health and fitness → Activity and Fitness**.
- Declare workout/routine tracking, body measurements and weight where prompted.
- Do not declare Health Connect or body-sensor access; the current app requests
  neither.
- Explain that camera access is for user-initiated QR scanning and image capture,
  not health diagnosis or sensing.
- Include this store-description disclaimer: **“FitGy is not a medical device and
  does not diagnose, treat, cure, or prevent any medical condition.”**

### Other App content forms

- Complete the privacy policy, account deletion, ads, target audience, content
  rating, news, government, financial features and advertising-ID forms accurately.
- Declare no ads and no in-app payment processing for the first release.
- Select an adults-only target audience consistent with the in-app 18+ gate.
- Supply reviewer access to a dedicated non-admin production test account. Store
  its password in Play Console instructions, never in Git.
- Add a support email and website matching the public policies.

## Signing and Android App Links

1. Enable Play App Signing when creating the Play Console application.
2. Upload the signed AAB to Internal testing.
3. Copy the **App signing key certificate SHA-256** from **Setup → App integrity**.
4. Add that fingerprint alongside the upload certificate in
   `apps/gym_app/web/.well-known/assetlinks.json`.
5. Register both Play app-signing and upload SHA-1/SHA-256 fingerprints in the
   Firebase Android app. Re-download `google-services.json` if Firebase changes it.
6. Build and redeploy customer Hosting, then run:

   ```sh
   PLAY_APP_SIGNING_SHA256='AA:BB:...' npm run play:check
   npm run play:check:live
   ```

The checked-in fingerprint currently belongs to the upload certificate and is
enough for directly installed signed builds. Google Play-delivered builds require
the Play app-signing fingerprint.

## Firebase release gates

- Register Android Play Integrity in Firebase App Check and verify valid/invalid
  request metrics before enforcing it.
- Confirm callable Functions enforce App Check, Firestore and Storage rules match
  the tested commit, and the release Android application can call every required
  Function.
- Configure Google sign-in fingerprints, authorized domains, phone/SMS policy,
  push notifications, Crashlytics, alerting, budgets and backups.
- Change `platform_public/app_branding` to `name: FitGy` and the production policy
  URLs. Do not edit any other fields unintentionally.
- Verify the deletion scheduler and support-retention scheduler in production logs.

## Beta verification

1. Run the full verification baseline in `AGENTS.md`.
2. Run `npm run play:check` and build a unique release version/code.
3. Upload to Internal testing and inspect the Play pre-launch report and SDK Index.
4. Test on at least one Android 16 device and one lowest-supported Android 7 device:
   sign-up, policy links, Google/email/phone auth, App Check, gym invitation App Link,
   camera QR scan, notification permission and deep link, personal workout/offline
   cache, sharing grant/revocation, export and account deletion.
5. If the Play developer account is subject to a mandatory closed-test period,
   complete it before requesting production access.
6. Promote the exact tested artifact; do not rebuild between test and promotion.

## Release troubleshooting

- Do not rename an older APK and treat the filename as its version. Verify the
  embedded `versionName` and `versionCode`; Play requires a strictly increasing
  version code. The first corrected FitGy build is `1.0.1+2`.
- Install production builds through a Google Play testing track. Production uses
  the Play Integrity App Check provider and App Check-enforced callable Functions,
  so a sideloaded release APK can authenticate and then be rejected when it calls
  the backend. Do not disable App Check to make public sideloads work.
- If Google sign-in fails only in a Play-installed build, add the Play app-signing
  SHA-1 and SHA-256 certificates to the Firebase Android app, enable the Google
  provider, replace `google-services.json`, and rebuild with a new version code.
