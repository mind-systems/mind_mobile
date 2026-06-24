# Plan Review: Serialize calibration through the queue + guard against dispose (T1)

**Plan:** `90-t1-serialize-calibration-through-the-queue-guard-against-dispose-decision-a-vs-b.md`
**Files Reviewed:** plan + `lib/Bci/NeiryBciProvider.dart`, `lib/Bci/SerialCommandQueue.dart`, `lib/Bci/BciDeviceManager.dart`, `lib/Bci/BciNotifier.dart`, `test/Bci/neiry_bci_provider_command_queue_test.dart`, spec note `165-bci-serialize-calibration-through-queue.md`
**Risk Level:** 🟢 Low

## Verification of factual claims

All concrete references in the plan were checked against the codebase and are accurate:

- **Line numbers:** `startCalibration` at `:275`, `startQuickCalibration` at `:311`, `importCalibration` at `:339`, `_teardownAfterUnexpectedDrop` at `:382` (comment about leaving `_calibrationSub` alive at `:380`), `_doDispose` calibration-sub cancel at `:549`. ✓ All correct.
- **`_disposed` field** exists (`:47`); `StreamController.isClosed` is a valid getter, so `_calibrationController.isClosed` works for the closed-controller guard. ✓
- **Emit-call inventory:** `startCalibration` has exactly 3 adds (StageFinished `:281`, Completed `:298`, onError Failed `:303`) — matches "both calls and the onError add". `startQuickCalibration` has 2 adds (Completed `:329`, catch Failed `:332`) — matches "success and catch". `importCalibration` has no calibration emit — matches "no `_emitCalibration` needed". ✓
- **Queue-safety (CONSTRAINT 1):** confirmed all three methods await only static `neiry.NfbCalibrator.*` futures/stream, never another `_queue` op. No self-deadlock. ✓
- **Caller-impact claim:** `BciDeviceManager.startCalibration`/`startQuickCalibration` (`:237`/`:251`) both wrap the provider call in `try/catch` + `logPrint` + state reset, so a post-dispose `QueueClosedException` is caught, not crashed. `importCalibration` has no caller in `lib/` (only the interface decl). ✓ No manager changes needed.
- **Drop-path constraint:** `_teardownAfterUnexpectedDrop` indeed does not cancel `_calibrationSub`; only `_doDispose` does. Plan correctly forbids changing this. ✓
- **Spec fidelity:** plan's Decision A matches the recommended option in note `165`, including the CONSTRAINT 1 caveat. ✓

## Context Gates

- **ARCHITECTURE.md** — No boundary violations. The change stays inside the `neiry_kit` adapter (`NeiryBciProvider`), the only file permitted to import `neiry_kit`. No domain model leaks across the module boundary. ✓ PASS
- **RULES.md** — The three rules concern Module Services / App.dart / constructor injection; none apply to this provider-internal change. Logging facade (`logPrint`) is preserved, no `print`/`debugPrint` introduced. ✓ PASS
- **ROADMAP.md** — T1 traces to Phase 56 follow-up; this is a `fix` (correctness) task with a clear spec note. Linkage present. ✓ PASS

## Critical Issues

None. The plan is implementable as written.

## Observations (non-blocking, WARN)

1. **Race (b) is only partially closed for the full `startCalibration` path — the plan should not be read as fully eliminating it.**
   The plan (and spec note `165`) state Option A "closes both (a) and (b)". This is fully true only for `startQuickCalibration` and `importCalibration`, which `await` their work *inside* the queue slot and therefore serialize against a teardown command. For `startCalibration`, the command body only sets up `calibrateIndividual().listen(...)` and returns quickly (the plan correctly says the subscription "persists outside the slot"). Because `_teardownAfterUnexpectedDrop` deliberately does **not** cancel `_calibrationSub`, a drop-triggered `device.disconnect()/dispose()` can still run concurrently with the still-live `calibrateIndividual()` stream. So for the full-calibration path, Option A prevents the **add-after-close crash (a)** via the `_emitCalibration` guard but does **not** fully eliminate lifecycle race **(b)** — it only removes the *enqueue-time* overlap, not the subscription's lifetime overlap. This is an inherent consequence of the "preserve resume-after-reconnect → don't cancel `_calibrationSub` in the drop path" constraint, so it is acceptable for this milestone; the implementer just shouldn't expect (b) to be provably gone for the subscription path, and should not "fix" it by cancelling the sub in the drop path. No task change required — just calibrated expectations.

2. **Test cannot literally `await _queue.idle` — the phrasing should resolve to microtask flushes.**
   Task 5 says "await `_queue.idle` equivalent / a microtask flush". `_queue` is private and there is no public idle/await hook on the provider, so the test must use the same `await Future<void>.delayed(Duration.zero)` microtask-flush pattern the existing suite already uses (see the existing tests at lines 198–211). The plan does offer "a microtask flush" as the alternative, so this is just a clarification, not a defect.

3. **Test should tolerate the rejected enqueue explicitly.**
   With Option A, `provider.startQuickCalibration()` after `dispose()` returns a Future that completes with `QueueClosedException`. The test must not bare-`await` it (that would surface as a test failure); it should `expectLater(..., throwsA(isA<StateError>()))` or wrap in try/catch. The plan acknowledges this ("which the test may expect and tolerate") — flagging so the implementer wires it correctly.

4. **Minor — `return _queue.enqueue(...)` inside an `async` method is valid but slightly redundant.**
   Returning a `Future<void>` from a method declared `Future<void> ... async` flattens correctly (no analyzer error), so the plan's wording is fine. The implementer may optionally drop the `async` keyword on the wrapper since the body becomes a single `return`. Purely stylistic.

## Positive Notes

- The plan correctly identifies that the *important* half of the fix is the `_emitCalibration` closed-controller guard (Task 1), because the long-lived `startCalibration` subscription emits **outside** the queue slot — the queue rejection alone would not protect that path. This is the subtle point the design hinges on, and the plan gets it right.
- Task dependencies are correctly ordered (Task 1 → Tasks 2–4 → Task 5).
- Out-of-scope boundary is explicit and correct: the duplicated 11-field neiry↔domain mapping is correctly deferred to `171-bci-extract-calibration-mapping` rather than entangled here.
- Constraints section faithfully preserves the resume-after-reconnect behavior and the queue's CONSTRAINTs, with accurate line citations.
- Verification step includes both the analyzer and the B1/B2 regression suites, with the exact test file names.

## Conclusion

The plan is precise, faithful to the spec, correct on every file path / line number / API reference, and implementable as written. The observations above are advisory (calibrated expectations on race (b), and test-wiring clarifications) and do not block implementation.

PLAN_REVIEW_PASS
