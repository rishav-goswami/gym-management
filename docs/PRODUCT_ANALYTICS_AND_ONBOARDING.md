# Product analytics, feedback and member onboarding

## Purpose

The platform console needs product signals without exposing member-private
records or depending on raw Firebase Analytics export. The customer app records
bounded aggregate feature-open events and accepts deliberate written feedback.
The member profile supplies non-medical inputs for general exercise selection.

## Feature analytics

`trackFeatureUsage` validates an active gym membership and increments:

- `platform_feature_metrics/{featureId}` for platform-wide totals and role
  segments;
- `gyms/{gymId}/feature_metrics/{featureId}` for tenant-level totals.

Counters identify the gym and audience role, but platform aggregates do not
store a per-user event history. They are directional product metrics, not
billing records or proof of workout completion. Firebase Analytics remains the
preferred source for funnels, retention and release-level telemetry when a
privacy-reviewed BigQuery workflow is introduced.

A private server-owned throttle document limits the same user, gym and feature
to one counted open per 15 minutes. It is not readable or writable by clients
and prevents accidental navigation loops from distorting the counters.

## Feedback

`submitFeatureFeedback` creates a server-authored `platform_feedback` record
with feature, rating, message, gym and role. Only platform administrators can
read this collection. Feedback must not be used for trainer/member surveillance
or exposed to other gyms. The server accepts at most one submission for the
same user, gym and feature every five minutes.

## Member recommendation profile

Members can maintain their own `gyms/{gymId}/members/{uid}` fields:

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

## Platform subscription controls

Plan documents define base limits and features. `setGymSubscription` applies an
active plan snapshot plus optional per-gym feature overrides to the gym,
subscription and entitlement documents atomically. Owners see effective
features but cannot mutate them.
