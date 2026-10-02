# Remind Me Again

A Flutter app for Android and iOS.

## Requirements

- Flutter 3.24.4 (stable) — the version CI pins in `.github/workflows/ci.yml`
- Android: JDK 17+ and the Android SDK
- iOS: Xcode (deployment target iOS 15.0) and CocoaPods once plugins are added

## Getting started

```bash
flutter pub get
flutter run
```

Before pushing, run the same checks as CI:

```bash
dart format lib test
flutter analyze --fatal-infos
flutter test
```

## Building releases

Release builds are obfuscated; keep the generated symbol files (not committed)
to symbolicate crash reports.

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
flutter build ipa --release --obfuscate --split-debug-info=build/symbols
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
- CI runs with a read-only token, pins third-party actions to commit SHAs, and
  installs dependencies with `--enforce-lockfile`.
- Dependabot keeps pub, Gradle, and GitHub Actions dependencies current.
- Report vulnerabilities as described in [SECURITY.md](SECURITY.md).

## License

GPL-3.0 — see [LICENSE](LICENSE).
