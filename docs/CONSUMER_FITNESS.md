# Consumer-first fitness spaces

## Product boundary

Every authenticated identity has a permanent private fitness data layer. It is
not a hidden gym tenant and does not require a role or membership. A standalone
consumer sees the platform-branded fitness app. When that person has an active
member affiliation, the same shell dynamically adopts the gym logo/colors and
merges membership billing, trainers, classes, attendance, announcements and gym
assignments into their existing Home, Training, Progress and Profile journey.
Members do not enter a second workspace and do not maintain duplicate workouts.

Owner, manager, receptionist, accountant and trainer operational consoles remain
distinct business contexts. Those roles do not change ownership of personal
workouts or silently create a billable member record.

The remote `platform_public/app_branding.consumerFeatures.personalSpacesV1`
switch gates the new routing. Keep it disabled in an existing environment until
rules, Functions and migrations `003` and `004` have passed acceptance. The
Emulator seed enables it for local testing.

The unauthenticated root waits for the public branding document before choosing
between the consumer introduction and legacy login. The three introduction
screens appear once per browser installation; later visits go directly to sign
in. Clear site data or use a private window to repeat first-install testing.

## Personal data and scope abstraction

`FitnessScope.personal(uid)` maps reusable training and progress features to:

- `users/{uid}/fitness_profile/current`
- `users/{uid}/routines/{id}`
- `users/{uid}/workout_logs/{id}`
- `users/{uid}/measurements/{id}`
- `users/{uid}/goals/{id}`
- `users/{uid}/personal_records/{id}`
- `users/{uid}/progress_photos/{id}`

`FitnessScope.gym(membership)` keeps the established tenant paths. The shared
UI never fabricates a gym ID for a standalone consumer. Personal Storage paths
are under `users/{uid}` and are readable only by that active user. Platform
administrators do not receive direct access through rules.

## Authentication and onboarding

The app supports email/password, phone OTP, Google and Apple providers. Social
provider credentials that collide with an existing verified email are retained
temporarily and linked after the user proves access through the existing
password provider. Provider secrets and Apple Developer identifiers are never
committed.

Enable Google and Apple per Firebase environment. Google needs a Web OAuth
client/secret. Apple web setup needs its Services ID, team ID, key ID, private
key and the Firebase auth-handler return URL; native Apple setup also needs the
released bundle ID and Sign in with Apple capability. Add every Hosting/custom
domain to Firebase authorized domains. Phone authentication still requires SMS
region policy, Android SHA fingerprints and Apple silent-push/APNs setup.

Invitation URLs use the clean HTTPS `/join` route. Android App Links and the
iOS associated-domain entitlement are tracked in the app. Before a store
release, publish `assetlinks.json` using the release signing-certificate SHA-256
and `apple-app-site-association` using the Apple team/bundle identifier at the
Hosting domain. Those account-specific values must be supplied by the release
operator and must not be guessed or copied from another Firebase account.

Before new personal fitness records are created, onboarding records self-attested 18+
confirmation, a versioned policy acceptance and the user’s name. Goals,
experience, weekly frequency and equipment are skippable preferences.

## Gym sharing

Accepting an expiring invitation creates a gym membership but shares no personal
fitness data. The user explicitly controls five categories: profile basics,
goals, workout summaries, measurements and progress.

An invitation link or QR opens a focused confirmation page containing only the
gym, invited role, matched identity and one **Join gym** action. It must not show
the general space selector, **My Fitness**, **Own a gym**, or other acquisition
choices. After acceptance, the app confirms that member services are active,
applies the gym overlay to the same customer shell and keeps personal fitness
private. Choosing fitness sharing is optional and must never block joining or
using the merged app.

Sharing consent changes only which bounded personal summaries authorized gym
staff can view. It does not enable or disable membership, payments, trainer
assignment, classes, attendance, notices or other tenant services. The personal
Profile exposes connected member gyms in a prominent **My gym membership**
section; selecting one opens the tenant-branded Profile/Membership/Settings view
inside the current app rather than navigating to a separate member workspace.
Sharing controls remain a separate, clearly labelled privacy area.

Active member affiliation is a presentation and authorization overlay, not a
fitness-data scope switch. Guided and self-created workouts continue writing to
`users/{uid}`. Trainer assignments are read from the gym and their results enter
the personal log; only consented summaries are projected back to the gym.

The **Your fitness spaces** screen is retained for operational roles and the
uncommon multiple-gym case. Selecting a member gym changes the active branding
overlay but returns to the same personal shell. An owner, manager or trainer
sees an explicit **Open dashboard** action because their business workspace is
genuinely separate. **Start my gym** opens trial provisioning. **Join a gym**
scans the secure invitation QR and also accepts a complete invitation link
copied from email or messaging; raw gym IDs and tokens are never requested.

Space-selector taps are intentionally not counted as a separate feature metric:
they are navigation rather than a meaningful outcome, and destination features
already record bounded, server-validated usage. Invitation acceptance and gym
creation remain the privacy-safe conversion milestones. The focused invitation
confirmation, post-join destination choice and member-profile shortcut do not
add noisy tap analytics; they use the existing invitation-acceptance outcome and
the destination feature outcomes.

Operational role and fitness identity are orthogonal. An owner or trainer can
use personal routines, workout logs and progress without creating a tenant
member record. Member-only business records—membership charges, trainer
assignment, class entitlement and member attendance—do not automatically apply
to staff. The current `gymId_uid` membership model has one gym role per person;
supporting a billable owner/member combination will require a separately
reviewed multi-role migration, rules and Functions change. The app must not
silently convert staff into members or expose their private workouts to the
gym.

Leaving is a privileged callable transition, never a client-side delete.
`leaveGymMembership` changes the membership and gym member profile to `left`,
decrements bounded active-member counters, revokes the sharing grant and deletes
server-owned projections. It does not delete tenant payments, subscriptions,
attendance or audits, and it does not touch personal fitness collections. A
later invitation may reactivate the same deterministic membership record so the
gym retains continuity without duplicating history.

`updateGymSharing` verifies the active membership and maintains server-owned,
bounded projections under `gyms/{gymId}/shared_fitness/{uid}`. Clients cannot
write projections. Disabling a category removes its projection while leaving
tenant operational records intact. Future personal writes are projected only
while the corresponding consent remains enabled.

## Consumer plans, support and deletion

`consumer_plans/free` enables all current core fitness features. Each user has
a server-owned `entitlements/current` snapshot ready for later premium plans;
release one does not process consumer payments.

The platform console lists account summaries and aggregate usage. It never
queries fitness subcollections directly. A support operator must enter a reason
to obtain a 15-minute grant. Every category view creates platform audit data and
a user-visible `support_history` entry.

Suspension revokes refresh tokens and rules deny personal data/media. Account
deletion immediately revokes sharing, disables the Auth user and schedules
personal Firestore and Storage deletion after 30 days. Tenant operational data
continues under the gym retention policy.

## Migration and rollout

Preview numbered migrations before any write:

```sh
npm run migrate:data -- --project YOUR_PROJECT_ID --dry-run
```

Migration `003_personal_fitness_spaces` initializes every Firebase Auth user,
creates the free entitlement/profile and copies member fitness history with
deterministic `gym_<gymId>_<sourceId>` IDs and `legacyGym` source metadata.
Migration `004_personal_progress_media` copies eligible progress images into
private user paths without deleting originals. Both are resumable and are
recorded in `_schema_migrations` only after success.

After backup and staging verification, apply with the exact-project guard:

```sh
npm run migrate:data -- \
  --project YOUR_PROJECT_ID \
  --bucket YOUR_FIREBASE_STORAGE_BUCKET \
  --confirm YOUR_PROJECT_ID
```

Deploy rules/indexes/Storage/Functions first, run cross-user and cross-gym tests,
then enable `personalSpacesV1` from **Platform console → Platform brand**.
