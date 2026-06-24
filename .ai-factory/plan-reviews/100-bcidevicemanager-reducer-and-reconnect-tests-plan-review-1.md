# Plan Review: BciDeviceManager reducer and reconnect tests

**Plan:** `100-bcidevicemanager-reducer-and-reconnect-tests.md`
**Risk Level:** 🟢 Low — the plan is accurate and well-grounded; findings are about completeness of the referenced fake harness, not architectural mistakes.

## Verification Summary

I cross-checked every line-number reference, file path, interface contract, and API
signature the plan relies on against the actual codebase.

**Confirmed correct:**
- Target source `lib/Bci/BciDeviceManager.dart` is 315 lines; every cited line range matches:
  `_setState` 130–140, `startScan` 155–215, `connectDevice` 217–235, `startCalibration`
  237–249, `startQuickCalibration` 251–263, calibration listener 76–103, connection
  listener 64–75, `_attemptReconnect` 274–313, `disconnect` 265–272, `connectedSerial`
  getter 109. All accurate.
- The constructor is fully constructor-injected (6 deps: provider, cardioSource,
  eegBandsSource, emotionsSource, repository, nfbCalibrationRepository). The plan's claim
  "no Test Infra refactor is required" holds — fakes replace the repositories entirely, so
  no `SharedPreferences.setMockInitialValues` / gRPC stubs are needed.
- `IBciDeviceProvider.scan()` at line 27 does contract a fresh stream per call — the fake's
  per-call controller design is correct.
- `NfbCalibrationData` has exactly 11 required fields (lines 31–43) — matches the builder note.
- `NfbCalibrationRepository.record` signature `(String, NfbCalibrationData, {@visibleForTesting bool awaitApiSync = false})`
  matches line 55–59. The manager calls it with 2 positional args (line 86) — fake override is compatible.
- `BluetoothPermissionDeniedException` is a const class — easy to throw in tests.
- `BciCalibrationEvent` sealed subtypes (`BciCalibrationStageFinished`, `BciCalibrationCompleted`,
  `BciCalibrationFailed`) and `BciConnectionState` hierarchy match the plan's transition assertions.
- Target spec file `test/Bci/bci_device_manager_test.dart` does not yet exist — no overwrite risk.
- Biometric source interfaces (`IHeartRateSource.cardioStream`, `IEegBandsSource.nfbStream`,
  `IEmotionsSource.emotionsStream`) match the inert-fake plan.

## Context Gates

- **Architecture:** `.ai-factory/ARCHITECTURE.md` — test-only change inside `lib/Bci/` domain;
  no boundary or dependency-direction impact. No issue.
- **Rules:** No `.ai-factory/RULES.md` and no `skill-context/aif-review/SKILL.md` present —
  no project-specific overrides to apply.
- **Roadmap:** The referenced note ties this to "Phase 53" coverage. This is `test`-type work
  (no production behavior change), so roadmap milestone linkage is optional. WARN: the plan
  does not name a ROADMAP milestone, but that is acceptable for a pure test-coverage task.

## Findings

### Should fix

1. **The referenced `FakeBciDeviceRepository` is missing `deleteDevice` — compile error if copied verbatim.**
   The plan delegates the full fake implementation to
   `.ai-factory/notes/177-test-plan-bci-device-manager-reducer.md` § "Fakes Required". That
   note's `FakeBciDeviceRepository implements BciDeviceRepository` implements only
   `cachedSerials`, `fetchKnownSerials`, and `registerDevice`. But `BciDeviceRepository`
   (`lib/Bci/BciDeviceRepository.dart:43`) also declares `Future<void> deleteDevice(String id)`.
   Since the fake uses `implements`, Dart requires a concrete `deleteDevice` or the file will
   not compile ("Missing concrete implementation of BciDeviceRepository.deleteDevice").
   The manager never calls it, so a one-line `@override Future<void> deleteDevice(String id) async {}`
   (or `throw UnimplementedError()`) suffices. The plan body says "implement its implicit
   interface," which is correct guidance, but the literal reference code in the note is
   incomplete — call this out so the implementer adds the method.

2. **Task 5 needs a connect-gating mechanism that the reference fake does not provide.**
   Task 5 case `should report state as BciConnecting between setState and provider.connect completing`
   instructs the implementer to "gate the fake's `connect` to assert mid-flight." However, the
   `FakeIBciDeviceProvider.connect` in note 177 completes synchronously
   (`connectCallCount++; if (connectThrows != null) throw ...`) with no `Completer` gate — unlike
   `GatedFakeDevicePort` in `neiry_bci_provider_locator_device_races_test.dart`, which uses
   completers for exactly this. The implementer must add a `Completer<void>? connectGate` to the
   fake and `await` it inside `connect()` before resolving. The same gating is useful for the
   auto-connect (Task 2) and reconnect (Task 6) cases that need to observe `BciConnecting`
   before `BciImpedance`. Recommend the plan add an explicit harness bullet: "expose a
   completable `connectGate` on the fake so tests can observe the in-flight `BciConnecting` phase."

### Consider

3. **Task 1, case "should not emit when transitioning to the same non-active state."**
   The plan mandates driving state "via the public API (no direct `_setState` access)" but does
   not name which public call reaches the `BciIdle → BciIdle` dedup branch (line 132–134). The
   natural path is calling `disconnect()` while already `BciIdle` (it calls `_setState(BciIdle())`,
   which dedup-suppresses). Worth naming explicitly so the implementer does not reach for a
   direct `_setState` call that the plan forbids.

4. **Async-ordering reminder is correct but easy to under-apply.**
   The plan correctly flags `unawaited(...)` microtasks (reconnect, record) needing
   `await pumpEventQueue()`. Note specifically that `_attemptReconnect()` is fired via
   `unawaited()` from inside the connection-state listener (line 72), so after
   `emitConnectionStatus(BciLinkStatus.down)` the test must pump the event queue **twice** in
   effect — once for the listener, once for the reconnect microtask and the scan subscription —
   before the reconnect `scan()` controller handle even exists. The `record` catchError path
   (Task 4 "still emit BciReady when record throws") also needs a pump since the throw happens
   on an unawaited future. This is implied but worth stating so flaky-by-timing tests are avoided.

5. **`latestValid` in the reference fake uses `firstWhereOrNull`.** That requires
   `import 'package:collection/collection.dart';` in the spec file (the production manager
   already imports it). Minor — just ensure the import is present.

## Positive Notes

- Excellent line-level grounding: each task cites the exact source lines it pins, and they all
  check out against the current file. This is the strongest signal the plan was written against
  the real code, not from memory.
- The decision to drive every reducer branch through the **public API** rather than reaching
  into `_setState` is the right call — it keeps the tests coupled to behavior, not to the
  private method, and survives internal refactors.
- Good coverage breadth: dedup branches, transition guards, invalid-calibration routing,
  error-swallowing paths, dispose no-op, and all three `_attemptReconnect` termination paths
  (onDone / onError-permission / onError-generic) are each pinned.
- Correctly identifies that fakes fully replace the repositories, sidestepping
  `SharedPreferences` and gRPC test infra — accurate and keeps the suite fast and hermetic.

## Conclusion

The plan is architecturally sound and faithful to the codebase. The two "should fix" items are
gaps in the **referenced fake harness** (a missing interface method and an absent connect gate),
not flaws in the test strategy — but because the plan delegates fake implementation to note 177
verbatim, an implementer following it literally will hit a compile error (finding 1) and be
unable to satisfy Task 5 (finding 2). Address those two before implementation.
