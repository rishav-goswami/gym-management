# Member billing and renewal

## What members can do

Open **Membership** from the member workspace.

- **Membership:** view the current plan, start date, valid-until date, remaining
  days, expiry state, and all active plans offered by the gym.
- **Payments:** view personal payment history, open a receipt, see its payment
  method/reference, and share a text receipt.
- **Notifications:** view expiry and renewal messages. Opening an unread message
  marks only that member's notification as read.
- **Request renewal:** choose a plan and send one pending request to the gym. The
  member is explicitly told that this action does not charge money.

The Home screen also shows an orange expiry banner in the final seven days and
a red banner after expiry. The server schedules deduplicated reminders around
7, 3, and 1 day before expiry and on expiry. The emulator seed includes a plan
ending in five days plus one unread reminder so the UI is immediately visible.

## Gym handling

Pending requests appear on the owner billing overview. Staff record the verified
external payment using **Record renewal**. The payment, subscription extension,
and request completion are committed together so the member does not see a paid
request without a matching payment receipt.

## Online checkout boundary

The disabled **Pay online** control is deliberate until a merchant model and
provider account are configured. A production flow must:

1. Create a unique provider order or payment link on Cloud Functions.
2. Open the provider-hosted checkout for UPI/card/netbanking.
3. Treat the app callback only as user feedback, never as proof of payment.
4. Verify the provider signature/webhook on Cloud Functions.
5. Deduplicate the provider payment ID and only then create the immutable
   payment and extend the subscription transactionally.
6. Keep API and webhook secrets in Google Cloud Secret Manager, not Flutter or
   Firestore.

For a multi-tenant product, decide whether every gym connects its own merchant
account or the platform is merchant of record before enabling checkout. The
latter can create settlement, onboarding, refund, tax, and compliance duties.

Relevant implementation references:

- <https://razorpay.com/docs/developer-tools/integrations/standard-checkout/>
- <https://razorpay.com/docs/api/payments/payment-links/>
- <https://firebase.google.com/docs/functions/config-env>

## Emulator check

Sign in as `member@pilotgym.example.com` with `PilotMember!2026`, select Pilot
Gym, then open **Home** and **Membership**. After sending a renewal request, sign
in as the owner and confirm it appears on **Payments → Overview**.
