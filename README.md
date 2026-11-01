# gjandasher_shiptracker

Flutter app for GJandAsher Digital Printing: outbound parcel tracking, returns,
customer QR registry, analytics, and staff/customer portals.

## Staff registration approvals

New staff accounts are created with `status: pending` and are signed out
immediately. They cannot enter the Staff Portal until an admin/owner approves
them from:

**Profile → Administration → Staff Registration Approvals**

Approving an account sets it to `active` and sends an approval email to the
staff member's registered address. Rejected accounts are blocked at login.

The `users` Firestore rules enforce this workflow:

- customers are created `active`
- staff are created `pending`
- only an admin can change another user's role or status
- users can never change their own role or status

Deploy the rules with:

```powershell
firebase deploy --only firestore:rules --project shiptracker-v2
```

## Transactional email

Approval and password-reset emails are sent through a Cloudflare Worker using
Resend. See [`backend/email-worker/README.md`](backend/email-worker/README.md)
for domain verification, DNS/SPF/DKIM/DMARC setup, secrets, deployment, and
deliverability guidance.

Build the app with the worker URL and shared key:

```powershell
flutter build apk --release `
  --dart-define=EMAIL_WORKER_URL=https://your-worker.workers.dev `
  --dart-define=EMAIL_API_KEY=your-shared-key
```

If the worker is not configured, staff approval still succeeds in Firestore
(the admin sees a warning), and password reset falls back to Firebase Auth's
built-in reset email.

> Inbox placement cannot be guaranteed by code. A verified sending domain with
> SPF, DKIM, and DMARC is the standard way to maximize deliverability.

## Merged branch

This branch combines:

- the Art repository's `backup/staff-approval-updated` branch (staff
  registration approval, transactional email worker, public privacy/terms/
  account-deletion pages, auth hardening, and the Android package rebrand), and
- the GJ repository's `ui-logo-blue-restyle` branch (logo-blue visual system,
  refreshed screens, and device/layout fixes).

The Android application ID is `com.gjandasher.digitalprinting` and the launcher
uses the adaptive icon set. Firebase configuration in
`android/app/google-services.json` matches that package.

## Google Sign-In on Play Store builds

Google Sign-In validates the certificate that signed the installed APK. Google
Play re-signs every release with its **app signing key**, so that certificate
must be registered in Firebase in addition to the local upload key.

1. Play Console → **Setup → App integrity → App signing** → copy the
   **app signing key SHA-1**.
2. Firebase Console → **Project settings → Your apps → Android app**
   (`com.gjandasher.digitalprinting`) → **Add fingerprint** and add:
   - the Play app signing key SHA-1 (required for installs from Google Play),
   - the upload key SHA-1 (required for locally built release APKs).
3. Optionally download the refreshed `google-services.json` over
   `android/app/google-services.json`. The web client ID does not change, so
   this is only needed to keep the file in sync.
4. Check **Google Cloud Console → APIs & Services → OAuth consent screen**
   (or **Google Auth Platform → Audience**). While the publishing status is
   *Testing*, only listed test users can complete Google Sign-In. Publish the
   app; the `email` and `profile` scopes do not require verification.

`lib/features/auth/data/auth_repository.dart` passes the project's web OAuth
client as `serverClientId` so Google Sign-In always returns an `idToken`, and
`lib/features/auth/presentation/auth_error_text.dart` turns Firebase/Google
errors into readable messages.

Because the certificate check happens on Google's servers, adding the missing
SHA-1 fixes already-installed Play builds without shipping a new version.

## Accounts created before the Play Store release

Accounts live in the Firebase project (`shiptracker-v2`), not in the installed
app, so they keep working after reinstalling from Google Play. Profiles created
before the approval workflow have no `status` field; `UserProfileModel` treats
a missing status as `active` (covered by `test/user_profile_model_test.dart`).

If an existing staff member cannot sign in with their password, open
**Firebase Console → Authentication → Users**, find the account and use
**Reset password** — or use "Forgot Password?" in the app. Accounts that were
created with *Continue with Google* have no password and must use the Google
button.

## Staff registration approvals

New staff accounts are created with `status: "pending"` and are signed out
immediately after sign-up. They cannot reach any portal until an owner/admin
approves them from **Profile → Staff Approvals**:

- pending staff see "Your staff account is still awaiting admin approval"
- rejected staff see a permanent rejection message
- the router also blocks pending/rejected accounts that still have a cached
  Firebase session

### Deploying the Firestore rules

The role checks are case-insensitive (`"Admin"`, `"STAFF "`, …) so profiles
created before the approval workflow keep working. The rules must be deployed
whenever `firestore.rules` changes:

```powershell
firebase deploy --only firestore:rules --project shiptracker-v2
```

The Staff Approvals screen needs `list` access to the `users` collection, which
only staff/admin accounts have. If it shows
`[cloud_firestore/permission-denied]`, the deployed rules are out of date or the
signed-in profile stores a role that is not `admin`/`staff`.

## Development

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

### VS Code

1. Install the **Flutter** and **Dart** extensions (VS Code will also suggest
   them from `.vscode/extensions.json`).
2. Open this project folder in VS Code.
3. Select an Android emulator/device from the status bar, then press `F5` and
   choose **GJandAsher (Debug)**.
4. Use **Terminal → Run Task** for `Flutter: pub get`, `Flutter: analyze`,
   `Flutter: test`, or `Flutter: build debug APK`.

The checked-in `.vscode` files contain launch configurations, recommended
extensions, formatting settings, and common Flutter tasks. They do not contain
machine-specific SDK paths, so each developer can use their own Flutter
installation.
