# Payments and subscriptions

Release one records payments received outside the app through UPI, cash, card,
bank transfer, or another method. It does not process money or store card data.

## Owner workflow

Open **Payments** in an owner, manager, receptionist, or accountant workspace.
The available actions still follow that person's Firestore permissions.

1. Open **Plans** and create the gym's membership offerings. Each plan has a
   name, description, price in integer minor units, duration, and active state.
2. Open **Record renewal** and select an active member and active plan. Staff no
   longer enter Firebase UIDs or arbitrary plan IDs.
3. Confirm the received amount and payment method. Add a transaction reference
   when available. If the amount differs from the plan price, an internal note
   is required for auditability.
4. Submit once. The Function creates an immutable payment and updates that
   member's subscription in one Firestore transaction.
5. Use **Subscriptions** to find active, expiring, or expired memberships. Use
   **Payments** to search by member, receipt, plan, or external reference.
6. Use **Export** to download separate payment and subscription CSV reports.

## Renewal rules

- Renewing an expired membership starts on the requested date.
- Renewing early starts the new period after the current active period ends.
- The server reads price and duration from the selected active plan.
- The received amount is stored separately from the plan list price so a
  discount or adjustment remains visible.
- Every payment gets a receipt identifier such as `PAY-AB12CD34`.
- Payment documents cannot be created, edited, or deleted directly by Flutter.
- Plan writes also use a privileged Function; inactive plans stay in historical
  records but cannot be selected for a new renewal.

## Emulator verification

Seed data contains Monthly Unlimited, Quarterly Value, and Annual Pro plans.

```sh
npm run emulators
npm run seed
cd apps/gym_app
fvm flutter run -d chrome \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true
```

Sign in as `owner@pilotgym.example.com` with `PilotOwner!2026`, select Pilot
Gym, and open **Payments**. After recording a renewal, inspect these paths at
<http://127.0.0.1:4000/firestore>:

- `gyms/pilot-gym/membership_plans`
- `gyms/pilot-gym/subscriptions`
- `gyms/pilot-gym/payments`
- `gyms/pilot-gym/audit_logs`
- `gyms/pilot-gym/dashboard_metrics/current`

## Current boundary and next billing increments

Implemented now: plans, manual payments, atomic renewals, subscription health,
search/filter, receipts, references/notes, member renewal requests, expiry
reminders, revenue aggregation, audit events, and CSV export.

Still intentionally pending: verified online checkout, refunds/reversals,
pause/freeze with date extension, partial or installment balances, invoice
PDF/GST fields, coupons, and owner SaaS billing. These should be added as
explicit accounting events rather than by editing historical payments. See
[`MEMBER_BILLING.md`](MEMBER_BILLING.md) for the online-payment boundary.
