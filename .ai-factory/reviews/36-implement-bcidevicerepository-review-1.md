# Code Review: Implement `BciDeviceRepository`

**Plan:** `.ai-factory/plans/36-implement-bcidevicerepository.md`
**File under review:** `lib/Bci/BciDeviceRepository.dart` (new, 46 lines)
**Risk Level:** 🟢 Low

## Scope of changes

Per `git diff HEAD --stat`:
- `lib/Bci/BciDeviceRepository.dart` — new file (46 lines)
- `.ai-factory/plans/36-implement-bcidevicerepository.md` — plan
- `.ai-factory/plan-reviews/36-implement-bcidevicerepository-plan-review-{1,2}.md` — plan reviews

No other source files modified. No `pubspec.yaml` change (the `shared_preferences` dep was already present).

## Plan ↔ Code

- ✅ Pure-Dart file under `lib/Bci/` — no Flutter/Riverpod imports beyond the explicitly-mandated `shared_preferences`.
- ✅ Imports match plan: `dart:convert`, `shared_preferences`, `mind/Bci/BciDevicesGrpcApi.dart`.
- ✅ `static const String _cacheKey = 'bci_known_serials';` matches the milestone-mandated key exactly.
- ✅ Constructor signature is verbatim from milestone: `BciDeviceRepository({required BciDevicesGrpcApi api, required SharedPreferences prefs})`.
- ✅ `cachedSerials()` is synchronous (returns `List<String>`, no `Future`) — required by the next milestone's `BciDeviceManager.startScan()` synchronous auto-connect decision.
- ✅ Corrupt-cache catch is the wide form: `try { ... } catch (_) { return const <String>[]; }` plus `is! List` guard plus `whereType<String>()`. All three failure modes (malformed JSON, wrong top-level type, non-string entries) return an empty list.
- ✅ `_writeCache` invoked only after successful remote fetch; local mutators (`registerDevice`, `deleteDevice`) do not touch the cache. Server is source of truth.
- ✅ Server order preserved (no `sort`).
- ✅ `register` called without de-duplication (server is idempotent).
- ✅ No try/catch around remote calls — error handling deferred to `BciNotifier`/`BciDeviceManager` per upcoming milestones.

## Cross-checks against existing code

- `BciDevicesGrpcApi.listDevices()` returns `Future<List<({String id, String serial})>>` — `devices.map((d) => d.serial)` resolves via record-field access. ✅
- `BciDevicesGrpcApi.register(String serial)` returns `Future<({String id, String serial})>` — result discarded, matches plan. ✅
- `BciDevicesGrpcApi.delete(String id)` returns `Future<void>` — `deleteDevice(String id)` forwards the `id` directly. The naming asymmetry (the rest of the API keys off `serial`; `delete` keys off the server-assigned `id`) is correct per the gRPC contract and matches `BciDevicesServiceClient.delete(DeleteBciDeviceRequest(id: id))`.
- `shared_preferences` package is already a transitive dependency — `SharedPreferencesStorage` (`lib/Core/AppSettings/SharedPreferencesStorage.dart`) imports it the same way. No pubspec change required. ✅
- `SharedPreferences.getString` returns `String?`; `setString` returns `Future<bool>` — `await`ing the future is fine, discarding the `bool` (success flag) matches the pattern used everywhere else in the codebase.

## Runtime correctness

- `cachedSerials()` is non-throwing under every conceivable cache state: missing key, malformed JSON, valid JSON of wrong type, or list with non-string entries. The startup path is safe.
- `fetchKnownSerials()` — if `_api.listDevices()` rejects, the exception propagates and `_writeCache` is not called (stale cache preserved). Correct.
- `_writeCache` is awaited inside `fetchKnownSerials()`. A disk-write failure (rare, e.g. disk pressure) would reject the whole call even though the remote fetch succeeded. v1 plan review flagged this as trivial/non-blocking; the current behavior is acceptable and the caller (next milestone's `BciDeviceManager`) will handle errors at a single point.
- No thread/concurrency hazards: `SharedPreferences` is single-flight; method-local variables only.
- `flutter analyze` on the new file: "No issues found" (verified).

## Findings

None.

REVIEW_PASS
