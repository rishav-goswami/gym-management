# FitGy Web Deployment and Secure Razorpay Billing Plan

## Summary

FitGy’s APK is already on Google Play Internal testing, but it is not production-ready. Immediate blockers are live policy pages/branding, authentication validation, Play declarations, App Check/signing verification, and release testing. Payments are not technically required by Google Play if the app accurately says payments happen offline, but they are a business-launch requirement for the intended product.

A solo developer can operate this incrementally. Razorpay supports sole-proprietor KYC, but live payments remain disabled until the merchant account, tax treatment, refund terms, and Razorpay products are approved. [Razorpay account setup](https://razorpay.com/docs/payments/set-up/?preferred-country=IN)

Billing will be split by what is being purchased:

- Gym owner → FitGy SaaS: Razorpay Subscriptions on the FitGy web app only. Mobile apps display existing plan status but do not link to external checkout.
- Member → gym membership: Razorpay Checkout inside Android/iOS/web, including UPI Intent and return to FitGy. This is a physical-service payment and does not require Apple/Google digital billing. [Google Play payment rules](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en-GB), [Apple payment rules](https://developer.apple.com/app-store/review/guidelines/)
- Member payments use Razorpay Route linked gym accounts with a 2% FitGy commission and one-time renewals.

## Implementation Changes

### 1. Deploy the current web builds first

- Run the complete repository security, Functions, Flutter app, console, portability, and Play release checks.
- Build both production web applications with their existing App Check keys.
- Deploy only the `gym-app` and `platform-console` Hosting targets to the explicitly selected Firebase project `createmix-in`; do not deploy Functions/rules in this initial step.
- Verify:
  - `https://createmix-gym-app.web.app/`
  - privacy, terms, deletion and `assetlinks.json`
  - `https://createmix-gym-admin.web.app/`
  - App Check, authentication and platform-admin denial
  - live FitGy branding and policy URLs
- Run `npm run play:check:live` and retain the previous Hosting release as the rollback target.

### 2. Complete payment-provider and legal prerequisites

- Create a Razorpay sole-proprietor account, complete KYC and bank verification, then enable test mode.
- Request Razorpay Subscriptions for FitGy SaaS and Route/Technology Partner access for connected gym accounts.
- Treat Route approval as a hard gate. If FitGy is not eligible, keep member online payment disabled and retain the existing externally-recorded payment flow.
- Before live mode, obtain professional confirmation for GST, TDS/e-commerce marketplace obligations, invoices, refunds and the 2% commission contract.
- Update privacy, terms, refund policy, Data Safety and Play declarations to disclose Razorpay, purchase history, provider identifiers, connected gyms, settlements and retention.
- Never store PAN, bank credentials, card data, UPI PINs, Razorpay secrets or raw KYC documents in Firebase.

### 3. Owner SaaS billing on web

- Preserve `saas_plans` as the public catalog but add immutable version records. Every price/currency/cadence change creates a new version and Razorpay Plan rather than modifying an active provider plan.
- Support all platform-console plans that are public, INR-denominated and monthly or annual. A plan becomes purchasable only after its current version has a valid Razorpay mapping.
- Replace the web upgrade request with Razorpay Subscription checkout. Android/iOS show current plan, expiry and support contact only—no external payment link or pricing CTA.
- Add a seven-day grace period after a failed renewal. During grace, entitlements remain active; afterward gym operations are suspended while data, export/support access and personal fitness remain preserved. A verified recovery webhook reactivates access.
- Cancellation takes effect at the paid period end. SaaS refunds remain platform-admin/manual in v1.

### 4. Member-to-gym payments

- Onboard each gym as a Razorpay Route linked account; only a verified gym owner can start onboarding.
- Add native Razorpay Checkout to Android/iOS and Standard Checkout on web. The native callback only shows “verifying payment”; it never activates membership.
- `createMemberPaymentOrder` validates authentication, active membership, tenant, selected plan and server-side price, then creates one INR Razorpay order.
- On verified `payment.captured`, create the immutable payment receipt and extend the membership using the existing transactional renewal rules exactly once.
- Financial calculation:
  - Member pays the advertised gym price with no surcharge.
  - FitGy commission is `floor(grossMinor × 2%)`.
  - Razorpay’s returned `payment.fee` already includes its tax and is deducted before calculating the gym transfer.
  - Gym transfer is `grossMinor - FitGy commission - payment.fee`.
  - Route transfer fees are borne from FitGy’s retained commission.
  - Do not enable live payments if configured fees make the transfer or FitGy balance invalid.
- Provide itemized gym settlement reports showing gross payment, 2% FitGy commission, provider fee, transfer and settlement status.
- Support gym-owner-approved full refunds only. The payment must be the member’s latest renewal with no later payment. After the verified refund/reversal webhook, create an immutable refund event and restore the pre-payment subscription snapshot. Unsafe cases go to platform support without automatic mutation.
- Return the full member-paid amount; reverse FitGy commission and gym transfer. Any non-refundable provider charges are borne by the gym under the merchant agreement.

## Functions, Data and Security Interfaces

- Add callable Functions:
  - `publishSaasBillingVersion`
  - `createPlatformSaasCheckout`
  - `cancelPlatformSaasSubscription`
  - `startGymPaymentOnboarding`
  - `createMemberPaymentOrder`
  - `requestMemberPaymentRefund`
- Add a public HTTPS `razorpayWebhook` and a scheduled reconciliation Function.
- Store provider mappings, checkout attempts, events, refunds and settlement projections in server-written billing collections. Clients receive only the minimum checkout ID/public key and scoped status projections.
- Store Razorpay API and webhook secrets in Google Cloud Secret Manager. Use separate test/live secrets.
- Verify webhook HMAC against the unmodified raw body with constant-time comparison; deduplicate `x-razorpay-event-id`; tolerate duplicate and out-of-order delivery. [Razorpay webhook guidance](https://razorpay.com/docs/webhooks/validate-test/?locale=en-US)
- Before changing entitlements or money records, fetch the provider object and verify captured status, order/subscription ID, gym/member ownership, amount, currency and environment.
- Require App Check, authenticated ownership and rate limiting on callables. Webhooks use signature verification because App Check does not apply.
- Add an owner-only `payments.refund` permission. Continue denying all direct client writes to payments, subscriptions, entitlements, provider accounts, refunds and webhook events.
- Add privacy-safe analytics identifiers for SaaS checkout, merchant onboarding and member online payment. Record aggregate outcomes only—never payment credentials, provider IDs, health data or message content.

## Test and Release Plan

- Unit-test amount calculations, immutable plan versions, grace periods, subscription recovery, cancellation and refund restoration.
- Function/rules tests must cover forged prices, cross-tenant orders, non-owner onboarding/refunds, replayed/out-of-order webhooks, invalid signatures, incorrect amounts/currencies, duplicate captures and direct Firestore writes.
- Mock Razorpay for Emulator Suite tests; then validate real test-mode checkout/webhooks in a dedicated Firebase staging project before deploying payment Functions to `createmix-in`.
- Test member checkout on physical Android and iOS devices: card failure, UPI app handoff, cancellation, return-to-app, delayed webhook, duplicate webhook, captured payment, transfer and full refund.
- Test web SaaS subscription activation, failed renewal, seven-day grace, recovery and cancellation.
- Re-run the complete AGENTS verification baseline, Play checks, SDK Index/Data Safety review, Android pre-launch report and iOS TestFlight review.
- Production rollout order:
  1. Current Hosting deployment and policy verification.
  2. Razorpay test-mode SaaS for internal users.
  3. One pilot gym with Route and member payments.
  4. Controlled live payments after KYC/legal approval.
  5. Google Play production and iOS App Store submission only after authentication and all visible flows pass.

## Assumptions and Defaults

- Firebase project `createmix-in` remains production; a separate project is used for payment staging.
- Owner SaaS purchasing is web-only; mobile consumption of an existing organizational subscription is allowed.
- Member payments are one-time gym-membership purchases, not AutoPay.
- FitGy commission is 2%.
- Because Razorpay Customer Fee Bearer is unavailable with Route, the member pays no added fee; provider fees reduce the gym transfer. [Razorpay fee limitation](https://razorpay.com/docs/payments/optimizer/convenience-fees/?locale=en-US)
- Refunds are full, gym-owner-approved and limited to safely reversible latest renewals.
- Failed owner SaaS renewals receive a seven-day grace period.
- Live billing remains feature-flagged off until Razorpay Subscriptions, Route, KYC, fee economics and tax treatment are approved.
