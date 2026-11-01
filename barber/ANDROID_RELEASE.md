# Android release 1.4.6 (14)

Package ID remains `fr.barberclubgrenoble.app`. Version name and code come from `pubspec.yaml`; do not maintain a second version in Gradle. The latest source release on `origin/main` was `1.4.5+13`, so this release uses `1.4.6+14`.

## Current verified bundle — 1 November 2026

`build/releases/BarberClub-1.4.6-14.aab` is the signed Play upload artifact (75,673,297 bytes), SHA-256 `d2bb1d219ce930f1a04edf29e09a990f604047ca1bb2e3ce359f41be4dcf8d81`.

- Source fixes are pushed to `main` in `742dbc5` and `05d498a`; Railway reports successful deployments and its final health check returned HTTP 200/status `ok`.
- 73 Flutter tests and 21 database-free backend unit tests passed. The backend TypeScript build passed. Focused Dart analysis is clean; full-project analysis has no errors and retains older lint/warning findings.
- 24 live content checks, 16 primary image URL checks and 15 post-deployment API/login checks passed. No live appointment was created, cancelled or rescheduled for testing.
- Bundletool, release signature, package/version/SDK, expected ABIs and static 16 KB ZIP/ELF alignment checks passed. Physical 16 KB-device testing remains unperformed.
- The Pixel 8 emulator runs the same release code, generated from this AAB and signed with the existing Android debug key to preserve its installed app data. This emulator APK is not the Play upload artifact.
- Play Console upload/review status for version 14 is being checked in the authenticated release session; do not infer publication from a successful local build.

## Historical upload-key recovery — 19 October 2026

The user confirmed the original upload key was lost and authorized generating a replacement. The signed bundle is now `build/releases/BarberClub-1.4.3-11-PENDING-KEY-RESET.aab` (75,632,755 bytes), SHA-256 `793dea06e76aa638d3ea1aedef32af2e675425bcff6bd2b1c2ca1a648579e9ac`.

The bundle's signature is valid and its signer matches the new public PEM. Registration was pending when this artifact was created. In the later Play Console session, Play accepted version 11 signed by this replacement key, confirming that the upload-key reset was active. See `UPLOAD_KEY_RESET.md` for fingerprints and private backup locations. Never upload the private keystore or recovery configuration.

## Earlier unsigned handoff — retained for reference

`build/releases/BarberClub-1.4.3-11-UNSIGNED.aab` — 75,581,179 bytes (72.1 MiB). **Not upload-ready: this older handoff remains unsigned. Use the signed replacement bundle after the reset, not this file.**

SHA-256: `1ecfd3086a4a23d50f8101d328726bf1742f9435b926741d87c51bbafd26d868`.

Verified from the actual bundle with official bundletool 1.18.3 (download SHA-256 verified against Google's GitHub release metadata):

- Valid AAB structure, package `fr.barberclubgrenoble.app`, version `1.4.3` / code `11`.
- Target SDK 36; release manifest is not debuggable.
- ARM32 (`armeabi-v7a`), ARM64 (`arm64-v8a`) and x86-64 are present; 15 native libraries total.
- Bundle requests `PAGE_ALIGNMENT_16K`; all 64-bit ELF LOAD alignments are at least 16 KB. This is a packaging/static check, not a physical 16 KB-device runtime test.
- Signature absent, as intended. The default artifact verifier rejects this unsigned file unless explicitly given `-AllowUnsigned`.
- 44 Flutter tests passed after the splash dependency correction. Android debug-signing validation passed; normal release validation correctly rejects the configured debug key.

The standard build output `build/app/outputs/bundle/release/app-release.aab` now contains signed version 1.4.6 (14), not either historical version 11 handoff.

## Signing status

The original key was not found locally. The local `android/key.properties` now points to the newly generated, user-authorized replacement upload key in `C:/Users/GeorgioHayek/.android/barberclub-upload-2026-10-19/`. It is ignored by Git and its file access is restricted. The previous debug configuration is backed up in that private folder.

**An unsigned bundle is not ready for Play upload.** A normal release build now rejects missing/debug signing credentials instead of producing a misleading debug-signed release. Debug/emulator builds still work without release credentials.

Signing is complete locally and Play previously accepted this replacement upload key. Match the replacement certificate fingerprint in `UPLOAD_KEY_RESET.md` against Play's Upload key certificate when investigating signing problems. Build guards cannot verify Play's current certificate registration. Keep all passwords local and do not place them in chat or tracked files.

The original lost key was replaced through the upload-key reset workflow. A public certificate downloadable from Play is not the private key and cannot sign a bundle. Do not rerun key generation for routine releases.

## Build

From `barber/`, with the accepted replacement upload credentials already configured locally:

```powershell
flutter pub get
flutter test --no-pub
flutter build appbundle --release --no-pub
```

Normal output: `build/app/outputs/bundle/release/app-release.aab`.

To prepare an explicitly **unsigned** release while recovering the key:

```powershell
$env:BARBERCLUB_UNSIGNED_RELEASE = 'true'
try {
    flutter build appbundle --release --no-pub
} finally {
    Remove-Item Env:BARBERCLUB_UNSIGNED_RELEASE -ErrorAction SilentlyContinue
}
```

Do not upload that unsigned file. Rebuild normally with the registered upload key when it is available. No store upload, key reset, account change or production data change is performed by these commands.

The explicit environment flag is uppercase so it survives Flutter/Dart's Windows environment handling. Direct Gradle invocations can also use `-PunsignedRelease=true`.

## Verify an artifact

Use the official Google `bundletool-all` JAR and the installed JDK. The verifier compares the bundle with the current source version, checks the package/target/debuggable flag, checks all expected ABIs, checks bundle ZIP alignment and every 64-bit native library's ELF LOAD alignment, and rejects unsigned or debug-signed bundles by default.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./tool/verify_android_bundle.ps1 `
    -BundlePath ./build/app/outputs/bundle/release/app-release.aab `
    -BundletoolPath ./build/verification/bundletool-all-1.18.3.jar `
    -JavaPath 'C:/Users/GeorgioHayek/Development/jdk-17.0.20.1+1/bin/java.exe'
```

For a knowingly unsigned handoff only, add `-AllowUnsigned`. Signature presence/cryptographic validity does not prove that Play has registered that upload certificate; compare its fingerprint in Play Console as well.

The `-ExecutionPolicy Bypass` above applies only to this verification subprocess on Windows machines that disable local script execution; it does not change machine/user execution policy. The verifier is repository-authored, read-only, and does not contact production APIs.

## Release scope and checks

- Updated website-backed salons/teams/photos, Voiron booking selection and landing copy, compact-screen scrolling and per-booking cancellation credentials.
- Package ID, app label, production endpoints and Firebase project are preserved.
- `flutter_native_splash` remains at the existing locked version, but is a runtime dependency so the generated Android plugin registrant can compile in release builds. Generated registration code was not edited manually.
- Installed Flutter toolchain targets API 36, with AGP 8.11.1 and NDK 28.2. No unrelated major toolchain/dependency upgrades are required merely to resolve “support will soon be dropped” warnings.
- Verify the generated bundle's package, version, target SDK, signing status, all expected ABIs and native 16 KB alignment before upload.
- “Mes RDV” barber avatars still have the previously reported booking-photo resolution gap; this release preparation does not claim it was fixed. No live appointment mutation tests were authorized or performed.
- Before production rollout, complete internal testing and verify Play Console's Data safety/privacy policy/app access declarations. Release preparation does not certify Play approval or change those declarations.

## Suggested French release notes

Ajout du salon de Voiron et mise à jour des équipes et contenus des salons. Amélioration du défilement lors du choix du barber et correction de la gestion des codes d'annulation des rendez-vous.

## Official references

- [Flutter Android release guide](https://docs.flutter.dev/deployment/android)
- [Android app/upload signing and lost upload-key reset](https://developer.android.com/studio/publish/app-signing)
- [Google Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [Native 16 KB compatibility checks](https://developer.android.com/guide/practices/page-sizes)
