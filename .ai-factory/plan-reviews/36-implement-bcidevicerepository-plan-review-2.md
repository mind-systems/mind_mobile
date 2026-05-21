# Plan Review (v2): Implement `BciDeviceRepository`

**Plan:** `.ai-factory/plans/36-implement-bcidevicerepository.md`
**Milestone (ROADMAP.md):** Phase 17 — "Implement `BciDeviceRepository`"
**Previous review:** `36-implement-bcidevicerepository-plan-review-1.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md** — WARN. The general architecture rule says Repository must not import Flutter / Riverpod, and `package:shared_preferences/shared_preferences.dart` is a Flutter plugin (depends on `flutter/services.dart`). The milestone description explicitly mandates `SharedPreferences prefs` in the constructor, so this is an intentional, milestone-level override of the general rule. The plan now calls this out explicitly in its Context section ("intentional override … kept verbatim per the milestone spec"), so the deviation is documented rather than accidental. Acceptable.
- **RULES.md** — PASS. No conflict with the three project rules (Module Services statelessness, App.dart purity, constructor DI). The repository is not a Module Service, does not touch `App.dart`, and uses constructor injection (`api`, `prefs`).
- **ROADMAP.md** — PASS. Plan matches the milestone description's API surface: file path `lib/Bci/BciDeviceRepository.dart`, cache key `'bci_known_serials'`, JSON array storage, sync `cachedSerials() → List<String>`, server-order preservation, idempotent `registerDevice`, cache updated only after successful `fetchKnownSerials()`, constructor signature `BciDeviceRepository({required BciDevicesGrpcApi api, required SharedPreferences prefs})`.

## Resolution of v1 Findings

### Issue #1 (task ordering breaks compile) — RESOLVED ✅

V1 had three tasks where Task 2 called `_writeCache` introduced only in Task 3, and the dependency arrow ran backwards. V2 collapses to two tasks in the correct dependency order: **Task 1** ships skeleton + `cachedSerials()` + `_writeCache()` (no remote calls), **Task 2** adds the three remote methods (uses `_writeCache` from Task 1). Each task leaves the project compiling.

### Issue #2 (corrupt-cache catch too narrow) — RESOLVED ✅

V1 specified `on FormatException`, which would have missed `TypeError` on wrong-shape valid JSON. V2 uses an unqualified `catch (_)` plus an explicit `is! List` guard and `whereType<String>()`, which silently drops non-string entries instead of throwing. This covers all three failure modes (`FormatException` on malformed JSON, `TypeError` on wrong top-level type, `TypeError` on non-string entries) without crashing the startup path. Plan inlines the rationale ("called synchronously on the startup path … must never throw") so a future editor won't narrow it back down.

### Issue #3 (concrete `BciDevicesGrpcApi` instead of interface) — NOT ADDRESSED, NON-BLOCKING

V2 still takes the concrete `BciDevicesGrpcApi`. This is faithful to the milestone wording (`BciDevicesGrpcApi api`) and v1 already flagged it as non-blocking. The interface `IBciDevicesGrpcApi` exists at `lib/Bci/IBciDevicesGrpcApi.dart` and matches the dominant `BreathSessionRepository` → `IBreathSessionApi` pattern, so using it would cost nothing and improve testability. Still non-blocking; deferring to milestone spec is defensible.

### Issue #4 (empty-string guard never triggers) — RESOLVED ✅

The empty-string branch is gone from Task 1. Only `raw == null` short-circuits; any other shape falls through to the `try`/`catch` which now handles every wrong-shape case.

### Issue #5 (`_writeCache` failure rejects whole `fetchKnownSerials`) — NOT ADDRESSED, NON-BLOCKING

Still no `.catchError` around `_writeCache(serials)` inside `fetchKnownSerials`. Disk-write failure under SharedPreferences would reject a call that otherwise succeeded remotely. Trivial in practice; v1 already flagged as optional. Acceptable.

## New Findings

### Codebase cross-check

- `BciDevicesGrpcApi.listDevices()` returns `Future<List<({String id, String serial})>>` — plan's `devices.map((d) => d.serial).toList()` works because record-field access is structural. ✅
- `BciDevicesGrpcApi.register(String serial)` returns `Future<({String id, String serial})>` — plan discards the result, fine because next-milestone `BciDeviceManager` doesn't need it. ✅
- `BciDevicesGrpcApi.delete(String id)` returns `Future<void>` — `deleteDevice(String id)` forwards `id` directly. ✅
- `shared_preferences: ^2.3.4` is already in `pubspec.yaml`. No new dependency required. ✅
- Directory `lib/Bci/` exists (`BciDevicesGrpcApi.dart`, `IBciDevicesGrpcApi.dart`, `IBciDeviceProvider.dart`, `NeiryBciProvider.dart`, `Models/`). Adding `BciDeviceRepository.dart` alongside fits. ✅
- `_cacheKey = 'bci_known_serials'` matches the milestone-mandated key exactly. ✅

### Minor observation (non-blocking)

`Task 2` describes `deleteDevice(String id)` — note the parameter is the device `id` (server-assigned), not the `serial`. This is correct per the API contract, and downstream milestones (Phase 17's `BciNotifier`) don't expose delete UI yet, so the caller mapping isn't a concern here. Worth keeping in mind only because the rest of the API surface keys off `serial`.

## Positive Notes

- The catch-all decision is justified inline with a forward-looking reason ("future serialization changes"), not just a description of current behavior — this saves the next reviewer from re-litigating the choice.
- Plan correctly preserves server ordering (`do not sort`) and documents *why* (server is already `updated_at DESC`) — consistent with the milestone and with Phase 17's auto-connect-most-recent semantics.
- `register` idempotency note references both the API source and the milestone, so a future contributor won't add client-side de-dup by reflex.
- Cache write happens only after a successful remote fetch — local mutators (`registerDevice`, `deleteDevice`) do not touch the cache. Matches the milestone's "source of truth is the server" invariant.
- Sync `cachedSerials()` (returns `List<String>`, no `Future`) is correctly identified as required by the next milestone's `BciDeviceManager.startScan()` synchronous auto-connect decision.
- No try/catch around remote calls — matches existing repository style; error handling deferred to `BciNotifier`/`BciDeviceManager` per the upcoming milestones.
- The override of the "no Flutter imports in repository" architecture rule is explicitly flagged in the plan's Context section with a cross-reference to how `AppSettingsRepository` solves the same problem differently (`IAppSettingsStorage`). Future readers will understand it is intentional, not a slip.

## Recommendation

V2 addresses both critical issues from v1. The plan is faithful to the milestone, matches the existing API surface, and the implementation is small enough (~30 lines, 2 tasks) that there is little surface area for regression. Ready to implement.

PLAN_REVIEW_PASS
