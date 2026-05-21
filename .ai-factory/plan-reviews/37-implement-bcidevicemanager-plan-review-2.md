# Plan Review 2: Implement `BciDeviceManager`

**Plan file:** `.ai-factory/plans/37-implement-bcidevicemanager.md`
**Spec:** `.ai-factory/notes/16-bci-device-manager.md`
**Previous review:** `.ai-factory/plan-reviews/37-implement-bcidevicemanager-plan-review-1.md`
**Risk level:** 🟢 Low
**Files Reviewed:** 1 plan + spec + 5 codebase files (`IBciDeviceProvider.dart`, `BciDeviceRepository.dart`, `NeiryBciProvider.dart`, `Logger.dart`, BCI domain models)

## Context Gates

- **Architecture (ARCHITECTURE.md):** OK. The manager remains in the domain layer (`lib/Bci/`), consumes only the existing `IBciDeviceProvider` interface and `BciDeviceRepository`, and exposes streams without leaking plugin types. No layering violations introduced.
- **Rules (RULES.md):** OK. Dependencies injected through constructor; no `App.dart` wiring in this milestone; `pubspec.yaml` modified only via `flutter pub add` per project CLAUDE.md.
- **Roadmap (ROADMAP.md):** OK. Plan implements the unchecked Phase 17 milestone "Implement `BciDeviceManager`" verbatim against the linked spec.

## Resolution of v1 Findings

All seven items from review 1 are resolved in v2:

| # | v1 Finding | v2 Resolution |
|---|---|---|
| 1 | Missing `flutter pub add collection` | New **Task 0** runs `flutter pub add collection` and verifies `pubspec.yaml` / `flutter pub get`. ✅ |
| 2 | "Pure Dart" wording inaccurate | Assumptions reworded: "No Riverpod imports; no direct Flutter UI imports; logging via the shared `logPrint` helper (which itself uses `package:flutter/foundation`'s `debugPrint`), matching the compromise already accepted in `NeiryBciProvider.dart`." ✅ |
| 3 | Placeholder subscriptions not assigned to fields | Task 1 now shows explicit assignments (`_connectionStateSub = …`, `_calibrationSub = …`) and adds the imperative: *"Field assignment is mandatory; do not write bare `_provider.connectionStateStream.listen((_) {});` — that leaks the subscription."* ✅ |
| 4 | `startCalibration` could leave manager stuck in `calibrating` | Task 4 now wraps `_provider.startCalibration()` in try/catch and transitions back to `impedance` on failure, mirroring `connectDevice` policy. ✅ |
| 5 | `BciCalibrationFailed.reason` was swallowed | Switch case now uses `case BciCalibrationFailed(:final reason)` and logs via `logPrint('BciDeviceManager: calibration failed: $reason')`. ✅ |
| 6 | Scan streams lacked `onError` | Both `startScan()` (Task 2) and `_attemptReconnect()` (Task 5) now attach `onError` that logs and transitions to `disconnected`. ✅ |
| 7 | `connectDevice` precondition (informational) | Carried forward as an explicit informational note in Task 3 flagged for the next milestone. ✅ |

## Critical Issues

None. The plan is internally consistent and faithful to the spec.

## Minor Notes (non-blocking)

### 1. Task 4 description vs. snippet: "cancel-then-reassign" wording is slightly misleading
Task 4 says: *"Replace the empty calibration-stream subscription installed by `_subscribeProviderStreams` in Task 1: cancel the placeholder first (`await _calibrationSub?.cancel();`) then reassign with the real handler"*, but the code snippet immediately below does not include any `cancel()` call, and the next paragraph clarifies *"Place the re-subscription inside `_subscribeProviderStreams` (replacing the placeholder line directly)."*

These two phrasings describe different mechanics. The final intent is a direct line replacement inside `_subscribeProviderStreams`, where the placeholder source line is removed and replaced by the real handler — no runtime cancel needed because the placeholder no longer exists in the committed code. The "cancel-then-reassign" sentence is a leftover that an implementer could read as "add a cancel call before the real listen". Suggest dropping that sentence or making the snippet match.

The same comment applies to Task 5's connection-state subscription replacement, which uses the same phrasing.

### 2. No reconnect backoff (out of scope per spec)
If `_attemptReconnect()` succeeds via `connectDevice`, transitions to `impedance`, and the device immediately drops again, the unexpected-disconnect listener will re-enter `_attemptReconnect()` with no backoff. With a flaky device this loops indefinitely. The spec is silent on backoff and the BciNotifier/UI milestone is the natural place to add it (e.g. exponential backoff or attempt-count cap). Flagging for the next milestone — not in scope here.

### 3. `unawaited(_repository.registerDevice(serial))` swallows async errors silently
Task 3's fire-and-forget registration after a successful connect intentionally does not await. If the server is unreachable, the future completes with an error in the background and nothing logs it. Under the "minimal logging" budget this is acceptable, but a one-liner `.catchError((e) => logPrint('BciDeviceManager: registerDevice failed: $e'))` would cost almost nothing and aid diagnostics. Optional.

## Positive Notes

- **Every v1 WARN was addressed in detail.** v2 reads as a careful response rather than a perfunctory rewrite — e.g. Task 1's snippet now demonstrates the field assignment, with an explicit imperative against bare `.listen(...)` calls.
- **Rationale-rich task bodies.** Each non-trivial decision is accompanied by a short justification (e.g. why the listener data handler is async, why state guards skip `scanning`, why the cache lookup is synchronous, why provider lifecycle is not the manager's responsibility). This will significantly reduce review friction at implementation time.
- **State-mutation funnel** preserved: `_setState` is the only writer, with a no-op-on-duplicate guard.
- **Race protection in auto-connect** (`_state == scanning` guard before `connectDevice`) carried forward in both `startScan` and `_attemptReconnect` — prevents late scan emissions from clobbering a manual user tap or a successful auto-connect.
- **Order of `_suppressAutoReconnect` assignment** before `await _provider.disconnect()` is correctly justified — the broadcast event is delivered after the synchronous `_setState(disconnected)`, so the unexpected-disconnect listener's `_state != disconnected` guard short-circuits cleanly.
- **Provider lifecycle ownership** explicitly excluded from `dispose()` with rationale — prevents future double-dispose once `App.initialize` wiring lands.
- **Task decomposition** continues to be one-concern-per-task with explicit dependency arrows, and the new Task 0 (`flutter pub add collection`) gates correctly on Task 1.
- **Spec fidelity** — all transitions in the spec table are preserved, including `BciCalibrationFailed → impedance` recovery and the dual-scope of `cachedSerials` (cache-wide for fresh scans, single-serial for reconnect).

PLAN_REVIEW_PASS
