# Plan: Implement `BciDeviceRepository`

## Context
Add the BCI device repository that bridges the remote `BciDevicesGrpcApi` and a local `SharedPreferences` cache of known device serials. The cache lets the pairing UI auto-connect to recently used devices at startup without waiting for a network round trip.

Note: the milestone explicitly mandates `SharedPreferences prefs` in the constructor. This is an intentional override of the general "no flutter imports in repositories" architecture rule (cf. `AppSettingsRepository`, which uses `IAppSettingsStorage` instead) — kept verbatim per the milestone spec.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Repository

- [x] **Task 1: Create `BciDeviceRepository` class skeleton with local cache**
  Files: `lib/Bci/BciDeviceRepository.dart`
  Create a new pure-Dart file (no Flutter/Riverpod imports beyond `shared_preferences`) under `lib/Bci/`.
  - Imports: `dart:convert` (for `jsonEncode`/`jsonDecode`), `package:shared_preferences/shared_preferences.dart`, `package:mind/Bci/BciDevicesGrpcApi.dart`.
  - Declare `class BciDeviceRepository`.
  - Add `static const String _cacheKey = 'bci_known_serials';`.
  - Private final fields: `final BciDevicesGrpcApi _api;` and `final SharedPreferences _prefs;`.
  - Named constructor: `BciDeviceRepository({required BciDevicesGrpcApi api, required SharedPreferences prefs}) : _api = api, _prefs = prefs;`.
  - Implement `List<String> cachedSerials()` — synchronous:
    - Read `final raw = _prefs.getString(_cacheKey);`.
    - If `raw == null`, return `const <String>[]`.
    - Wrap the decode in `try { ... } catch (_) { return const <String>[]; }` (catch-all, not `on FormatException`) so any corrupt-cache failure mode — malformed JSON (`FormatException`), wrong shape (`TypeError` on cast/iteration), or future serialization changes — returns an empty list instead of throwing. `cachedSerials()` is called synchronously on the startup path by the next milestone's `BciDeviceManager.startScan()` and must never throw.
    - Inside the `try`, decode via `jsonDecode(raw)`. If the result `is! List`, return `const <String>[]`. Otherwise return `decoded.whereType<String>().toList()` — silently drops non-string entries rather than throwing on cast.
  - Implement `Future<void> _writeCache(List<String> serials) async`:
    - `await _prefs.setString(_cacheKey, jsonEncode(serials));`.
  - This task ships the cache helpers without any remote methods; the class compiles standalone.

- [x] **Task 2: Implement remote methods (`fetchKnownSerials`, `registerDevice`, `deleteDevice`)** (depends on Task 1)
  Files: `lib/Bci/BciDeviceRepository.dart`
  - `Future<List<String>> fetchKnownSerials() async`:
    - Call `final devices = await _api.listDevices();`.
    - Map to `final serials = devices.map((d) => d.serial).toList();`. Server order is "most recently used first" (already ordered by `updated_at DESC` per the API) — preserve order, do not sort.
    - `await _writeCache(serials);` then return `serials`. Cache is updated only on successful remote fetch.
  - `Future<void> registerDevice(String serial) async`:
    - Call `await _api.register(serial);` and discard the result. `register` is server-side idempotent (see `BciDevicesGrpcApi.register` and the milestone description), so no client-side de-dup is needed.
  - `Future<void> deleteDevice(String id) async`:
    - Call `await _api.delete(id);`.
  - No try/catch around remote calls: callers (e.g. `BciNotifier`/`BciDeviceManager` in following milestones) decide error handling, matching the existing repository style.
  - Local mutators (`registerDevice`, `deleteDevice`) do not touch the cache — the source of truth is the server, and the next `fetchKnownSerials()` refreshes it.
