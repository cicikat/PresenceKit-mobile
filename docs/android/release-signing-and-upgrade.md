# Android release signing and upgrade authority

## Required identity

Every public release must use one fixed, non-debug release keystore. The keystore, passwords, `android/key.properties`, and CI secret values stay outside version control. A release build must fail before packaging if any of the four signing fields or the referenced keystore is absent. Never replace a historical public APK with a rebuild from the same source signed by a newly generated key.

Before publishing, record the APK filename, SHA-256, version name/code, certificate SHA-256, certificate subject, and `apksigner verify --print-certs` result. Keep the record free of private key material and passwords.

## Formal release entry point

`AA1` creates the verified formal release artifact only. `AA3` uses the same release build, signing, metadata, and signer validation, then installs the verified APK with `adb install -r` on exactly one authorized Android device. It never installs before validation completes.

Run `AA1打包发行包.bat` and provide both values when prompted:

- `versionName` is the version shown to users, such as `1.0.0` or `1.0.0-rc.1`.
- `versionCode` is Android's upgrade-comparison value. It must be a positive integer and must increase for every later Android release.
- A release such as `1.0.0 / build 2` can upgrade `0.2.2 / build 1` when the package name and signing identity are compatible.

The script confirms the requested version, current Git commit, and `prod release` build type before starting. It runs `flutter pub get` and then `flutter build apk --release --flavor prod --build-name <versionName> --build-number <versionCode>`; it does not modify `pubspec.yaml`. It also refuses missing/incomplete signing configuration, debug-signing fallback, reused artifact names, mismatched APK metadata, and a certificate other than the permanent historical PresenceKit-mobile identity:

`18:69:B3:48:D9:E2:6F:13:D8:21:3F:F6:09:33:BC:F9:33:FE:6E:87:79:D1:31:98:F6:55:A4:D7:C0:79:1F:AE`

The final APK, `.apk.sha256`, and `.build-info.txt` are written under `dist/release`. The keystore is only read for signing and is never copied there. GitHub publication remains a subsequent manual step; the script does not stage, commit, tag, or publish anything.

## Upgrade gate

The real public APK must be installed first on a test device. Only when its signer certificate digest equals the candidate digest may the candidate be tested with `adb install -r`. The upgrade leg must retain app data and verify backend URL, owner ID, ordinary settings, admin token, relay token, secure-storage migration, token replacement/deletion, two restarts, and a second same-signed overwrite. A clean install is a separate leg. Automated migration tests and simulated same-signature tests never substitute for this real published-APK test.

## 2026-07-29 audit outcome

The public v0.2.2 APK is verified and is signed by `C=US, O=Android, CN=Android Debug`, certificate SHA-256 `1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae`. The configured v1 release keystore and current `a351d08` formal candidate were unavailable, so no lineage-compatible upgrade claim can be made. No device upgrade test was run.

If the historical private key is recovered, option 1 is to use that identity permanently and repeat the complete real-device matrix. If it is not recovered, Android cannot perform an in-place upgrade from the historical APK to a package signed with a different identity. Option 2 is a transition release with an explicit reinstall path: export backend URL, owner ID, ordinary settings, and user-approved token re-entry/import; uninstall the old app only after confirming the export; install the new identity; restore settings and enter fresh tokens; then verify chat, relay, and token migration on the new installation. The project must choose between these options before announcing v1 readiness.
