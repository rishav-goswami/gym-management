# Infrastructure, provisioning, and Firebase migration

## What is reproducible

The platform uses three layers instead of pretending one tool controls every
Firebase product:

1. `infra/terraform/` provisions a new Google Cloud/Firebase project, required
   APIs, billing attachment, Firestore location/protection/PITR, Auth providers,
   registered apps, Hosting sites, and optional backups.
2. `firebase.json` plus `firebase/` deploys application-owned rules, composite
   indexes and TTL policies, Storage rules, Functions, Remote Config, Hosting
   behavior, and the Emulator Suite through the Firebase CLI.
3. `firebase/migrations/` holds numbered, forward-only Firestore schema/config
   migrations. `firebase/functions/src/seed.ts` remains disposable emulator demo
   data and is not a production migration.

Current forward migrations include foundation metadata, tenant member identity,
consumer personal-space initialization/history copy, and progress-photo media
copy. The consumer migrations use deterministic IDs, preserve tenant originals,
report candidates during `--dry-run`, and are safe to resume. See
[`CONSUMER_FITNESS.md`](CONSUMER_FITNESS.md) before enabling the rollout switch.

Run the local consistency check after infrastructure changes:

```sh
terraform -chdir=infra/terraform init -backend=false
npm run infra:check
npm run security:check
```

The Terraform state is not committed. Production state belongs in an encrypted
remote backend with narrow IAM access and state locking. Firebase client API keys
are application identifiers, but service accounts, Auth hash parameters,
Terraform variable files, migration exports, signing keys, and provider secrets
must never enter Git.

`infra/terraform/backend.hcl.example` configures a GCS state backend. Create its
bucket once in a trusted administration project, enable object versioning, and
keep the real `backend.hcl` ignored. This state bucket must not live in a project
that the same Terraform state might replace or retire.

## Provisioning a clean account/project

1. Decide permanent project IDs, Firestore location, package/bundle IDs, and
   globally unique Hosting site IDs. Firestore location and released store IDs
   are especially difficult or impossible to change later.
2. Copy `infra/terraform/terraform.tfvars.example` to an ignored environment
   file, set the destination billing account, run `terraform plan`, review it,
   and apply it. Detailed commands are in `infra/terraform/README.md`.
3. Run the Hosting target commands printed by `terraform output` and add the new
   project alias to `.firebaserc`.
4. Run FlutterFire separately for `apps/gym_app` and the web-only
   `apps/platform_console`. Keep their Firebase Web Apps and Hosting sites
   separate.
5. Deploy Firestore rules and indexes before importing data, then Functions and
   Remote Config. Provision the default Storage bucket in step 7 before
   deploying Storage rules.
6. Run the Firestore migrations with `--dry-run`, followed by the exact-project
   confirmation. Bootstrap a platform administrator with
   `scripts/bootstrap-cloud.mjs`.
7. Create Firebase Storage, deploy its rules, and then provision the versioned
   core exercise media without adding it to the app binary:

   ```sh
   npm run storage:provision -- --project YOUR_PROJECT_ID --location YOUR_STORAGE_LOCATION --dry-run
   npm run storage:provision -- --project YOUR_PROJECT_ID --location YOUR_STORAGE_LOCATION --confirm YOUR_PROJECT_ID
   firebase deploy --project YOUR_PROJECT_ID --only storage
   npm run storage:cors -- --project YOUR_PROJECT_ID --dry-run
   npm run storage:cors -- --project YOUR_PROJECT_ID --confirm YOUR_PROJECT_ID
   npm run catalog:manifest
   npm run catalog:sync -- --project YOUR_PROJECT_ID --dry-run
   npm run catalog:sync -- --project YOUR_PROJECT_ID --confirm YOUR_PROJECT_ID
   ```

   The commands are safe to rerun: Storage CORS is replaced with the tracked
   policy, existing versioned objects are skipped, and source commit/license
   metadata is tracked in both the manifest and project. The default wildcard
   CORS origin supports Firebase Hosting, local Flutter web ports, and migrated
   Hosting domains; Firebase Storage Rules still control authorization. Pass
   `--origins URL,...` when an environment deliberately uses a fixed allowlist.
8. Configure console-only services: Google and Apple Auth provider credentials,
   App Check provider/enforcement, APNs and FCM, Android SHA fingerprints,
   authorized Auth domains, SMS region policy, custom domains/DNS, budget alerts,
   Function secrets, and store signing credentials.
   These contain external trust relationships and are intentionally not guessed
   by the repository.

## Moving live data to another Firebase project

Treat a project move as a release with a maintenance window. Both source and
destination must use Blaze for managed Firestore export/import. Practice the
entire sequence on staging first.

### 1. Prepare and freeze

- Back up the source and record document/user/object counts.
- Deploy destination rules and indexes first.
- Stop client and Admin SDK writes for the final export. Firestore rules alone do
  not stop privileged Function/Admin SDK writes.
- Keep the old project intact and read-only until acceptance checks pass.

### 2. Preserve Firebase Authentication UIDs

Export users into the ignored `.firebase-migration/` directory:

```sh
mkdir -p .firebase-migration
npx firebase auth:export .firebase-migration/auth-users.json \
  --project SOURCE_PROJECT_ID --format=json
```

In the source Firebase Console, retrieve the Auth password-hash parameters. They
are sensitive; store them in a password manager, not this repository. Import the
users before Firestore so their original `localId`/UID continues to match
memberships and tenant documents:

```sh
npx firebase auth:import .firebase-migration/auth-users.json \
  --project DESTINATION_PROJECT_ID \
  --hash-algo=SCRYPT \
  --hash-key='VALUE_FROM_SECRET_STORE' \
  --salt-separator='VALUE_FROM_SECRET_STORE' \
  --rounds=ROUNDS --mem-cost=MEM_COST
```

Reapply the `platformAdmin` claim using the destination bootstrap command and
verify any other custom claims. Gym roles do not need claim migration because
they live in Firestore memberships.

### 3. Move Firestore

Create a Cloud Storage export bucket in the Firestore database location, export
the source, grant the destination Firestore service agent access to the export,
and import the exact output URI:

```sh
gcloud firestore export gs://YOUR_EXPORT_BUCKET/firebase-move \
  --project=SOURCE_PROJECT_ID --database='(default)'

gcloud firestore import gs://YOUR_EXPORT_BUCKET/firebase-move/EXACT_EXPORT_PREFIX \
  --project=DESTINATION_PROJECT_ID --database='(default)'
```

Use the output URI returned by `gcloud firestore export`; do not invent it.
Imports retain document IDs, overwrite matching imported documents, leave
unrelated destination documents untouched, and do not trigger Firestore
Functions. Cross-project bucket IAM is required.

### 4. Move Storage objects

After creating/attaching the destination Firebase Storage bucket and deploying
its rules, copy objects with Google Cloud Storage tooling:

```sh
gcloud storage rsync --recursive \
  gs://SOURCE_FIREBASE_BUCKET gs://DESTINATION_FIREBASE_BUCKET
```

Check object counts, content types, cache controls, and progress-photo access.
Do not copy bucket IAM blindly; the destination Firebase service agents and
rules own access.

### 5. Reconfigure and cut over

- Deploy Remote Config, Functions, rules, indexes, and both web builds.
- Run `catalog:sync` for the destination. Core media can also be copied with the
  remaining bucket, but rerunning the manifest is deterministic and avoids
  coupling it to customer-uploaded objects.
- A new Firebase project does not receive a default Storage bucket from
  Terraform. Run `storage:provision` once with an explicit location before
  deploying Storage rules or syncing media. It is idempotent and refuses an
  immutable location mismatch.
- Reapply `storage:cors` after creating or moving the bucket. Bucket CORS is not
  carried by Firebase rules or the exercise-media manifest.
- Recreate Function secrets; they are not present in Git or Firestore exports.
- Regenerate Flutter Firebase options/native config files and release updated
  mobile apps. Old installed builds continue talking to the old project.
- Reconfigure App Check, APNs, OAuth/phone Auth, custom domains, Analytics,
  Crashlytics, alerts, and scheduled backups.
- FCM registration tokens are tied to the Firebase project. Do not trust copied
  tokens; clients must register fresh destination tokens.
- Validate login, multi-gym switching, invitations, tenant isolation, media,
  payments, attendance, routed support, notifications, and scheduled Functions.
- Compare counts and samples, then switch DNS/traffic. Retain the source in a
  protected read-only state for the agreed rollback period.

## What an export does not replace

Firestore export does not include Auth users, Storage objects, rules, indexes,
Functions, Remote Config, App Check, secrets, IAM, billing, Hosting releases,
Analytics history, Crashlytics history, or mobile-store configuration. This is
why provisioning code, Firebase CLI configuration, data migrations, and the
operational runbook are all required.

Migration `005_unified_support_hub` is part of the portable schema sequence. It
uses deterministic thread/inbox IDs, preserves legacy conversations, and may be
resumed after interruption. The tracked Remote Config defaults
`gym_support_enabled`, `platform_support_enabled`, and
`support_images_enabled`, Firestore/Storage rules, indexes, Functions, and the
12-month purge scheduler must move with it. `firebase.test.json` provides
isolated Emulator Suite ports so rule tests can run while the normal local
development emulators are already active.
