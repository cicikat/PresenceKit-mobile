# Android instrumented testing

`android/app/src/androidTest/` covers framework-level contracts for
notification channels, the declared accessibility service, permission intent
construction, Keystore ciphertext round trips, corrupt ciphertext failure,
and fail-closed capability calls when no user authorization is present.

The `android-instrumented` workflow runs the `dev` variant on a disposable
hardware-accelerated API 35 emulator. On failure it uploads the Android test
reports together with device logcat and activity process state. This is
`instrumented` evidence only: it does not prove OEM
background restrictions, vendor permission screens, durable Doze recovery, a
physical reboot, relay recovery, or real notification delivery. Those remain
`real-device` cases in the lifecycle matrix and are `not-run` until evidence
is recorded.

The tests use synthetic keys and values only. They do not read production
credentials or attempt to grant accessibility/overlay permission through
system APIs.
