# Code Review: Move `fetchKnownSerials()` from `App.initialize()` to `BciDeviceManager.startScan()`

**Plan:** `.ai-factory/plans/81-move-fetchknownserials-from-app-initialize-to-bcidevicemanager-startscan.md`
**Files changed:** `lib/Bci/BciDeviceManager.dart`, `lib/Core/App.dart`
**Risk:** Low

## Diff vs. plan

Both tasks were executed verbatim:

- `lib/Bci/BciDeviceManager.dart:129-132` — inserted the fire-and-forget `fetchKnownSerials()` call exactly where the plan specified (after the forced `_stateController.add(BciConnectionState.scanning)`, before the `cachedSerials()` read). Uses `unawaited` (in scope via `dart:async` line 1) and `logPrint` (in scope via `package:mind/Logger.dart` line 17). `catchError` returns `<String>[]`, matching the `Future<List<String>>` signature of `fetchKnownSerials()` (`BciDeviceRepository.dart:32`).
- `lib/Core/App.dart` — line 172 removed. Surrounding `bciRepository` / `bciDeviceManager` / `bciNotifier` construction (now lines 161–171) untouched. Confirmed via `git diff` that no other reference to `fetchKnownSerials` remains in `App.dart`.

## Correctness

- **Type contract.** `fetchKnownSerials()` is `Future<List<String>>`; `catchError` arm returns `<String>[]`. Sound; compiler-clean.
- **Symbol availability.** `unawaited` and `logPrint` are both already used elsewhere in `BciDeviceManager.dart` (`unawaited(_attemptReconnect())` at line 66, `unawaited(_repository.registerDevice(...))` at lines 181–183, multiple `logPrint(...)` calls). No new imports required.
- **Ordering.** The fire-and-forget call is placed before `await _scanSub?.cancel()` (line 136), which is the first true async hop in the method. This gives the fetch the earliest possible start without blocking the synchronous state emit. Correct placement.
- **`cachedSerials` snapshot semantics.** `cachedSerials()` (`BciDeviceRepository.dart:16-26`) reads `SharedPreferences` synchronously; `fetchKnownSerials()` (`BciDeviceRepository.dart:32-37`) writes to `SharedPreferences` after the gRPC call resolves. Because the fetch is fire-and-forget and `cachedSerials` is captured into a local at line 134 *before* the fetch resolves, the in-flight scan will not auto-connect on serials newly returned by this fetch — only the next `startScan()` will see them. This is identical to the prior behaviour (App-startup fetch was also fire-and-forget) and is explicitly called out in the plan. Acceptable.
- **No regression in `_attemptReconnect()`.** The plan explicitly excludes adding a fetch there, and the diff confirms it was not touched. Reconnect keys off `_connectedSerial`, not the repository cache, so no fetch is needed there.
- **No interaction with `connectDevice` / `registerDevice`.** `registerDevice` still writes to the server but does **not** update the local cache (`BciDeviceRepository.dart:39-41`). Pre-existing behaviour — out of scope.

## Runtime / lifecycle concerns

- **Dispose race.** If `startScan()` is called and `dispose()` runs before the gRPC future resolves, the success path of `fetchKnownSerials()` writes to `SharedPreferences` (harmless) and the error path only calls `logPrint` — no controller access, no `_disposed`-gated mutation. Safe.
- **Multiple rapid `startScan()` calls.** Each call now fires an additional `fetchKnownSerials()` gRPC request. Pre-existing scans are not throttled, and `listDevices` is idempotent/cheap, so this is acceptable; not worth adding a guard. Not a bug introduced by this change.
- **Cold-start UX.** Before this change, the cache was warmed at app launch, so the very first `startScan()` post-install could auto-connect using a freshly-fetched server list. After this change, the very first `startScan()` reads the local (possibly stale or empty) cache before the new fetch lands. For a returning user this is a no-op (cache already populated). For a user who registered a device on one phone and is opening BCI on a second device for the first time, auto-connect lands on the *next* scan rather than the first. Plan acknowledges this; matches the milestone's "behaviour is unchanged for users who open the BCI screen" promise within reasonable bounds.

## Style / conventions

- Logging follows the existing in-file pattern (`'BciDeviceManager: <action> failed: $e'`). Consistent with `registerDevice` error handler.
- No unrelated edits.

## RULES.md compliance

The change removes a BCI-specific concern from `App.initialize()` (which RULES.md mandates remain infrastructure-only) and relocates it into the BCI module. Small but real cleanup.

## Findings

None.

REVIEW_PASS
