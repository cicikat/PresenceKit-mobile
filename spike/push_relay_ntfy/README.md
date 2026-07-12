# Push-Relay Spike: ntfy

Validates whether a persistent SSE relay survives Doze / OEM kill better than
the current MobileNotificationService long-poll loop.

## Quick start

### 1. Run local ntfy server

```bash
cd spike/push_relay_ntfy/server
docker compose up -d
# verify:
curl http://localhost:8080/v1/health     # → {"healthy":true}
```

No Docker? Download the ntfy binary:
```bash
# Windows
winget install ntfy  # or download from https://github.com/binwiederhier/ntfy/releases
ntfy serve --config server/ntfy.yml
```

### 2. Verify publish + subscribe work

**Terminal A — subscribe (SSE):**
```bash
curl -N "http://localhost:8080/yexuan-spike/sse"
# Should print ": keepalive" every ~55 s when idle
```

**Terminal B — publish:**
```bash
cd server
./publish.sh              # bash
.\publish.ps1             # powershell
# Terminal A should immediately print: data: {"message":"ping …"}
```

**WebSocket alternative:**
```bash
curl --no-buffer -H "Upgrade: websocket" \
     -H "Connection: Upgrade" \
     -H "Sec-WebSocket-Version: 13" \
     -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
     http://localhost:8080/yexuan-spike/ws
```
*(ntfy supports both SSE and WS; the Android spike uses SSE for simplicity.)*

### 3. Expose server to device

If device and PC share WiFi:
```
http://192.168.1.X:8080
```
Use `ipconfig` (Windows) or `ip a` (Linux) to find your LAN IP.  
Set the same IP in NtfySpikeActivity when you start the relay.

### 4. Wire up Android spike

1. Copy `android/*.kt` into `android/app/src/main/kotlin/com/presencekit/mobile/spike/`
2. Apply the additions described in `android/manifest_additions.xml` to the real manifest.
3. Build & install: `flutter build apk --debug && adb install build/app/outputs/flutter-apk/app-debug.apk`
4. Launch spike activity:
   ```
   adb shell am start -n com.presencekit.mobile/.spike.NtfySpikeActivity
   ```
5. Enter host + topic, tap **Start Relay**, then **Request Battery Exemption**.
6. Start the loop publisher:
   ```bash
   cd server && ./loop_publish.sh 192.168.1.X:8080 yexuan-spike 300
   ```

### 5. Record observations

Fill in `android/test_log_template.md` with timestamps from loop_publish output vs.
notification arrival times. Run the same sequence against MobileNotificationService for comparison.

## File structure

```
spike/push_relay_ntfy/
├── README.md                         ← this file
├── server/
│   ├── docker-compose.yml            ← ntfy server
│   ├── ntfy.yml                      ← server config
│   ├── publish.sh / publish.ps1      ← one-shot publish
│   └── loop_publish.sh               ← periodic publish for tests
└── android/
    ├── NtfyRelayService.kt           ← SSE subscriber foreground service
    ├── NtfyBootReceiver.kt           ← restart after reboot
    ├── NtfySpikeActivity.kt          ← minimal test harness UI
    ├── manifest_additions.xml        ← what to add to the real manifest
    └── test_log_template.md          ← observation recording template
```

## Key implementation notes

- **No new library dependency**: NtfyRelayService uses plain `java.net.HttpURLConnection`
  to read the SSE stream. The spike avoids pulling in OkHttp so it doesn't affect build size.
- **Dedup**: same `seenIds` pattern as `MobileNotificationService.seenMobileMessageIds`.
- **Reconnect**: exponential backoff 2 s → 64 s ceiling, same as existing poll loop.
- **Boot recovery**: NtfyBootReceiver mirrors the AlarmManager-based recovery in the existing service.
- **No lib/ changes**: all spike code is under `spike/` and `android/…/spike/`; the main app is untouched.

## Conclusion

See [docs/reference/push-relay-spike.md](../../docs/reference/push-relay-spike.md).
