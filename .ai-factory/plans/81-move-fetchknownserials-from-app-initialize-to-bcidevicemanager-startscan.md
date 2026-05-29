# Plan: Move `fetchKnownSerials()` from `App.initialize()` to `BciDeviceManager.startScan()`

## Context
Defer the `bciRepository.fetchKnownSerials()` gRPC call until the user actually opens the BCI screen, removing one network call per session for users who never use BCI. Behaviour for users who open the BCI screen is unchanged — the cache is refreshed when scanning starts.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Move the fetch call

- [x] **Task 1: Trigger `fetchKnownSerials()` at the start of `BciDeviceManager.startScan()`**
  Files: `lib/Bci/BciDeviceManager.dart`
  In `startScan()` (currently lines 119–168), immediately after the forced `BciConnectionState.scanning` emit block (i.e. after the `_stateController.add(BciConnectionState.scanning);` block, before the `final cachedSerials = _repository.cachedSerials();` line), insert a fire-and-forget refresh of the known-serials cache:
  ```dart
  unawaited(_repository.fetchKnownSerials().catchError((Object e) {
    logPrint('BciDeviceManager: fetchKnownSerials failed: $e');
    return <String>[];
  }));
  ```
  Notes:
  - `unawaited` is already imported transitively via `dart:async` (used elsewhere in the file — see `unawaited(_attemptReconnect())` at line 66 and `unawaited(_repository.registerDevice(...))` at line 176). No new imports required.
  - `logPrint` is already imported via `package:mind/Logger.dart` (line 17). Use it to match existing failure-logging style in this file (e.g. `registerDevice` failure handler at lines 176–178).
  - `fetchKnownSerials()` returns `Future<List<String>>`, so `catchError` must return a `List<String>` — mirror the empty-list fallback used today in `App.initialize()` (`lib/Core/App.dart:172`).
  - Do not `await` the result. The existing `cachedSerials()` read on line 129 intentionally uses whatever is already cached in `BciDeviceRepository`; the freshly-fetched serials become available on the next scan (same observable behaviour as today, since `App.initialize()` also fires-and-forgets).
  - Do not call `fetchKnownSerials()` in `_attemptReconnect()` — reconnect matches against the already-known `_connectedSerial`, not the repository cache.

- [x] **Task 2: Remove the fire-and-forget call from `App.initialize()`**
  Files: `lib/Core/App.dart`
  Delete line 172:
  ```dart
  unawaited(bciRepository.fetchKnownSerials().catchError((Object e) { return <String>[]; }));
  ```
  Leave the surrounding `bciRepository` / `bciDeviceManager` / `bciNotifier` construction (lines 161–171) untouched. Verify no other lines in `App.initialize()` reference `fetchKnownSerials` after the deletion.

<!-- orchestrator-sessions
planner: f709e629-2c31-4cc3-9834-bddce2139a40
elapsed: 275
implementer: 29760fa4-2dd4-463a-b265-c06f391dfabb
-->
