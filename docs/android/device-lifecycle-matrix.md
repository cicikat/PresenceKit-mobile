# Real-device lifecycle acceptance matrix

This is the v1 evidence record for Android device acceptance. It is separate from
the emulator-based instrumented tests in `instrumented-testing.md`.

The checked-in baseline is intentionally `not-run`: no device identity,
backend identity, relay identity, or execution timestamp is evidence. A real
execution may update the JSON only after recording the exact environment and a
reproducible evidence link or attached artifact for every `passed`/`failed`
case.

Required execution order:

1. Record the prod artifact version, device model/API, backend SHA, relay
   identity, and UTC execution time in the JSON environment block.
2. Run the cases in the JSON in order. Keep backend, relay, and permission
   changes controlled and note them in the evidence artifact.
3. For each case, use `passed`, `failed`, or `blocked`; never use `passed` for
   a simulated or emulator-only observation.
4. Attach logs/screenshots/video or a test-run URL to the case evidence. Do not
   put tokens, user data, phone numbers, or machine-local absolute paths in the
   repository.
5. Leave the overall summary `not-run` or `partial` when any required case has
   not been executed on a real target.

The instrumented workflow proves native capability contracts on an emulator;
it does not prove Doze, process-kill, reboot, OEM background policy, relay
recovery, or release-artifact acceptance.
