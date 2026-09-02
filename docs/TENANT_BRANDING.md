# Tenant branding

The customer application is published as **FitGy** and applies each selected
gym's brand at runtime. Gym Management remains the service operator and control
plane name. A gym does not require a separate APK, IPA, web build, or Firebase
project.

## Managed fields

The tenant document `gyms/{gymId}` stores the public name, phone, city, website,
currency, timezone and locale. Its `branding` map stores:

- `logoUrl`
- `primaryColor`, `secondaryColor`, and `accentColor` as `#RRGGBB`
- `tagline`

The selected gym is watched in realtime. Members see changes to the app title,
logo, navigation theme, accent colors, and home tagline without signing out or
installing a new build.

## Platform workflow

1. Sign into the private platform console.
2. Use **Provision gym** and enter the email of an identity that has already
   registered in the customer app. The Function resolves the Firebase UID and
   creates the owner membership securely.
3. Select **Manage** on a tenant.
4. Upload a square logo, enter the palette and business profile, inspect the
   preview, and save.

The platform console calls `updateGymAsPlatformAdmin`; it cannot write tenant
documents directly.

## Owner workflow

Owners and managers with `staff.manage` open **Branding** in their gym
workspace. They can upload a logo and edit the same approved profile fields.
Other roles do not receive this destination and the callable Function rejects
unauthorized updates.

Logo uploads use `gyms/{gymId}/branding/`. Storage rules allow writes only to a
trusted platform administrator or an active owner/manager, require an image
content type, and limit files to 10 MB. Public reads are intentional because a
gym logo is public brand material. Exercise guidance and private progress media
use separate paths and policies.

## Project migration

Branding document fields move with the Firestore export. Copy the Storage
bucket as described in `INFRASTRUCTURE_AND_MIGRATION.md`, then verify logo URLs.
If the Firebase download hostname or token changes, re-upload the logo or
rewrite `branding.logoUrl` during the destination migration.
