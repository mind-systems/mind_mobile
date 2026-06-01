# Plan Review — Tear down the neiry `Device` on an unexpected disconnect

**Plan:** `106-tear-down-the-neiry-device-on-an-unexpected-disconnect-so-auto-reconnect-works.md`
**Target file:** `lib/Bci/NeiryBciProvider.dart` (single file)
**Risk Level:** 🟢 Low

## Verdict
The plan is correct, implementable, and faithful to both the codebase and the source spec
(`.ai-factory/notes/52-task-neiry-device-teardown-on-drop.md`). The root-cause diagnosis is
accurate, the file path and API surface are right, and no migrations or cross-project changes
are involved. Findings below are non-blocking refinements only.

## Diagnosis verification (confirmed against source)
- `connect()` (lines 147–153) hard-throws `StateError` when `_device != null`. ✓
- `_onNeiryConnectionState` (lines 246–256) currently only forwards `disconnected` — it never
  nulls `_device`, cancels subscriptions, or disposes classifiers. ✓
- `BciDeviceManager._subscribeProviderStreams` (lines 60–73) reacts to the `disconnected` emit
  by calling `_attemptReconnect()` → `connectDevice()` → `_provider.connect(serial)`, which then
  hits the `StateError` guard. ✓ So the stated failure mode is real.
- `_connectionStateController` is a **broadcast** controller (lines 43–44), so `.add()` delivers
  to the manager's listener on a later microtask — never synchronously inside
  `_onNeiryConnectionState`. The async-teardown / null-before-emit design is sound. ✓
- `disconnect()` nulls `_device` (line 470), so the idempotency guard `if (_device == null) return;`
  correctly distinguishes a user-initiated disconnect from an unexpected drop. ✓
- `unawaited` is already in scope via `dart:async` (used in `dispose()`, line 481). ✓

## Context Gates
- **Architecture (`ARCHITECTURE.md`):** PASS. The change stays entirely inside
  `NeiryBciProvider`, the only file permitted to import `neiry_kit`. No boundary crossed; consumers
  still depend on `IBciDeviceProvider`.
- **Rules (`RULES.md`):** PASS. The stateless-module-Service rule and constructor-injection rule
  target module Services/`App.dart`, not this domain provider. No violation.
- **Roadmap (`ROADMAP.md`):** PASS — linked. Matches the unchecked Phase 26 item at line 247 and
  its spec note 52. This is a `fix`; linkage is present.

## Critical Issues
None.

## Minor Notes (non-blocking)
1. **"11 subscriptions" wording.** Task 1 prose says "the 11 `StreamSubscription` fields" but then
   lists 10 and excludes `_calibrationSub`. The spec note (line 19) likewise says "cancel the 11
   subscriptions." The actionable instruction — mirror `_cancelDeviceSubscriptions()`, which cancels
   exactly those 10 and leaves `_calibrationSub` (lines 413–433) — is correct and unambiguous; only
   the count word is loose. Suggest the implementer just say "the same 10 device-stream subscriptions
   that `_cancelDeviceSubscriptions()` cancels" to avoid the off-by-one confusion.
2. **`_calibrationSub` left active on a mid-calibration drop.** The plan (correctly) mirrors
   `disconnect()`/`_cancelDeviceSubscriptions()` and does not cancel `_calibrationSub`. This is
   internally consistent with the existing `disconnect()` path (only `_doDispose()` cancels it). If
   a drop occurs mid-calibration, the calibration subscription survives the teardown — acceptable and
   consistent, but worth a one-line awareness during implementation in case stale `BciCalibrationEvent`s
   are undesirable post-drop.
3. **`unsupportedConnection` → reconnect loop.** Applying teardown to the `unsupportedConnection` case
   means the manager will auto-reconnect and likely hit "unsupported" again. This is **pre-existing
   behavior** (the case already emits `disconnected` today), not a regression introduced by the plan.
   No action required.
4. **"null-before-emit is load-bearing" framing.** Because the controller is broadcast, any
   synchronous nulling within the same callback (before yielding to the event loop) is sufficient —
   ordering relative to the `.add()` line within the callback is not actually the load-bearing part.
   The plan's prescribed ordering is nonetheless correct and safe; no change needed.

## Positive Notes
- The re-entrancy hazard (tearing down inside `_connectionSub`'s own callback) is explicitly
  identified and correctly deferred to an `unawaited`/microtask path — matching the existing
  `dispose()` → `unawaited(_doDispose())` shape.
- The idempotency guard is precisely specified as a *true no-op* (not `{ emit; return; }`), with a
  correct rationale for why a second emit would be redundant noise.
- Controllers are correctly left open so reconnect can resume emitting.
- Scope is tightly bounded to one file; `disconnect()`, `_cancelDeviceSubscriptions()`, and
  `_doDispose()` are explicitly left untouched, minimizing blast radius.
- Verification is correctly specified as an on-device drop test (the only way to exercise a native
  BLE drop and confirm no `StateError`/SIGABRT).

PLAN_REVIEW_PASS
