# Plan Review: Implement `BciDeviceManager`

**Plan file:** `.ai-factory/plans/37-implement-bcidevicemanager.md`
**Spec:** `.ai-factory/notes/16-bci-device-manager.md`
**Risk level:** 🟢 Low

## Context Gates

- **Architecture (ARCHITECTURE.md):** OK. The plan places the manager in the domain layer (`lib/Bci/`), consumes the existing `IBciDeviceProvider` abstraction and `BciDeviceRepository`, and exposes streams that will be wrapped by `BciNotifier` in the next milestone. No layering violations.
- **Rules (RULES.md):** OK.
  - Dependencies are injected through the constructor (`provider`, `repository`). ✅
  - No `App.dart` wiring is added in this milestone — explicitly deferred. ✅
  - The manager is a stateful domain class (subscribes, holds state, disposes); this is the same role `*Notifier` plays elsewhere, not a Module Service, so the "stateless services" rule does not apply.
- **Roadmap (ROADMAP.md):** OK. The plan implements the unchecked Phase 17 item "Implement `BciDeviceManager`" and faithfully follows the linked spec.

## Critical Issues

None. The plan is internally consistent with the spec and the existing `IBciDeviceProvider` / `BciDeviceRepository` contracts.

## Issues to Address

### 1. `package:collection` is not a declared dependency — `flutter pub add collection` is missing (WARN)
The plan's Assumptions section notes: *"`collection` is already a transitive dependency in `pubspec.lock`."* This is true, but:
- The project uses `package:flutter_lints/flutter.yaml`, which enables the `depend_on_referenced_packages` lint. Importing `package:collection/collection.dart` without a direct declaration in `pubspec.yaml` will trigger an analyzer warning.
- Grep across `lib/` confirms no current file imports `package:collection` — this would be the first direct use.
- The project CLAUDE.md explicitly mandates `flutter pub add <package_name>` for new packages.

**Fix:** Add a pre-Task-1 step: `flutter pub add collection`. Alternatively, drop the `package:collection` dependency entirely and inline the helper:
```dart
T? _firstWhereOrNull<T>(Iterable<T> it, bool Function(T) test) {
  for (final e in it) { if (test(e)) return e; }
  return null;
}
```
(Either fix is acceptable; the first is cleaner.)

### 2. "Pure Dart, no Flutter imports" assumption is inaccurate (WARN)
Assumptions claim the file is "pure Dart (no Flutter/Riverpod imports)", but the plan also imports `package:mind/Logger.dart`, which transitively imports `package:flutter/foundation.dart` (uses `debugPrint`). The same compromise exists in `NeiryBciProvider.dart` and is accepted project-wide, so this is **not blocking** — but the assumption statement is misleading. Reword to "no Riverpod imports; no direct Flutter UI imports; logging via the shared `logPrint` helper, matching `NeiryBciProvider`".

### 3. Task 1 placeholder subscriptions are not assigned to fields — risk of subscription leak between Task 1 and Tasks 4/5 (WARN)
Task 1 says: *"Private `void _subscribeProviderStreams()` placeholder for now: subscribe to `_provider.connectionStateStream` with an empty handler `(_) {}` ... and to `_provider.calibrationStream` with an empty handler `(_) {}`."* It does not explicitly say to assign these `listen()` calls to `_connectionStateSub` / `_calibrationSub`. If an implementer reads this literally and writes:
```dart
_provider.connectionStateStream.listen((_) {});
_provider.calibrationStream.listen((_) {});
```
the subscriptions cannot be cancelled in `dispose()` (the fields stay `null`), and they will leak if Tasks 4/5 are not landed in the same change set. Also, Task 1's `dispose()` would compile but be incomplete.

**Fix:** Make the assignment explicit in Task 1, e.g.:
> `_connectionStateSub = _provider.connectionStateStream.listen((_) {});`
> `_calibrationSub = _provider.calibrationStream.listen((_) {});`
> The handler bodies are replaced in Tasks 4 and 5, but the field assignment must be present from the start so `dispose()` can cancel them.

### 4. `startCalibration()` does not handle a throw from the provider (WARN)
Task 4:
```
_setState(BciConnectionState.calibrating);
await _provider.startCalibration();
```
If `_provider.startCalibration()` throws (e.g. the headband is offline), the manager is stuck in `calibrating` indefinitely. Even minimal robustness should wrap the call in try/catch and transition back to `impedance` on failure, matching the `BciCalibrationFailed` policy:
```dart
_setState(BciConnectionState.calibrating);
try {
  await _provider.startCalibration();
} catch (e) {
  logPrint('BciDeviceManager: startCalibration failed: $e');
  _setState(BciConnectionState.impedance);
}
```
The spec is silent on this edge case but it mirrors the existing `connectDevice` failure handling. Worth adding now to avoid a follow-up patch.

### 5. `BciCalibrationFailed.reason` is dropped without logging (WARN)
Task 4's switch:
```dart
case BciCalibrationFailed():
  _setState(BciConnectionState.impedance);
```
The plan's logging budget is "minimal", but this branch silently swallows the failure reason — a future bug here will be hard to diagnose. Capture the reason:
```dart
case BciCalibrationFailed(:final reason):
  logPrint('BciDeviceManager: calibration failed: $reason');
  _setState(BciConnectionState.impedance);
```

### 6. Scan stream has no `onError` handler (WARN)
Both `startScan()` (Task 2) and `_attemptReconnect()` (Task 5) call `_provider.scan().listen((discovered) async { ... })` without an `onError` argument. If the underlying scan stream errors (e.g. Bluetooth permission revoked mid-scan), the error propagates as an uncaught zone error and the manager remains stuck in `scanning`. Add:
```dart
onError: (Object e) {
  logPrint('BciDeviceManager: scan error: $e');
  _setState(BciConnectionState.disconnected);
},
```
to both subscriptions.

### 7. `connectDevice()` is callable from any state without a precondition guard (informational)
Per the spec the only callers in this milestone are the manager itself (auto-connect in `startScan` / `_attemptReconnect`); UI consumers come later. But the public method has no precondition — calling `connectDevice` while in `impedance` or `ready` would unconditionally transition to `connecting` and then call `_provider.connect(serial)`, which `NeiryBciProvider` will reject with `StateError`. The catch block in Task 3 handles the throw cleanly (logs, sets `disconnected`), so this is not a correctness bug — but worth noting for the next milestone (`BciNotifier`/UI) so it does not surprise the implementer.

## Positive Notes

- **State-mutation funnel** — `_setState` as the only writer to `_state` and `_stateController`, with no-op on duplicates, is the right pattern and matches existing notifiers in the codebase.
- **Race handling in auto-connect** — guarding `connectDevice` on `_state == scanning` (Task 2) is a thoughtful catch; without it, a late scan emission could clobber a manual user tap.
- **Order of `_suppressAutoReconnect` writes** — setting the flag *before* `await _provider.disconnect()` (Task 5) correctly prevents the unexpected-disconnect listener from triggering auto-reconnect during manual disconnect. The trace below confirms the broadcast event is delivered after the manager's synchronous `_setState(disconnected)`, so the listener's guard `_state != disconnected` short-circuits and no spurious "unexpected disconnect" log occurs:
  1. `await _provider.disconnect()` returns after `_connectionStateController.add(disconnected)` (event scheduled).
  2. Manager continues synchronously: `_connectedSerial = null; _setState(disconnected)`.
  3. Next microtask: listener fires, sees `_state == disconnected`, returns.
- **Idempotent server registration** — fire-and-forget `_repository.registerDevice(serial)` after every successful connect is consistent with `BciDevicesGrpcApi.register` semantics.
- **Provider lifecycle ownership** — explicit note that `dispose()` must **not** call `_provider.dispose()` is the right call and prevents a double-dispose when wiring lands in `App.initialize`.
- **Task decomposition** — each task is a single concern (skeleton, scan, connect, calibration, disconnect/reconnect) with clear file scope and explicit dependencies. Tasks 4 and 5 correctly couple changes that share state (calibration handler + `startCalibration`; manual disconnect + unexpected disconnect + reconnect).
- **Spec fidelity** — every transition in the spec's state table is preserved, including the `BciCalibrationFailed → impedance` recovery path.
