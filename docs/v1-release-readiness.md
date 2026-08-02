# v1 Android release readiness

> **2026-08-02 后续验收更新**：下方 2026-07-29 快照只描述当时可见的 checkout。维护者随后确认 debug 与正式包已分离，正式包已满足版本号限制及同签名覆盖安装验收；因此其中“signing identity not provisioned / upgrade not verified”的阻塞结论已关闭。保留旧快照仅供追溯，不能再作为当前发布阻塞依据。

## Signing-lineage audit (2026-07-29)

This audit used the APK attached to the public [v0.2.2 GitHub Release](https://github.com/cicikat/PresenceKit-mobile/releases/tag/v0.2.2), not a rebuild from the v0.2.2 source tag. The downloaded asset was `app-release.apk`; GitHub asset SHA-256 and the downloaded file SHA-256 were both `60fc680ee19ae336b2760aec9027dbbf57142395a53433774f937b85b5f37b87`.

| Sample | SHA-256 | versionName / versionCode | signer certificate SHA-256 | subject | `apksigner verify` |
| --- | --- | --- | --- | --- | --- |
| Published GitHub v0.2.2 `app-release.apk` | `60fc680ee19ae336b2760aec9027dbbf57142395a53433774f937b85b5f37b87` | `0.2.2 / 1` | `1869b348d9e26f13d8213ff60933bcf933fe6e8779d13198f655a4d7c0791fae` | `C=US, O=Android, CN=Android Debug` | passed (v1/v2) |
| Existing `dist/PresenceKit-mobile-v0.2.2.apk` | identical to published asset | `0.2.2 / 1` | identical to published asset | identical to published asset | passed (v1/v2); historical copy, not a current candidate |
| Current commit `a351d08` formal release candidate | not produced | n/a | n/a | n/a | not run |
| Configured release keystore | unavailable in this checkout/environment | n/a | n/a | n/a | n/a |

The existing local v0.2.2 APK is byte-for-byte identical to the public asset and predates commit `a351d08`; it is deliberately not called the current candidate. No keystore, `android/key.properties`, or historical private signing key was found in the permitted local search. The historical certificate is recoverable from the APK, but its private key is not.

`apksigner` therefore establishes that the real public v0.2.2 APK is debug-signed. It does not establish a fixed release identity for v1, and no current a351d08 formally signed candidate exists to compare against it. The release build remains fail-loud when the required keystore is absent; the attempted local Gradle build was additionally blocked before project configuration because the Gradle distribution was not cached and network access was denied.

### Verdict and upgrade gate

Signing-lineage compatibility is **not established**. The real published APK is not a valid baseline for the requested fixed-release-key upgrade gate, and the real-device matrix was **not executed**. In particular, there is no evidence for `adb install -r` over the public APK, token retention, relay continuity, or post-upgrade restart behavior.

This is not an Android “different key” verdict between two valid release identities: the v1 candidate and configured release certificate are unavailable. Treat v1 signing/token readiness as **blocked: signing identity not provisioned and real upgrade not verified**. Do not substitute an APK rebuilt from old source or a debug-signed package for the public Release APK.

The release-signing and transition choices are recorded in [release-signing-and-upgrade.md](android/release-signing-and-upgrade.md). A maintainer must choose either to recover and permanently reuse the historical signing identity, or to declare a transition release and require reinstall plus settings export/import. No choice is made automatically here.

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
