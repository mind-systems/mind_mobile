# Plan Review: BciDeviceManager reducer and reconnect tests (round 3)

**Plan:** `.ai-factory/plans/100-bcidevicemanager-reducer-and-reconnect-tests.md`
**Risk Level:** 🟢 Low — pure test-coverage plan; no production code, no migrations, no proto changes.

## Scope

Adds `test/Bci/bci_device_manager_test.dart` with fakes to directly exercise `BciDeviceManager`'s
sealed-state reducer (`_setState` dedup), forward connection path, calibration routing, derived
`connectedSerial`, and auto-reconnect policy. This is the third review; reviews 1 and 2 raised four
substantive findings and several nits — this pass confirms whether they were absorbed and
re-verifies the plan's grounding against the live code.

## Verification performed (against current source)

All citations re-checked against the actual files, not carried over from prior reviews:

- **`lib/Bci/BciDeviceManager.dart` (315 lines)** — every line range matches: `_subscribeProviderStreams`/connection listener 64–75, calibration listener 76–103, `connectedSerial` getter 109, `_setState` 130–140 (dispose guard 131, type-dedup 132–134, serial-dedup 135–136), `startScan` 155–215 (suppress reset 156, direct-write bypass 160–162, auto-connect 189–196, onError 198–208, onDone 209–213), `connectDevice` 217–235 (BciConnecting 218, connect 220, serial set 221, registerDevice 222, mid-flight guard 228–229, catch 231–234), `startCalibration` 237–249 (guard 238, totalStages 4 at 240, catch 245–247), `startQuickCalibration` 251–263 (totalStages 1 at 254, catch 259–261), `disconnect` 265–272, `_attemptReconnect` 274–313 (second `scan()` at 277, match 284–290, onError 299–305, onDone 307–310). All accurate.
- **`IBciDeviceProvider.dart`** — `scan()` returns a fresh stream per call (line 27, contract documented 22–26). Full interface surface the fake must satisfy confirmed: `scan`, `connect`, `disconnect`, `connectionStateStream`, `signalQualityStream`, `batteryStream`, `calibrationStream`, `startCalibration`, `startQuickCalibration`, `importCalibration(NfbCalibrationData)` (71), `dispose()` (78).
- **`BciDeviceRepository.dart`** — concrete class; `deleteDevice(String id)` present at line 43–45 exactly as the plan flags. The implicit interface the fake must satisfy is `cachedSerials`, `fetchKnownSerials`, `registerDevice`, `deleteDevice`.
- **`NfbCalibrationRepository.dart`** — `record(String, NfbCalibrationData, {@visibleForTesting bool awaitApiSync = false})` at 55–59 ✓; `history(serial)` 22, `latestValid(serial)` 37 (iterates `history`, returns first `isValid`) ✓. The plan's note that a `firstWhereOrNull`-based fake needs `import 'package:collection/collection.dart'` is correct.
- **`NfbCalibrationData.dart`** — exactly 11 required fields (31–43). Allowed `failReason` values include `"none"` and `"tooManyArtifacts"` (13–20), matching the builder helper spec.
- **Anchors exist:** grounding note `.ai-factory/notes/177-test-plan-bci-device-manager-reducer.md` present; `GatedFakeDevicePort` reference pattern lives in `test/Bci/neiry_bci_provider_locator_device_races_test.dart` (present); target spec file does **not** yet exist (no overwrite risk).

## Prior findings — disposition

- **R2 Issue 1 / R1-impl gap (Task 6 `connectedSerial`-null case tested the wrong branch).** **Resolved.** Task 6 (plan line 106) now drives the line-71 serial guard via a gated `connectDevice('A')` left mid-flight in `BciConnecting` (serial set at 221 happens *after* `BciConnecting` at 218), emits `down`, and asserts no reconnect scan. It explicitly distinguishes this from the line-68 "down while scanning" case. Correct.
- **R1/R2 (connect gating absent from harness).** **Resolved.** Plan line 23 adds a completable `connectGate` (`Completer<void>? connectGate`, awaited inside `connect()` after the counter bump, defaulting to `null`), citing the in-repo `GatedFakeDevicePort` pattern. Required by Task 5 and Task 6 and now specified.
- **R1/R2 (fakes must override the full implicit interface).** **Resolved.** Plan lines 21/24/25 now call out `importCalibration` + `dispose` on the provider fake, `deleteDevice` on the repo fake (with the one-line stub), and `history` + `latestValid` + the `awaitApiSync` named param on the calibration-repo fake.
- **R2 Issue 4 (multi-scan controller handle).** **Resolved.** Plan line 22 mandates the list-based design exposing `_scanControllers.last` so reconnect-discovery emissions reach the second `scan()` controller.
- **R1/R2 (double-pump for reconnect; pump for record catchError).** **Resolved.** Plan line 29 spells out the double-pump (listener microtask then reconnect microtask + its `scan()` subscription) and the `record` catchError pump.
- **R1/R2 nits (Task 1 `BciIdle→BciIdle` via `disconnect()`; `describe` vs `group`).** **Resolved.** Plan line 39 names `disconnect()` from idle as the public path; line 19 corrects to "`flutter_test` has no `describe` — only `group`/`test`."

Every actionable finding from the two prior reviews has been folded into the plan text. No regressions introduced.

## Context Gates

- **Architecture gate — PASS.** Test-only addition inside the `lib/Bci/` domain; no boundary, layering, or dependency-direction change. `.ai-factory/ARCHITECTURE.md` is unaffected.
- **Rules gate — PASS.** `.ai-factory/RULES.md` covers module-service statelessness and constructor DI. The plan relies on `BciDeviceManager`'s fully constructor-injected dependencies and injects fakes the same way — no rule conflict. No `skill-context/aif-review/SKILL.md` present, so no project-specific output overrides apply.
- **Roadmap gate — PASS (WARN).** Behaviors under test trace to Phase 51 (sealed state) and Phase 53. This is `test`-type work with no production-behavior change, so milestone linkage is optional; the plan does not name a ROADMAP milestone. Non-blocking.

## Findings

No blocking issues. Two nits only:

### Nit 1 (wording): "quick-calibration retry increment" comment in Task 3
Task 3 (plan line 66) annotates `should emit BciCalibrating with totalStages 1 ... (line 254 — quick-calibration retry increment)`. Line 254 simply sets `BciCalibrating(serial, totalStages: 1)`; there is no counter/increment in that path. The annotation is harmless but slightly misleading — the assertion (totalStages == 1) is correct.

### Nit 2 (implementation hint, not a defect): dedup-matrix cases that need two overlapping `BciConnecting` states
Task 1's `BciConnecting('A') → BciConnecting('A')` (same-type/same-serial dedup) and `BciConnecting('A') → BciConnecting('B')` (same-type/different-serial emit) are both reachable purely via the public API by issuing two `connectDevice(...)` calls while `connectGate` is held un-completed (so the first stays in `BciConnecting`). The plan already provides `connectGate`, so this is feasible without direct `_setState` access — just worth the implementer keeping in mind that these cases require an overlapping gated call rather than a single connect.

## Positive Notes

- Branch coverage remains exhaustive and each case carries an exact line citation that checks out against the live file: full dedup matrix (same/diff type × same/diff serial, post-dispose), both calibration outcomes (valid→Ready, invalid→Impedance) plus failed/progress/guarded-ignore, both scan error paths (permission vs generic) and onDone, all three `_attemptReconnect` terminations, and the error-swallow paths (`record`, `registerDevice`).
- The plan drives every reducer branch through the **public API** rather than poking `_setState`, keeping tests coupled to behavior and refactor-resilient.
- Async discipline is now precisely specified (double-pump for reconnect, pump for unawaited `record` throw, `await manager.dispose()` in `tearDown`), which is the main flakiness hazard for this suite.
- The harness section correctly anticipates the full implicit-interface obligation of `implements`, the per-call `scan()` controller contract, and the `connectGate` seam — the three things that would otherwise surface as compile/timing failures mid-implementation.

## Conclusion

The plan is accurate, fully grounded in the current code, and has absorbed every finding from rounds 1 and 2. The remaining items are wording/implementation nits with no impact on correctness or coverage. Ready to implement.

PLAN_REVIEW_PASS
