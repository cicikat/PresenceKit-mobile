# Android release signing and upgrade authority

## Required identity

Every public release must use one fixed, non-debug release keystore. The keystore, passwords, `android/key.properties`, and CI secret values stay outside version control. A release build must fail before packaging if any of the four signing fields or the referenced keystore is absent. Never replace a historical public APK with a rebuild from the same source signed by a newly generated key.

Before publishing, record the APK filename, SHA-256, version name/code, certificate SHA-256, certificate subject, and `apksigner verify --print-certs` result. Keep the record free of private key material and passwords.

## Upgrade gate

The real public APK must be installed first on a test device. Only when its signer certificate digest equals the candidate digest may the candidate be tested with `adb install -r`. The upgrade leg must retain app data and verify backend URL, owner ID, ordinary settings, admin token, relay token, secure-storage migration, token replacement/deletion, two restarts, and a second same-signed overwrite. A clean install is a separate leg. Automated migration tests and simulated same-signature tests never substitute for this real published-APK test.

## 2026-07-29 audit outcome

The public v0.2.2 APK is verified and is signed by `C=US, O=Android, CN=Android Debug`, certificate SHA-256 `1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae`. The configured v1 release keystore and current `a351d08` formal candidate were unavailable, so no lineage-compatible upgrade claim can be made. No device upgrade test was run.

If the historical private key is recovered, option 1 is to use that identity permanently and repeat the complete real-device matrix. If it is not recovered, Android cannot perform an in-place upgrade from the historical APK to a package signed with a different identity. Option 2 is a transition release with an explicit reinstall path: export backend URL, owner ID, ordinary settings, and user-approved token re-entry/import; uninstall the old app only after confirming the export; install the new identity; restore settings and enter fresh tokens; then verify chat, relay, and token migration on the new installation. The project must choose between these options before announcing v1 readiness.
