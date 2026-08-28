# Firestore data migrations

These are numbered, forward-only migrations for durable platform configuration
and schema transformations. They are separate from emulator demo data and from
Firestore backup/import operations.

Rules:

- Never edit an applied migration; add the next numbered file.
- Make migrations idempotent and safe to retry.
- Never put user credentials, production exports, or service-account JSON here.
- Record completion in `_schema_migrations/{migrationId}`.
- Test against the Emulator Suite or a disposable Firebase project first.
- Back up production and stop writers before a risky transformation.

Authentication uses Application Default Credentials. For local administration,
run `gcloud auth application-default login`; CI should use workload identity,
not a downloaded service-account key.

Preview pending migrations:

```sh
npm run migrate:data -- --project demo-gym-dev --dry-run
```

Dry-run output includes candidate Auth users, member memberships and legacy
progress-photo documents for the personal-space migrations. Migration 003 uses
deterministic IDs and migration 004 copies media while preserving tenant
originals, so interrupted runs are resumable.

Apply after checking the exact project:

```sh
npm run migrate:data -- \
  --project YOUR_PROJECT_ID \
  --bucket YOUR_FIREBASE_STORAGE_BUCKET \
  --confirm YOUR_PROJECT_ID
```
