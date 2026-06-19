# Code Review: BCI connection — split link-layer from domain phase + sealed identity

**Scope reviewed:** `git diff HEAD` — 7 source files (`BciLinkStatus.dart` new, `BciConnectionState.dart`, `IBciDeviceProvider.dart`, `NeiryBciProvider.dart`, `BciDeviceManager.dart`, `BciPairingService.dart`, `BciDataService.dart`).
**Risk:** 🟢 Low — implementation matches the plan and spec; verified independently against surrounding code.

## What I verified

- **No leftover enum-member references.** Grep across `lib/` for `BciConnectionState.`, `.disconnected`, `.bluetoothPermissionDenied`, `_connectingSerial` returns only unrelated `GrpcConnectionState` / `neiry.NeiryConnectionState` hits. The side-channel field and the `devices.length == 1` heuristic are fully removed.
- **Imports are clean.** `NeiryBciProvider` and `IBciDeviceProvider` dropped the `BciConnectionState` import in favor of `BciLinkStatus`; both reference only `BciLinkStatus` now (no unused import, no dangling reference). Consumers that use the sealed subtypes (`BciDeviceManager`, `BciPairingService`, `BciDataService`) keep the single `BciConnectionState.dart` import — all subtypes live in that one library, so the sealed `switch` compiles exhaustively.
- **Exhaustiveness.** Both rewritten switches (`BciDataService._reduce` and `BciPairingService._reduceStateChanged`) cover all 7 concrete leaves (`BciIdle`, `BciScanning`, `BciPermissionDenied`, `BciConnecting`, `BciImpedance`, `BciCalibrating`, `BciReady`) with no `default`. `BciActive` is abstract/sealed, so listing its 4 leaves individually is correct.
- **`_setState` dedup predicate is correct.** It short-circuits on `runtimeType` inequality first, then compares `serial` only for same-type `BciActive` pairs. `BciImpedance(x) → BciReady(x)` differs by `runtimeType` and therefore emits — the impedance→ready (and impedance→calibrating) transitions are not swallowed. Same-type/same-serial re-entries are correctly deduped. This matches the predicate the plan review asked for.
- **Reconnect-trigger widening is benign.** The new guard fires the unexpected-disconnect path when `status == BciLinkStatus.down && _state is BciActive`, which now includes `BciConnecting` (the old enum guard excluded `connecting`). I traced `NeiryBciProvider`: `_connectionSub` — the only source of `BciLinkStatus.down` from the native stream — is subscribed in `_subscribeDeviceStreams()` (`:189`) which runs **only after** `await _device!.connect()` and `await _device!.start()` succeed (`:186`). During the manager's `BciConnecting` window (`await _provider.connect(serial)` in flight) no `_connectionSub` is live, so no `down` can interleave. The explicit-disconnect emit (`:589`) runs only under `disconnect()`, which sets `_suppressAutoReconnect = true`. Additionally, on a first connect `_connectedSerial` is still null during the connecting window, so the `_connectedSerial != null` guard blocks reconnect regardless. No runtime regression; the implementer documented the inclusion in a code comment (the plan review's accepted option b).

## Observations (informational, no action required)

- **Latent bug fixed as a side effect.** `BciPairingService` now sets `connectedSerial: serial` in the `BciCalibrating` and `BciReady` arms too (previously omitted, relying on persistence from the `impedance` arm). Because the service seeds via `startWith(BciStateChanged(currentState))`, a fresh subscriber that attaches while the manager is already in `calibrating`/`ready` previously reduced from `initial()` and ended up with `connectedSerial == null`. The serial is invariant across `connecting→impedance→calibrating→ready`, so feeding it in every `BciActive` arm is strictly more correct and closes that gap.
- **Double-connect on same-serial re-entry** (e.g. `connectDevice(A)` while already `BciConnecting(A)`) is deduped by `_setState` but the method body still re-invokes `_provider.connect`, which throws `StateError` on a non-null `_device`. This is pre-existing behavior (the old enum dedup had the same shape) and out of scope — flagging only for awareness.
- **Style nit (non-blocking):** `BciConnectionState _state = BciIdle();` could use `const BciIdle()`. No correctness impact.

## Conclusion

The change is correct, the migration surface is complete, and every `switch` site is compiler-checked for exhaustiveness. The link-layer/domain split makes "connecting without serial" unrepresentable and removes the multi-device auto-connect bug at its root. No blocking or non-blocking bugs found.

REVIEW_PASS
