# Remind Me Again

A Flutter app for Android and iOS.

## Requirements

- Flutter 3.24.4 (stable) — the version CI pins in `.github/workflows/ci.yml`
- Android: JDK 17 to 21 and the Android SDK. Flutter defaults to the JDK bundled
  with Android Studio; if that is JDK 24 or newer, Gradle prints
  `WARNING: A restricted method in java.lang.System has been called` on every
  build. Point Flutter at a supported JDK instead:

  ```bash
  flutter config --jdk-dir=/path/to/jdk-21
  ```
- iOS: Xcode (deployment target iOS 15.0) and CocoaPods once plugins are added

## Getting started

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

`env.json` holds the public, non-secret configuration (Google OAuth client IDs)
and is passed to every build with `--dart-define-from-file=env.json`. See
[Google Tasks Off-Device Database Setup](#google-tasks-off-device-database-setup).

Before pushing, run the same checks as CI:

```bash
dart format lib test
flutter analyze --fatal-infos
flutter test
```

## Google Tasks Off-Device Database Setup

Remind Me Again stores tasks off-device in the signed-in user's default Google Tasks list (`@default`) using `google_sign_in` and `googleapis`.

1. **Enable the Google Tasks API** in your Google Cloud project (`https://console.cloud.google.com/apis/library/tasks.googleapis.com`).
2. **Configure the OAuth Consent Screen** and add the `https://www.googleapis.com/auth/tasks` scope.
3. **Create OAuth 2.0 Client IDs**:
   - **Android**: Register package name `io.github.davidtanner.remind_me_again` with your signing certificate SHA-1 fingerprint (one entry per keystore you build with: debug and upload). The Android client ID is matched by package name and SHA-1 and is never passed into the app.
   - **Web**: Create a *Web application* client. `google_sign_in` on Android requires its ID as the `serverClientId`; sign-in fails with `serverClientId must be provided on Android` without it.
   - **iOS**: Register bundle ID `io.github.davidtanner.remind_me_again`.
4. **Fill in `env.json`** at the repo root. OAuth client IDs are public identifiers, not secrets, so the file is committed and used by every build (`flutter run`, `flutter build`, and CI) via `--dart-define-from-file=env.json`.

   | Key | Used by | Value |
   | --- | --- | --- |
   | `GOOGLE_IOS_CLIENT_ID` | iOS | The iOS OAuth client ID. Passed to `GoogleSignIn.initialize(clientId:)` and written into `ios/Runner/Info.plist` (`GIDClientID` and the `CFBundleURLSchemes` reversed client ID) by the `Apply Google Sign-In Config` Xcode build phase (`ios/scripts/apply_google_signin_config.sh`). The reversed ID is derived automatically. |
   | `GOOGLE_SERVER_CLIENT_ID` | Android, iOS | The Web OAuth client ID. Required on Android; passed to `GoogleSignIn.initialize(serverClientId:)`. |
   | `GOOGLE_ANDROID_CLIENT_ID` | reference only | The Android OAuth client ID, kept here for documentation. |
   | `GOOGLE_PROJECT_ID` | reference only | The Google Cloud project ID. |

   A one-off `--dart-define=KEY=value` on the command line overrides the value from `env.json`.
   If `GOOGLE_IOS_CLIENT_ID` is empty, the iOS build phase leaves `Info.plist` alone and prints a
   warning; you can then still supply `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_IOS_REVERSED_CLIENT_ID` as
   Xcode build settings instead.

## Building releases

Release builds are obfuscated; keep the generated symbol files (not committed)
to symbolicate crash reports.

```bash
flutter build appbundle --release --dart-define-from-file=env.json --obfuscate --split-debug-info=build/symbols
flutter build ipa --release --dart-define-from-file=env.json --obfuscate --split-debug-info=build/symbols
```

### Android signing

Copy `android/key.properties.example` to `android/key.properties` and point it at
your upload keystore. Both files are gitignored. In CI, provide the
`ANDROID_KEYSTORE_*` / `ANDROID_KEY_*` environment variables from GitHub Actions
secrets instead. Without either, release builds fall back to debug signing.

### iOS signing

Set your team and signing in Xcode (`ios/Runner.xcworkspace`). Never commit
certificates (`.p12`), provisioning profiles, or App Store Connect API keys (`.p8`).

## Security

- Secrets and signing material are gitignored — see the bottom of `.gitignore`.
  Only public values (OAuth client IDs) belong in the committed `env.json`.
- CI runs with a read-only token, pins third-party actions to commit SHAs, and
  installs dependencies with `--enforce-lockfile`.
- Dependabot keeps pub, Gradle, and GitHub Actions dependencies current.
- Report vulnerabilities as described in [SECURITY.md](SECURITY.md).

## License

GPL-3.0 — see [LICENSE](LICENSE).
