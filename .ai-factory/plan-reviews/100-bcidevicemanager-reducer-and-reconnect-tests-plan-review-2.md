# Plan Review: BciDeviceManager reducer and reconnect tests

**Plan:** `.ai-factory/plans/100-bcidevicemanager-reducer-and-reconnect-tests.md`
**Risk Level:** 🟢 Low

## Scope

A pure test-coverage plan: add `test/Bci/bci_device_manager_test.dart` with fakes to directly
exercise `BciDeviceManager`'s reducer, calibration routing, and auto-reconnect paths. No
production code changes, no migrations, no proto changes. Review focuses on accuracy of the
plan's grounding (line refs, file paths, API usage), branch coverage, and the harness design.

## Verification performed

- **All line references are accurate.** Every `lib/Bci/BciDeviceManager.dart` line citation in the
  plan was checked against the current 315-line file and matches: `_setState` 130–140, `startScan`
  155–215, `connectDevice` 217–235, `startCalibration` 237–249, `startQuickCalibration` 251–263,
  calibration listener 76–103, connection listener 64–75, `_attemptReconnect` 274–313, `disconnect`
  265–272, `connectedSerial` getter 109.
- **External anchor refs verified:** `IBciDeviceProvider.dart:27` (`scan()`), `NfbCalibrationRepository.dart:55`
  (`record(...)` with `@visibleForTesting awaitApiSync` at 58), `NfbCalibrationData.dart:31`
  (11 required fields — confirmed: 11). All correct.
- **Models match the fakes' obligations:** `BciConnectionState` sealed hierarchy, `BciCalibrationEvent`
  (3 variants), `BciLinkStatus { down, up }`, `BluetoothPermissionDeniedException`, `BciDeviceInfo`
  — all align with the plan's harness description.
- **The grounding note exists** (`.ai-factory/notes/177-test-plan-bci-device-manager-reducer.md`) and
  contains complete, compiling fake reference implementations. The target test file does not yet
  exist, consistent with the plan.
- **Roadmap linkage:** behaviors under test were introduced in Phase 53 (ROADMAP lines 270–274,
  note 150) and Phase 51 (sealed state, note 103). The plan pins exactly those behaviors. Aligned.

## Context Gates

- **Architecture gate — PASS.** Test-only addition; no boundary or dependency changes.
- **Rules gate — PASS.** `.ai-factory/RULES.md` covers module-service statelessness and constructor
  DI. The plan correctly relies on `BciDeviceManager`'s fully constructor-injected dependencies and
  injects fakes the same way — no rule conflict.
- **Roadmap gate — PASS (WARN: none).** Clear linkage to Phase 53.

## Findings

### Issue 1 (Medium): Task 6 "connectedSerial is null" case as specified tests the wrong branch

> `should not attempt reconnect when connectedSerial is null` (line 71 serial guard; **down while scanning, never connected**)

The serial guard the case targets is on line 71: `if (!_suppressAutoReconnect && _connectedSerial != null)`.
But line 68 gates the *entire* listener body on `_state is BciActive`. `BciScanning` is **not** a
`BciActive` subtype, so emitting `down` while scanning never reaches line 71 — it is rejected at
line 68 and this case becomes an exact duplicate of the sibling case
`should ignore down when not in an active phase (line 68 guard; e.g. while scanning)`.

To genuinely cover the line-71 serial-null guard, the state must be `BciActive` **with**
`_connectedSerial == null`. The only reachable such state is **`BciConnecting` mid-flight**:
`connectDevice('A')` sets `BciConnecting('A')` at line 218 *before* `_connectedSerial = serial`
at line 221. So the correct setup is: start `connectDevice('A')` with a gated (un-completed)
`provider.connect`, emit `BciLinkStatus.down` while still `BciConnecting`, and assert no reconnect
scan fires. Recommend rewording the case setup accordingly, otherwise this branch is left uncovered
despite appearing covered.

### Issue 2 (Low): Harness needs a gating mechanism on `provider.connect`, not just `connectThrows`

Two cases depend on observing or controlling state *while `connect` is in flight*:
- Task 5: `should report state as BciConnecting between setState and provider.connect completing`
  ("gate the fake's connect to assert mid-flight").
- The corrected Issue-1 case above.

The plan's enumerated `FakeIBciDeviceProvider` API (controllers, emit helpers, call counters,
`connectThrows`/`startCalibrationThrows`/`startQuickCalibrationThrows`) and the note's reference fake
both implement `connect` as an immediately-returning `async` method — there is no `Completer` gate.
The implementer should add a `Completer`-based gate to `connect` (the existing
`GatedFakeDevicePort` in `neiry_bci_provider_locator_device_races_test.dart` is the in-repo pattern
to copy). Worth calling out so it isn't discovered mid-implementation.

### Issue 3 (Low): Fakes must override more than the counted methods

The plan lists only the methods it wants counters/throws on, but `implements` requires the full
implicit interface:
- `FakeIBciDeviceProvider implements IBciDeviceProvider` must also implement
  `importCalibration(NfbCalibrationData)` and `dispose()` (both present in the note's reference fake —
  good, just not mentioned in the plan body).
- `FakeNfbCalibrationRepository implements NfbCalibrationRepository` must also override `history(serial)`
  and `latestValid(serial)`, not just `record` / `refreshFromServer` (again present in the note).

No action needed beyond following the note's reference implementations; flagged only so the plan's
abbreviated fake descriptions aren't mistaken for the complete override set.

### Issue 4 (Nit): Multi-scan controller handle

Task 6/7 reconnect cases call `scan()` a second time inside `_attemptReconnect` (line 277). Since
`scan()` returns a fresh controller per call (interface contract, and the note's fake appends to a
`_scanControllers` list), the test must push reconnect discoveries to the **latest** controller, not
the first. The plan's harness bullet ("a scan() controller handle the test can push to") reads
singular; the note's list-based design is correct. Implementer should use the list, exposing
`_scanControllers.last` (or similar).

### Nit: "describe/group blocks"

Line 19 says "before the `describe`/`group` blocks." Dart's `flutter_test` has no `describe` — only
`group`/`test`. Harmless wording.

## Positive Notes

- Branch coverage is genuinely exhaustive — every reducer branch, both calibration outcomes, both
  scan error paths (permission vs generic), both reconnect terminations (onError/onDone), the dedup
  matrix (same-type/same-serial, same-type/diff-serial, diff-type/same-serial, post-dispose), and the
  error-swallow paths (`record`, `registerDevice`) each map to a named case with a line citation.
- The async-discipline note (lines 27) correctly anticipates the real hazard: `unawaited(...)`
  microtasks for reconnect and `record` require `pumpEventQueue()` before assertions, and
  `await manager.dispose()` in `tearDown` to avoid leaked controllers.
- Correctly identifies that "isConnecting" has no getter and must be asserted via `state is BciConnecting`.
- The plan correctly notes all dependencies are constructor-injected, so no test-infra refactor is
  needed — accurate and aligned with `.ai-factory/RULES.md`.

## Verdict

The plan is accurate, well-grounded, and ready to implement after correcting the Task 6
`connectedSerial`-null case setup (Issue 1) — as written it would silently leave the line-71 serial
guard uncovered. Issues 2–4 are harness clarifications the implementer can absorb from the reference
note. None are blocking beyond Issue 1, which is a one-line wording fix to the case setup.
