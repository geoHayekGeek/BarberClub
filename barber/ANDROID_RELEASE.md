# Android release 1.4.3 (11)

Package ID remains `fr.barberclubgrenoble.app`. The user confirmed version code 11 is the next unused Play upload code. Version name and code come from `pubspec.yaml`; do not maintain a second version in Gradle.

## Prepared artifact — 19 October 2026

`build/releases/BarberClub-1.4.3-11-UNSIGNED.aab` — 75,581,179 bytes (72.1 MiB). **Not upload-ready: the existing Play upload private key is missing.**

SHA-256: `1ecfd3086a4a23d50f8101d328726bf1742f9435b926741d87c51bbafd26d868`.

Verified from the actual bundle with official bundletool 1.18.3 (download SHA-256 verified against Google's GitHub release metadata):

- Valid AAB structure, package `fr.barberclubgrenoble.app`, version `1.4.3` / code `11`.
- Target SDK 36; release manifest is not debuggable.
- ARM32 (`armeabi-v7a`), ARM64 (`arm64-v8a`) and x86-64 are present; 15 native libraries total.
- Bundle requests `PAGE_ALIGNMENT_16K`; all 64-bit ELF LOAD alignments are at least 16 KB. This is a packaging/static check, not a physical 16 KB-device runtime test.
- Signature absent, as intended. The default artifact verifier rejects this unsigned file unless explicitly given `-AllowUnsigned`.
- 44 Flutter tests passed after the splash dependency correction. Android debug-signing validation passed; normal release validation correctly rejects the configured debug key.

The standard build output `build/app/outputs/bundle/release/app-release.aab` contains the same unsigned bundle. Do not upload either file until it has been signed with the upload key registered in Play Console. No new signing key was generated and nothing was uploaded.

## Signing status

The local `android/key.properties` currently points to Android's debug key. No BarberClub upload keystore was found in the accessible user profile or Git signing-file history. Unrelated OneDrive/internal tool keystores are not app upload keys and were not opened.

**An unsigned bundle is not ready for Play upload.** A normal release build now rejects missing/debug signing credentials instead of producing a misleading debug-signed release. Debug/emulator builds still work without release credentials.

To complete signing, put the existing Play upload keystore on this machine and configure its path, alias and passwords in the ignored `android/key.properties` file. Use `android/key.properties.example` as a template; enter passwords locally, not in chat or tracked files. Match the keystore certificate fingerprint against the Upload key certificate in Play Console's App integrity/App signing page. Build guards cannot verify that Play has registered a particular non-debug key.

If the existing upload key is lost and the app uses Play App Signing, the account owner can request an upload-key reset in Play Console. Do not generate or register a replacement without the owner's direction. The public certificate downloadable from Play is not the private key and cannot sign a bundle.

## Build

From `barber/`, with the correct existing upload credentials configured:

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
