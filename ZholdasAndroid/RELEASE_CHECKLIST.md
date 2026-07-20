# Android release checklist

Keep all credentials and signing files outside version control. The patterns for the
files below are included in `.gitignore`; still inspect the release bundle before upload.

## 1. Final application identity

- Replace the temporary `com.example.zholdas` `applicationId` and namespace in
  `app/build.gradle.kts` before creating the Play Console application. Choose the final
  ID once: Google Play does not allow changing an application's package name later.
- Update package declarations and any Firebase/Maps restrictions to the same ID.
- Increase `versionCode` for every Play upload and set the public `versionName`.

## 2. Google Maps

1. Enable **Maps SDK for Android** in the production Google Cloud project.
2. Create an Android-restricted API key. Restrict it to the final package name and the
   SHA-1 certificate fingerprint for every allowed signing certificate (debug only for
   local testing; Play App Signing for production).
3. Put the key outside the repository in the user Gradle properties file:
   `%USERPROFILE%\.gradle\gradle.properties` on Windows or
   `~/.gradle/gradle.properties` on macOS/Linux:

   ```properties
   MAPS_API_KEY=replace_with_the_local_value
   ```

   Alternatively pass `-PMAPS_API_KEY=...` from a protected CI secret.
4. Confirm that the merged release manifest contains a non-empty
   `com.google.android.geo.API_KEY` value and that the key works in a signed build.

## 3. Firebase Cloud Messaging

1. Register an Android app with the final package name in the production Firebase
   project.
2. Download its `google-services.json` and place it at
   `app/google-services.json`. Do not commit the file.
3. Add the debug and production signing SHA-1/SHA-256 fingerprints in Firebase where
   required, then rebuild. The Google Services Gradle plugin is enabled automatically
   only when this file exists.
4. Configure the backend with the server-side Firebase Admin credentials through the
   host's secret manager. Never put a service-account JSON file in this app.
5. Test token registration, token rotation, foreground delivery, background delivery,
   notification permission denial, and tapping a notification on Android 13+.

## 4. Release signing

1. Create the upload keystore outside this repository and make encrypted backups.
2. Prefer **Play App Signing**: retain the upload key locally and let Google protect the
   app-signing key.
3. Configure signing in Android Studio's **Generate Signed Bundle / APK** workflow, or
   add a local/CI signing configuration whose values come only from ignored
   `local.properties` or protected environment variables. Never place passwords or an
   absolute personal keystore path in `build.gradle.kts`.
4. Record the upload and Play App Signing SHA-1/SHA-256 fingerprints, then apply the
   production fingerprint restrictions to Maps and Firebase.
5. Produce a signed Android App Bundle (`.aab`) and verify its certificate with
   `apksigner verify --print-certs` before upload.

## 5. Security and release verification

- Keep the release backend URL HTTPS-only and confirm the merged release manifest has
  `android:usesCleartextTraffic="false"` and `android:allowBackup="false"`.
- Replace the custom-scheme password-reset callback with an HTTPS Android App Link when
  a production domain is available. Publish `/.well-known/assetlinks.json`, add an
  `autoVerify` intent filter, and allow only that callback URL in Supabase. Until then,
  treat `zholdas://reset-password` as interceptable by another installed application.
- Verify Supabase Row Level Security for every table exposed by the public anon key.
  The anon key identifies the project; it must not grant privileged access.
- Run unit tests, lint, release assembly/bundle, R8 checks, and a secret scan. Inspect the
  merged release manifest and confirm no debug cleartext rule or empty Maps key remains.
- Test location only while the app is in use. If background location is introduced,
  redesign the user disclosure and Play permission declaration before adding the
  permission.

## 6. Play Console and policy

- Publish a public privacy policy describing account/profile data, precise and
  approximate location, event content and images, contacts/friend relationships,
  messages, notification tokens, moderation reports, retention, and deletion.
- Complete **Data safety** from actual production behavior and third-party SDK behavior.
  Declare encryption in transit, collection/sharing purposes, optional versus required
  data, retention, and deletion accurately.
- Complete the location permission declaration and explain the user-visible event/map,
  arrival, and live-location features. The current manifest does not request background
  location.
- Provide an in-app and web-accessible account-deletion path if users can create
  accounts, and enter its URL in Play Console.
- Complete content rating, ads declaration, target audience, app access instructions for
  reviewers, countries, support contact, store listing, screenshots, icon, and feature
  graphic.
- Upload first to **Internal testing**. Test install/update through Google Play on real
  devices, then promote only after crash, ANR, backend, Maps, push, deep-link, offline,
  theme, language, accessibility, and account-deletion checks pass.
