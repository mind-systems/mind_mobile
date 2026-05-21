# Plan Review: Implement `BciDeviceRepository`

**Plan:** `.ai-factory/plans/36-implement-bcidevicerepository.md`
**Milestone (ROADMAP.md):** Phase 17 — "Implement `BciDeviceRepository`"
**Risk Level:** 🟡 Medium (small, contained — but task ordering breaks compile)

## Context Gates

- **ARCHITECTURE.md** — WARN. Architecture rule: "Notifier and Repository must NOT import flutter/ or riverpod." `package:shared_preferences/shared_preferences.dart` is a Flutter plugin (depends on `flutter/services.dart`), so strictly speaking the plan violates the rule. However, the milestone description explicitly mandates `SharedPreferences prefs` in the constructor, so this is an explicit milestone override of the general rule, not a plan error. Acceptable. Note that `AppSettingsRepository` solves this by going through an `IAppSettingsStorage` abstraction — the plan does not do that and instead takes `SharedPreferences` directly per the milestone.
- **RULES.md** — PASS. No conflict with stated project rules (Module Services statelessness, App.dart purity, constructor DI). This task is repository-only and does not touch App.dart or any Service.
- **ROADMAP.md** — PASS. Plan matches the milestone description's API surface (cache key `bci_known_serials`, JSON array, server-order preservation, idempotent `registerDevice`, sync `cachedSerials()`).

## Critical Issues

### 1. Task ordering breaks compile after Task 2

Task 2 calls `_writeCache(serials)` (line 30: "Persist via the cache helper added in Task 3 (`_writeCache(serials)`)") but `_writeCache` is introduced only in Task 3. The dependency arrow is also backwards — Task 3 is declared "depends on Task 2", but Task 2 cannot compile until Task 3 exists.

If `/aif-implement` ships tasks one at a time (the usual pattern, with each task expected to leave the project compiling), Task 2 will fail. Two acceptable fixes:

- **Swap order:** make the cache helpers Task 2 (no dependency on remote) and the remote methods Task 3 (depends on cache). This matches the actual call direction.
- **Merge Tasks 2 and 3** into a single "implement all methods" task — they are ~15 lines combined and there is no review value in splitting them.

Recommend the swap.

### 2. Corrupt-cache catch is too narrow

Task 3 specifies "wrap in `try/catch` on `FormatException` to make corrupt cache non-fatal." `FormatException` only covers `jsonDecode` failing on malformed JSON. If the stored value is *valid JSON but wrong shape* — e.g. `"not-a-list"`, `42`, `{"a":1}`, or `[1,2,3]` (numbers) — the failure mode is different:

- `jsonDecode("42") as List` → `TypeError`
- `jsonDecode("[1,2,3]").map((e) => e as String).toList()` → `TypeError` on iteration

Neither is a `FormatException`. The startup path (`cachedSerials()` is called synchronously by `BciDeviceManager.startScan()` per the next milestone) must never throw on a corrupt cache.

Either widen the catch (`on Object catch (_)` or unqualified `catch (_)`), or guard with `is` checks: `if (decoded is! List) return const <String>[]; return decoded.whereType<String>().toList();`. The `whereType<String>()` variant has the nice property of silently dropping non-string entries instead of throwing.

## Minor Issues

### 3. Constructor parameter typed as concrete class, not interface

Plan takes `BciDevicesGrpcApi api`. The interface `IBciDevicesGrpcApi` already exists at `lib/Bci/IBciDevicesGrpcApi.dart` and the existing repository convention (`BreathSessionRepository` takes `IBreathSessionApi`) prefers interfaces for testability. The milestone description does say "`BciDevicesGrpcApi api`" verbatim, so the plan is faithful to the milestone — but using `IBciDevicesGrpcApi` would cost nothing and match the dominant project pattern. The concrete `DeviceRepository` (which also takes a concrete `DeviceApi`) is the only counter-example.

Non-blocking. If the implementer prefers the interface here, the milestone wording would not prevent it.

### 4. Empty-string guard on `getString` is defensive but never triggers

`SharedPreferences.getString` returns `null` when the key is absent and the stored string otherwise. Task 3 says "If `raw == null` or empty, return `const <String>[]`." Since `_writeCache` always writes `jsonEncode(serials)` (minimum `"[]"`, never `""`), the empty-string branch is dead. Harmless, but worth noting that the only way `raw == ""` could happen is data corruption from outside the app, which the broader corrupt-cache catch already handles.

### 5. `_writeCache` never returns the cached serials on write failure

`_writeCache` is `await`-ed inside `fetchKnownSerials()`. If `setString` throws (extremely rare, but possible under disk pressure), the whole `fetchKnownSerials()` call rejects even though the remote fetch succeeded. Existing repos do not wrap remote calls in `try/catch` (plan correctly preserves this), but the local-write failure here is different in kind — a server fetch succeeded and the caller would still benefit from the returned list.

Trivial. If you care: `await _writeCache(serials).catchError((_) {})` before `return serials;`. Otherwise leave as-is and let the caller decide.

## Positive Notes

- Plan correctly identifies that `IBciDevicesGrpcApi.listDevices()` returns records `({String id, String serial})` and extracts `.serial` with `.toList()`.
- Server order preservation is called out explicitly ("do not sort").
- Idempotency of `register` is documented inline with a reference to the API source and milestone description — future readers will not be tempted to add client-side de-dup.
- Cache write happens only on successful remote fetch — local mutators (`registerDevice`, `deleteDevice`) correctly do not touch the cache. This matches the milestone's "source of truth is the server" semantics.
- Sync `cachedSerials()` (no `Future`) is correctly identified — the next milestone (`BciDeviceManager.startScan`) needs a sync read for the auto-connect decision before the screen renders.
- Pure-Dart constraint is documented ("no Flutter/Riverpod imports") — the implementer will not add `flutter/foundation.dart` or Riverpod by reflex.
- No try/catch around remote calls — matches existing repository style and the next milestone's `BciNotifier`/`BciDeviceManager` error-handling layer.

## Recommendation

Address issue #1 (swap task order or merge Tasks 2 and 3) and issue #2 (widen the corrupt-cache catch). After those two edits, the plan is ready to implement.

