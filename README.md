[English](README.md) | [简体中文](README.zh-CN.md)

# PresenceKit-mobile

A Flutter mobile client for [PresenceKit](https://github.com/cicikat/PresenceKit) — a companion AI with long-term memory and emotional state. This is a thin client: chat, profile, diary, garden, capability checks, and a mobile-channel poller for proactive messages. All persona, memory, and scheduling logic lives in the backend.

**Requires a running PresenceKit backend** — see the [backend Quickstart](https://github.com/cicikat/PresenceKit#quickstart).

---

## Connecting to a backend

**During development**, with a phone plugged into the same machine as the backend:

```powershell
adb reverse tcp:8080 tcp:8080
```

This forwards the phone's `http://127.0.0.1:8080` to the backend running on your dev machine. `mobile_dev_control.bat` wraps this (and the reverse teardown) in a small menu — edit the `ADB` path at the top of the script for your machine first.

**Off the cable**, set the "backend node" in the app's settings to your computer's LAN IP, e.g. `http://192.168.1.100:8080`. Requirements:

- Phone and computer on the same LAN, or bridged via Tailscale / VPN / a reverse tunnel.
- The backend's admin service listens on `0.0.0.0:8080` (or the relevant LAN address).
- Your firewall allows the phone to reach port 8080.
- Public-network nodes must use HTTPS; plaintext HTTP is only allowed for loopback, Tailscale, or a user-confirmed exact RFC1918 private IPv4 origin.

You can also bake a default backend address into the production build: `flutter build apk --release --flavor prod --dart-define=BACKEND_BASE_URL=http://192.168.1.100:8080`.

---

## Building / installing

- **`AA1打包安装到手机.bat`** — dev loop: builds a debug (or `debug`/`release`) APK and installs it to a connected device over adb. It hardcodes local `flutter`/`adb` paths at the top — edit those for your machine before running.
- **`AA2打包发行包.bat`** — release packaging: builds a release APK and drops `dist/PresenceKit-mobile-vX.Y.Z.apk` (+ `.sha256`) for uploading to a GitHub Release. No device needed.

Debug/dev builds use the Android debug key. A formal release build (`flutter build apk --release --flavor prod` or `AA2打包发行包.bat`) requires a fixed release keystore and fails before packaging if `android/key.properties`, its four fields, or its `storeFile` is absent; it never falls back to a debug-signed release APK.

For a local release, create the keystore outside the repository, copy `android/key.properties.example` to the gitignored `android/key.properties`, and set its file path, passwords, and alias. Do not commit the keystore, passwords, alias, or `key.properties`. For GitHub tag releases, configure the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`; the workflow materializes them only in its ephemeral runner.

Android access and relay tokens are stored as Keystore-encrypted values in private app storage. The legacy `SharedPreferences("yexuan_memery")` name remains unchanged for non-sensitive settings and one-time upgrade compatibility; a legacy token is copied securely and its plaintext key is removed only after that write succeeds.

Download prebuilt APKs from this repo's [GitHub Releases](https://github.com/cicikat/PresenceKit-mobile/releases). Requires a running [PresenceKit backend](https://github.com/cicikat/PresenceKit/releases) — check the release notes for the compatible backend version.

---

## More docs

- [docs/mobile/background-notification-design.md](docs/mobile/background-notification-design.md) — background polling, notification gating, and behavior-metadata handling (implemented, not a proposal).
- [docs/roadmap-notes.md](docs/roadmap-notes.md) — open design questions not yet settled into a stable plan.
- [docs/protocols/sensor-event-protocol.md](docs/protocols/sensor-event-protocol.md) — draft protocol for multi-device/hardware sensor events.

---

## Running tests

If your machine routes local traffic through an HTTP proxy, Dart's HTTP client will also route `127.0.0.1` through it, breaking the in-process test harness (`HttpException: Connection closed before full header was received`). Set `NO_PROXY` before running tests:

```powershell
$env:NO_PROXY = "localhost,127.0.0.1,::1"; flutter test
```

See [CLAUDE.md](CLAUDE.md) for details. In CI or a proxy-free environment, `flutter test` needs no extra setup.

---

## License

This project is licensed under the PolyForm Noncommercial License 1.0.0.

Noncommercial use is permitted. Commercial use is not permitted without separate permission from the author.
