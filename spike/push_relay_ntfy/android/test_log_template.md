# ntfy Relay Spike — Test Log

Fill in one row per observed publish → receive event.  
`latency_s` = time between publish timestamp in loop_publish.sh output and notification appearing on device.

## Device

| Field | Value |
|-------|-------|
| Model | |
| Android version | |
| ROM / OEM skin | |
| Battery mode | (default / unrestricted / restricted) |
| test run date | |

## Baseline: MobileNotificationService long-poll

| # | publish_ts | receive_ts | latency_s | device state at publish | notes |
|---|-----------|------------|-----------|------------------------|-------|
| 1 | | | | screen-on | |
| 2 | | | | screen-off 5 min | |
| 3 | | | | screen-off 30 min | |
| 4 | | | | screen-off 60 min | |
| 5 | | | | swiped from recents | |
| 6 | | | | after reboot | |

## Spike: NtfyRelayService SSE

| # | publish_ts | receive_ts | latency_s | device state at publish | notes |
|---|-----------|------------|-----------|------------------------|-------|
| 1 | | | | screen-on | |
| 2 | | | | screen-off 5 min | |
| 3 | | | | screen-off 30 min | |
| 4 | | | | screen-off 60 min | |
| 5 | | | | swiped from recents | |
| 6 | | | | after reboot | |

## Observations

- Did the SSE socket survive 30 min Doze without reconnect? Y / N
- Did the SSE socket survive 60 min Doze without reconnect? Y / N
- Did OEM kill the foreground service? (check `adb logcat | grep NtfyRelaySpike`) Y / N
- How many reconnects in 1 h? (count "SSE connecting" lines in logcat)
- Was battery optimization exemption required to survive? Y / N / not tested

## logcat capture commands

```bash
# Connect device, run during test:
adb logcat -v time NtfyRelaySpike:V *:S 2>&1 | tee ntfy_spike_logcat.txt

# Separate terminal — long-poll baseline:
adb logcat -v time mobile-poll:V *:S 2>&1 | tee longpoll_logcat.txt
```
