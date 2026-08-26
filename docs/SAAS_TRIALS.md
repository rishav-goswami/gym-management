# Owner trials, quotas, and upgrades

## Customer flow

1. A gym owner creates a normal Firebase identity in the customer app.
2. Firebase sends an email verification link. Phone-auth identities are already
   verified by OTP.
3. On **Choose workspace**, the owner selects **Start my gym** and submits the
   gym name. No owner role can be selected on the public registration form.
4. The `startGymTrial` callable Function verifies the identity, reads the active
   `saas_plans/trial` version, and transactionally creates the tenant, immutable
   owner membership, plan snapshot, entitlements, usage counters, and a
   one-trial-per-UID claim.
5. The owner dashboard shows trial days remaining and current usage versus each
   limit. When a limit is reached, the privileged Function rejects the operation
   with `resource-exhausted`; changing the UI or calling Firestore directly does
   not bypass it.
6. **Upgrade** creates a pending platform request. It never takes money. A
   trusted operator reviews the request in the separate platform console and
   manually approves it after arranging billing.

## Plan documents

Plans live at `saas_plans/{planId}`. They are readable by signed-in customers
when active/public, but no client can write them. The platform console calls
`upsertSaasPlan`; the Function validates the document and increments its
version. A gym receives a snapshot under:

- `gyms/{gymId}/platform_subscription/current`
- `gyms/{gymId}/entitlements/current`
- `gyms/{gymId}/usage/current`

Changing a plan does not silently change existing customer entitlements. A new
snapshot is accepted when an upgrade is approved.

The default emulator seed provides a 14-day trial with 5 active members, 1
trainer, 1 additional staff account, and 3 concurrently scheduled classes.
Started classes are closed by a scheduled Function and release their slot. It also provides
a Starter plan. Edit these defaults from the platform console; do not edit a
gym's counters manually.

## Security properties

- Only a verified Firebase identity can start a trial.
- `trial_claims/{uid}` makes the free trial one-time per identity.
- Owner memberships are created by Admin SDK and are immutable through the
  membership-management callable.
- Invitation acceptance and role/status changes update usage in Firestore
  transactions, preventing last-seat races.
- Member creation and class scheduling are denied by Firestore rules and routed
  through privileged Functions.
- Expired and suspended tenants are rejected by both rules and callable
  authorization checks.
- Platform plan writes and upgrade decisions require the `platformAdmin` custom
  claim. Gym roles remain in Firestore and never become custom claims.

## Local test

Run the Emulator Suite and seed it, then register a fresh email identity. Open
the verification link from the Auth emulator, start a gym, and invite members
until the displayed limit is reached. Confirm the next acceptance is rejected.
Request Starter from the owner dashboard, approve it in the platform console,
and confirm the new limits appear.

These callable workflows run locally without billing. In the cloud they require
Cloud Functions deployment, which requires the Firebase project to use Blaze.
The current upgrade request is manual and does not process cards or UPI.
