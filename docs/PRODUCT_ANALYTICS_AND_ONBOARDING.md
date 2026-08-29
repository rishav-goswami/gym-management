# Product analytics, feedback and member onboarding

## Purpose

The platform console needs product signals without exposing member-private
records or depending on raw Firebase Analytics export. The customer app records
bounded aggregate feature-open events and accepts deliberate written feedback.
The member profile supplies non-medical inputs for general exercise selection.

## Feature analytics

`trackFeatureUsage` accepts an explicit `personal` or `gym` scope. Gym events
validate an active membership; personal events validate an active consumer. It
increments:

- `platform_feature_metrics/{featureId}` for platform-wide totals and role
  segments;
- `gyms/{gymId}/feature_metrics/{featureId}` for tenant-level totals.

Platform metrics segment `scope_personal`/`scope_gym` and bounded audiences such
as standalone, member, trainer and owner. Funnel milestones cover registration,
onboarding, first routine, first workout, first progress entry, invitation
acceptance, membership leave and gym creation. `membershipLeave` is recorded
server-side only after a successful deactivation and contains no reason, health
data or tenant history. These remain directional counters rather than a
health-data event stream.

Counters identify the gym and audience role, but platform aggregates do not
store a per-user event history. They are directional product metrics, not
billing records or proof of workout completion. Firebase Analytics remains the
preferred source for funnels, retention and release-level telemetry when a
privacy-reviewed BigQuery workflow is introduced.

A private server-owned throttle document limits the same user, gym and feature
to one counted open per 15 minutes. It is not readable or writable by clients
and prevents accidental navigation loops from distorting the counters.

The merged member gym-services surface reuses the stable `attendance` and
`classes` identifiers. Opening an enabled service and successful check-in,
booking or scheduling actions feed the same throttled gym-scoped adoption
counter; QR contents, class names, attendance records and booking details are
never included in analytics metadata. The platform console therefore measures
feature adoption without becoming a source of member activity history.

The support hub uses stable `supportTrainer`, `supportGym` and
`supportPlatform` identifiers. The server derives gym/personal scope, audience
and category and records bounded outcomes for case creation/routing, claim,
first response, resolution and reopen. Message text, attachments, exercise
labels, workout records and health content are never analytics metadata.
Resolution feedback is optional and must use the existing bounded rating/text
contract without copying conversation content.

## New feature observability checklist

Feature monitoring is part of the implementation, not a follow-up task. For
each user-facing capability introduced or materially changed:

1. Assign a stable, non-sensitive `featureId` and add it to the server allowlist.
   Do not build identifiers from user, gym, exercise or health data.
2. Prefer meaningful outcomes such as opened, started, completed, saved or
   shared. Avoid logging every tap, set, repetition or measurement.
3. Send `scopeType` as `personal` or `gym`; Functions must validate membership
   and derive trusted audience segments rather than accepting client-forged
   roles or gym identifiers.
4. Count recurring events through a bounded throttle and record activation
   milestones idempotently so retries and navigation loops do not inflate the
   dashboard.
5. Add a contextual feedback entry point after meaningful use when feedback can
   improve the feature. Accept a bounded rating and optional short message;
   never attach workout logs, measurements, photos, conversations or payment
   details.
6. Add or update an aggregate console tile, trend or audience comparison that
   explains an actionable product question. Do not expose individual health or
   fitness activity to ordinary console queries.
7. Test rejected feature identifiers, forged scope/audience/gym data,
   cross-tenant access, throttling/idempotency and feedback sanitization.
8. Document the event meaning and manually verify that its aggregate and
   feedback view work before enabling the feature's rollout flag.

If a feature intentionally has no analytics or feedback surface, record the
privacy, safety or usefulness reason in its canonical document so the omission
is deliberate and reviewable.

## Feedback

`submitFeatureFeedback` creates a server-authored `platform_feedback` record
with feature, rating, message, gym and role. Only platform administrators can
read this collection. Feedback must not be used for trainer/member surveillance
or exposed to other gyms. The server accepts at most one submission for the
same user, gym and feature every five minutes.

## Member recommendation profile

Consumers maintain `users/{uid}/fitness_profile/current` in personal space.
Members may also maintain the corresponding allowed fields in their existing
`gyms/{gymId}/members/{uid}` tenant profile:

- display name, phone and tenant-private profile image path;
- height and weight;
- training experience and one or more fitness goals;
- preferred workout days and available equipment;
- optional limitations for trainer context.

The app currently selects the first declared fitness goal to choose a general
exercise session. This is deterministic guidance, not an autonomous medical or
nutrition prescription. Limitations are displayed as context but are not
interpreted into diagnosis, injury advice or rehabilitation routines.

Profile images use `gyms/{gymId}/profiles/{uid}/...` in Firebase Storage. Only
the member can write their path; active tenant users can read it so authorized
staff and trainers can identify the member.

The member's merged customer navigation keeps **Profile** in the fourth mobile
slot. Personal account/preferences and sharing stay in that screen. Opening
**My gym membership** presents the tenant Profile/Membership/Settings view
inside the same shell for gym-owned details, billing/reminders and the secure
leave action. Owners see a searchable member directory with the member's name,
contact, onboarding state, account state, plan, and expiry instead of raw
Firebase user IDs.

Invitation acceptance snapshots the verified Firebase Auth name, email and
phone into the tenant member profile. `hydrateMemberProfiles` is a bounded,
permission-checked compatibility repair for profiles created before that
contract existed; the numbered data migration provides the portable bulk path.

## Platform subscription controls

Plan documents define base limits and features. `setGymSubscription` applies an
active plan snapshot plus optional per-gym feature overrides to the gym,
subscription and entitlement documents atomically. Owners see effective
features but cannot mutate them.
