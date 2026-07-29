# v1 Android release readiness

## Identity and credential-storage preflight

| Blocker | Status | Evidence |
| --- | --- | --- |
| Fixed release identity | Implemented; manual signing key provisioning remains | Release Gradle tasks and AA2 fail without a complete, existing keystore; tag workflow requires four signing secrets. |
| Keystore-backed access/relay tokens | Implemented; device upgrade validation remains | `AndroidKeystoreCredentialStore` encrypts values with a non-exportable Android Keystore key and migrates legacy plaintext transactionally. |
| Lossless installed-app upgrade/recovery | Open until device validation | Must be run using two APKs signed by the same release key. |

`SharedPreferences("yexuan_memery")` is an immutable compatibility name. It continues to hold ordinary settings such as backend URL and owner ID. Sensitive `adminToken` and `relayToken` are read from secure storage first. On first secure read, a legacy value is written securely, then—and only then—removed from the legacy preferences. A failed secure write leaves the legacy value untouched.

## Required device acceptance

1. Install an old signed APK, set backend URL, owner ID, access token, and (if used) relay token.
2. Install the v1 signed APK over it with the same signing identity and without clearing app data.
3. Relaunch twice: connection and background notification behaviour must work without re-entering tokens; verify the legacy token keys are absent with an authorized local inspection.
4. Replace each token, relaunch, then delete/logout and relaunch; no credential may remain usable.
5. Repeat a clean install with no token and then with a manually entered token.

Do not use `adb uninstall`, app-data clear, a debug-signed APK, or a different signing key during the upgrade leg: each invalidates the acceptance condition.
