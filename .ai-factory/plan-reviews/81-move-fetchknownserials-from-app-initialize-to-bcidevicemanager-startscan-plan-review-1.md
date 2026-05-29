# Plan Review: Move `fetchKnownSerials()` from `App.initialize()` to `BciDeviceManager.startScan()`

**Plan:** `.ai-factory/plans/81-move-fetchknownserials-from-app-initialize-to-bcidevicemanager-startscan.md`
**Files Reviewed:** 2 (plan, BciDeviceManager.dart, BciDeviceRepository.dart, App.dart)
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** PASS — change preserves the established layering (Repository → Manager → Notifier). No boundary crossed; module-internal refactor.
- **RULES.md:** PASS (and a strong positive). Rule #2 says: *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only (DB, HTTP, notifiers, sync). Module concerns belong in the module's Service or coordinator."* The plan directly improves compliance: it removes a BCI-specific cache-warm trigger from `App.initialize()` and relocates it into the module's own manager.
- **ROADMAP.md:** PASS — Plan matches the open Phase 23 milestone (`ROADMAP.md:183`) verbatim in intent. The plan correctly substitutes `logPrint` for the roadmap's stylistic `log(...)` placeholder, since `logPrint` is the actual symbol exported by `package:mind/Logger.dart` and used everywhere in `BciDeviceManager`.

## Verification of Plan Claims

All file paths and line references were verified against the current tree:

- `lib/Bci/BciDeviceManager.dart`:
  - `import 'dart:async';` is line 1 → `unawaited` is in scope. ✅
  - `import 'package:mind/Logger.dart';` is line 17 → `logPrint` is in scope. ✅
  - `unawaited(_attemptReconnect())` exists at line 66. ✅
  - `unawaited(_repository.registerDevice(...))` exists at lines 176–178. ✅
  - `startScan()` spans lines 119–168. ✅
  - The forced `_stateController.add(BciConnectionState.scanning)` block ends at line 127. ✅
  - `final cachedSerials = _repository.cachedSerials();` is line 129. ✅
- `lib/Bci/BciDeviceRepository.dart`:
  - `fetchKnownSerials()` returns `Future<List<String>>`. ✅ (`catchError` returning `<String>[]` matches.)
  - `cachedSerials()` is synchronous and reads from `SharedPreferences` — independent of the in-flight fetch, so the cache snapshot taken at line 129 is consistent with today's "use whatever is already on disk" semantics. ✅
- `lib/Core/App.dart`:
  - Line 172 contains exactly `unawaited(bciRepository.fetchKnownSerials().catchError((Object e) { return <String>[]; }));`. ✅
  - Surrounding construction (lines 161–171) is independent of this line and can stay untouched. ✅
  - `grep` confirms no other reference to `fetchKnownSerials` in `App.dart` once line 172 is deleted. ✅

## Critical Issues

None.

## Recommendations / Nitpicks

1. **Behavioural delta on first-ever screen open (acknowledged, but worth restating).** Before this change, the cache was warmed during app startup, so the very first `startScan()` after launch could auto-connect on its first scan tick. After this change, the first `startScan()` reads the cache *before* the fresh fetch resolves, so:
   - **Cold install:** no auto-connect on first scan (cache empty regardless).
   - **Subsequent launches:** still auto-connects from the previously-persisted cache, so no UX regression.
   - **Only edge case:** a user who registers a device on Device A, then immediately launches on Device B (same account) and opens the BCI screen, will not auto-connect on the very first scan tick because the local cache is empty until the fetch resolves. The next `startScan()` (or the same `startScan()` if the fetch resolves quickly and the scan tick refires) picks it up. This matches the behaviour the plan promises ("freshly-fetched serials become available on the next scan") and is acceptable for the intended use case, but is worth keeping in mind when QA runs the BCI flow.

2. **No throttling between rapid scan starts.** If the user repeatedly enters/leaves the BCI screen, each `startScan()` fires a new `fetchKnownSerials()` gRPC call. This was a non-issue when the call was at app start (once per process), but is now per-scan. In practice scans are user-initiated and infrequent, and `BciDevicesGrpcApi.listDevices()` is idempotent and cheap, so this is non-blocking. Not worth adding a guard.

3. **Logging is intentionally minimal.** No log line on success — matches the plan's "logging: minimal" setting and the existing `registerDevice` failure-only pattern. Good.

4. **`unawaited` after `await` ordering.** Plan places the fire-and-forget call *before* the `await _scanSub?.cancel()` on line 131. That is the correct placement: the fetch must start as early as possible so it has the best chance to resolve before the cache is read by a later scan tick, and the `await _scanSub?.cancel()` is the first true async hop in the method. ✅

## Positive Notes

- The plan explicitly anchors every change to a line number and an existing reference pattern (the `registerDevice` fire-and-forget, the existing `App.initialize()` empty-list fallback). Easy to implement without ambiguity.
- The plan explicitly *prevents* a likely mistake by calling out that `_attemptReconnect()` must **not** also call `fetchKnownSerials()` (since reconnect keys off `_connectedSerial`, not the cache). Saves a follow-up review cycle.
- Removing line 172 of `App.dart` aligns the file with RULES.md rule #2 — a small but real cleanup.

PLAN_REVIEW_PASS
