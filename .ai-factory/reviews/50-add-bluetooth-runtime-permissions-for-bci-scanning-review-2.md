# Review 2 — Add Bluetooth runtime permissions for BCI scanning

## Code Review Summary

**Files Reviewed:** 12 source files (Android manifest, iOS plist, domain layer, module layer, l10n) + 2 pubspec files
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (.ai-factory/ARCHITECTURE.md):** ✅ Module/domain boundary preserved — `permission_handler` is acknowledged as a controlled coupling (only `BciDiscoverySection` calls `openAppSettings()`; `bci_module` package gains a single platform-plugin import for that purpose only). Domain code (`NeiryBciProvider`, `BciDeviceManager`) does not import any Flutter or UI symbols.
- **Rules (.ai-factory/RULES.md):** ✅ `BciPairingService` remains stateless — no `StreamController`, no `dispose()`. New reducer branches use only `bciNotifier.stream.scan(...)`. No App.dart wiring added; no module-state pollution.
- **Roadmap (.ai-factory/ROADMAP.md):** ✅ Roadmap modified in the same diff to record this milestone.

### Critical Issues

None.

### Notes / Minor Observations (non-blocking)

1. **AndroidManifest deviates from plan in a positive way.** The plan specified an unconditional `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />`, but the implementation added `android:maxSdkVersion="30"`. This is consistent with the conditional permission request in `NeiryBciProvider.scan()` (`if (sdkInt < 31) Permission.locationWhenInUse`) and is the recommended pattern when paired with `BLUETOOTH_SCAN`'s `neverForLocation` flag on Android 12+. The deviation is correct.

2. **`onDone` callback added to `BciDeviceManager.startScan()` (not in plan).** This addition is justified — without it, the "soft denial" path in `NeiryBciProvider.scan()` (where the stream completes silently with no events on Android non-permanent denial) would leave `_state` stuck at `scanning` indefinitely. The new `onDone` correctly transitions to `disconnected` only when still in `scanning` state, so the post-error `bluetoothPermissionDenied` state is preserved (`onError` runs first and changes `_state` so the `onDone` predicate is false).

3. **Comment in `_attemptReconnect()` references "line 185" but the actual `_setState(scanning)` is at line 190.** Cosmetic only; the dedup-safety reasoning is sound.

4. **`openAppSettings()` is called fire-and-forget** (returns `Future<bool>`). Standard usage — no bug, but the boolean indicating whether the platform call succeeded is discarded. Acceptable since failure here has no actionable handler.

5. **First-build alert behavior is handled correctly via re-emission.** `ref.listen` does not fire on the initial build, but `BciPairingViewModel.initState()` invokes `service.startScan()`, which forces a `scanning → bluetoothPermissionDenied` transition through the reducer when permission is still denied. The rising edge in `BciDiscoverySection` then fires the dialog as expected.

6. **Reducer correctly clears `isBluetoothPermissionDenied` on both `scanning` and `disconnected`** branches, preventing the flag from persisting across user-driven `disconnect()` or normal scan completion. This matches plan tasks 9 verbatim.

### Positive Notes

- The `_setState` dedup-safety analysis in `BciDeviceManager` is documented inline as the plan required, so future readers won't have to re-derive the reasoning.
- iOS branch correctly treats only `isPermanentlyDenied` / `isRestricted` as hard denial and lets `denied` / `notDetermined` fall through to CoreBluetooth's native prompt, exactly as specified.
- `WidgetsBindingObserver` is registered/unregistered in `initState`/`dispose`, `mounted` is checked before reading `ref` in `didChangeAppLifecycleState`, and the rescan call uses `ref.read(...notifier)` rather than capturing context — no stale-context bug.
- `BciPairingState.copyWith` uses the simple `bool?` + `??` pattern for the new flag rather than the `_undefined` sentinel, matching existing `isScanning` / `isConnecting` shape — internally consistent.
- l10n delegate files were regenerated and committed (both `app_localizations.dart` abstract definitions and the two locale concrete files), so CI/other branches won't break on missing getters.
- The new `bluetoothPermissionDenied` enum value is appended to `BciConnectionState`, preserving the ordering of pre-existing values (no breakage of any code that might rely on `.index` or persisted ordinals — none was found in `lib/` but the discipline is good).
- `BciDeviceManager._subscribeProviderStreams` was updated to exclude `bluetoothPermissionDenied` from the "unexpected disconnect" auto-reconnect trigger — without this, the provider's downstream disconnect emission (`NeiryConnectionState.disconnected` → `BciConnectionState.disconnected`) would have logged "unexpected disconnect" and re-armed reconnect, looping the user through the alert. Catches a subtle race.

REVIEW_PASS
