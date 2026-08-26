# Security policy

## Credentials

Never commit Firebase Admin SDK service-account files, private keys, signing
certificates, OAuth client secrets, refresh tokens, production `.env` files, or
payment-provider secret keys. Store server credentials in Google Secret Manager
or the deployment platform's protected environment.

FlutterFire-generated client configuration (`firebase_options.dart`,
`google-services.json`, and `GoogleService-Info.plist`) contains public app
identifiers. Firebase client API keys identify the project; they do not authorize
database access. Keep those keys restricted to Firebase APIs and protect data
with Authentication, Security Rules, and App Check.

Run `npm run security:check` before pushing. This repository also provides a
pre-commit hook in `.githooks`; configure it once with:

```sh
git config core.hooksPath .githooks
```

Do not broaden `.github/secret_scanning.yml`. Its exact paths only suppress
known false positives in generated FlutterFire client configuration.

## Reporting

Do not open a public issue containing credentials or private customer data.
Contact the repository owner privately and rotate any genuinely exposed secret
before publishing details.
