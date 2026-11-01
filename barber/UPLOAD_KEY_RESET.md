# Replacement Play upload key — 19 October 2026

The user authorized generating a replacement because the original upload key was lost. The replacement signed release `1.4.3+11`, which Play accepted in the later Console session, confirming the reset was active. The current release `1.4.6+14` uses this same key. This document retains the recovery procedure; no further reset or new key generation is needed for routine uploads.

## Files

- Public PEM for the reset request: `build/releases/BarberClub-upload-certificate-2026-10-19.pem`.
- Signed AAB, usable only after Play accepts the new upload certificate: `build/releases/BarberClub-1.4.3-11-PENDING-KEY-RESET.aab`.
- Private signing/recovery folder, outside Git: `C:/Users/GeorgioHayek/.android/barberclub-upload-2026-10-19/`.
- Private keystore in that folder: `barberclub-upload.jks`.
- Private recovery configuration in that folder: `recovery-key.properties`. It contains the generated password and alias; do not share or upload it.
- The ignored `android/key.properties` is configured for this key. Its former debug configuration is preserved in the private folder as `previous-debug-key.properties`.

The private folder and the local Gradle credential file allow access only to the current Windows user and SYSTEM. The keystore is encrypted with a cryptographically random 256-bit password. The recovery/Gradle configuration files necessarily contain that password in plaintext and rely on those file permissions. Passwords were not printed or embedded in scripts/commands.

**Make an encrypted backup of the entire private signing folder in a second secure location.** Back up both the keystore and recovery configuration, not just the public PEM. No off-machine backup was made automatically.

## Public key identity

- Alias: `barberclub-upload-2026-10-19`.
- Key: RSA 4096-bit; certificate signature: SHA256withRSA.
- Certificate subject: `CN=BarberClub Upload 2026-10-19, O=BarberClub`.
- Validity: 19 October 2026 through 6 March 2054.
- SHA-1: `4D:79:8A:5C:D6:89:49:83:9C:7E:4C:56:82:EC:AA:5C:3D:92:C5:CE`.
- SHA-256: `38:29:C1:EE:56:1A:FF:E8:A8:87:70:5D:1A:62:0C:79:D6:E1:BA:FB:7F:90:A0:09:CA:E1:09:F5:D9:8A:06:D5`.

These certificate fingerprints are public; they are not passwords. Do not confuse the certificate fingerprint with a file's SHA-256 checksum.

## Historical recovery procedure

For an app enrolled in Play App Signing:

1. Open BarberClub's app-signing page in Play Console. Google's current help lists **Protected with Play → Play Store protection → Manage Play app signing**.
2. In **Upload key certificate**, choose **Request upload key reset**. This is not an app-signing-key upgrade.
3. State that the previous upload key was lost, and attach only `BarberClub-upload-certificate-2026-10-19.pem`. Never upload the private `.jks` or either credential file.
4. Submit the request and wait for Google's confirmation and the effective activation date. Creating a local certificate alone does not register it.
5. Check that Play's accepted upload-certificate fingerprint matches the SHA-256 above before uploading a release. The reset was subsequently activated and Play accepted version 11. Use the current artifact/version from `ANDROID_RELEASE.md`; never reuse a consumed version code.

Suggested explanation: “The previous upload key was lost. Please register the attached replacement upload certificate for fr.barberclubgrenoble.app.”

An upload-key reset preserves Google's app-signing key, so it is different from rotating the key used to sign installed applications. If this app was never enrolled in Play App Signing and the lost key was its self-managed app-signing key, a new upload key cannot recover that old signing identity; confirm the app's signing setup with the account owner.

Official guidance: [Google Play upload-key reset](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en), [Android signing/key recovery](https://developer.android.com/studio/publish/app-signing#reset_upload_key).

## Verified signed artifact

- Package `fr.barberclubgrenoble.app`, version `1.4.3` / code `11`, target SDK 36, not debuggable.
- ARM32, ARM64 and x86-64; 15 native libraries; 16 KB bundle ZIP alignment and all 64-bit ELF LOAD alignment checks passed.
- JAR signature verification passed and the embedded signer matches the replacement PEM fingerprint above.
- Signed AAB size: 75,632,755 bytes.
- Signed AAB SHA-256: `793dea06e76aa638d3ea1aedef32af2e675425bcff6bd2b1c2ca1a648579e9ac`.
- Existing unsigned handoff is retained separately and must not be uploaded.

Run `flutter build appbundle --release --no-pub` to rebuild using the configured replacement key. The key-creation script refuses existing signing directories and non-debug signing configurations; it is not a build step and should not be rerun to make routine releases.
