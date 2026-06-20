# Code Review: Render the list from Drift (offline-first cold start; invalidate() re-reads Drift)

**Review 1** · Branch `dev` · Reviewed `git diff HEAD` + full surrounding files.

## Scope of changes (code)

| File | Change |
|------|--------|
| `lib/BreathModule/Core/IBreathSessionRepository.dart` | + `localSessions()` to interface |
| `lib/BreathModule/Core/BreathSessionRepository.dart` | + `localSessions()` → `_dao.getSessions()` (pure local read, no API) |
| `lib/BreathModule/Core/Models/BreathSessionNotifierEvent.dart` | + `LocalSessionsLoaded` event |
| `lib/BreathModule/Core/BreathSessionNotifier.dart` | + `_readLocalEntries()`, `loadLocal()`; `invalidate()` now async re-reads Drift + emits `LocalSessionsLoaded`; `_onUserIdChanged` awaits `invalidate()` |
| `lib/Core/App.dart` | + `await breathSessionNotifier.loadLocal();` right after construction, before `syncEngine` |
| `test/BreathModule/breath_session_notifier_test.dart` | + fake `localSessions()`; user-change test asserts `LocalSessionsLoaded` |

## Verdict

The implementation faithfully realizes the approved plan. Traced every runtime path; no bugs, security, or correctness defects. Findings below are **non-blocking advisories**.

## Verified correct

- **Interface fan-out is complete.** Only two implementers of `IBreathSessionRepository` exist — `BreathSessionRepository` (implemented) and the test fake `FakeBreathSessionRepository` (implemented). The `docs/core/testing.md` occurrence is documentation, not compiled. No compile break.
- **Empty-Drift seed asymmetry is implemented as specified.** `loadLocal()` returns early on empty entries (no emit) → BehaviorSubject keeps its seeded `lastEvent: null` → `observeChanges()` `expand` returns `[]` on replay → ViewModel `initialLoading` skeleton holds. `invalidate()` always emits even when empty. The two correctly diverge only in the empty case, sharing `_readLocalEntries()`.
- **Privacy wipe preserved.** `_onUserIdChanged` awaits `deleteAll()` (sets fake `_sessions = []`) before `invalidate()` re-reads `localSessions()` → empty → `buildSectionedEntries([], user)` → `[]`. No cross-user leakage. The `skip(1)` on the auth stream still suppresses the seeded identity, so no spurious wipe on construction.
- **User-change test trace is sound.** After `load(null,10)` on a single session, `nextCursor` is `null`; the wipe re-read preserves that null and emits `LocalSessionsLoaded` with empty entries → all three assertions (`entries isEmpty`, `nextCursor isNull`, `isA<LocalSessionsLoaded>`) hold, and `deleteAllCount == 1`. The single `Future.delayed(Duration.zero)` still drains the now-slightly-longer microtask chain (extra `localSessions()` await is microtask-level).
- **Service layer untouched and compatible.** `observeChanges()` routes `LocalSessionsLoaded` through its "all other events → `ListUpdatedEvent`" branch (only `SessionsInvalidated` is special-cased). `currentItems()` reads `notifier.currentState.entries`, now warm from the seed. No change needed, none made.
- **App init ordering is correct.** `await loadLocal()` runs after the notifier is constructed and before `syncEngine` / `waitForColdStart`, so `currentState.entries` is warm before any screen builds. Guest with empty Drift: `loadLocal()` no-ops, falls through to the existing network path.
- **No lint regression from async `invalidate()`.** The project uses `package:flutter_lints/flutter.yaml`, which does **not** enable `unawaited_futures`; the two unawaited `invalidate()` calls in `SyncEngine` will not fail `flutter analyze`.
- **`SessionsInvalidated` dead branch** (ViewModel `_handleSessionsInvalidated`, Service `SessionsInvalidatedEvent`) is now unreachable, as the plan intends. No live regression — the only `invalidate()` caller firing while the list is mounted is the SyncEngine delta path, which is strictly improved.

## Non-blocking findings

### 1. Unrelated audio asset changes are staged (process — not this milestone)
`git diff --stat` shows `assets/audio/tick_clock.ogg` (8413→7211 bytes) and `assets/audio/tick_heartbeat.ogg` (7211→8413 bytes) staged. The byte sizes are **swapped**, which suggests the two tick sounds may have been accidentally exchanged. These are pre-existing staged changes unrelated to the Drift-render work. **Action:** confirm they belong in this commit (and aren't a swap mistake) before committing the milestone, or unstage them.

### 2. `invalidate()` exceptions are now silently unhandled in `SyncEngine` (LOW, robustness)
`SyncEngine._processEvents` (line 120) and `_handleFullResync` (line 126) call `breathSessionNotifier.invalidate();` fire-and-forget. Previously `invalidate()` was a synchronous `void` that only pushed to a `BehaviorSubject` and could not realistically throw. It now performs a DB read (`localSessions()` → `getSessions()`); if that read throws, the discarded `Future` produces an **unhandled async error** instead of surfacing. Practically low risk (a local DAO read failing is rare), but if hardening is desired, wrap these calls in `unawaited(...)` with a `.catchError`/try, or `await` them inside the already-async methods. Not required for correctness.

### 3. Mounted-list delta renders the full Drift set against a stale cursor (INFO, note-133 territory)
When the list is mounted and a SyncEngine delta fires `invalidate()`, the emitted `ListUpdatedEvent` carries the **entire** Drift set while `nextCursor`/`hasMore` are carried over from the prior network pagination. This is the same network-vs-Drift reconciliation the plan explicitly defers to note 133 (and is consistent with the documented "content shrink" design note). Calling it out so it isn't mistaken for a defect: functionally the list shows all cached rows; the cursor/`hasMore` coupling is intentionally left for the refresh rework.

## Conclusion

The milestone's code is correct, matches the plan, keeps existing tests compiling/passing, and introduces no bug, security, or correctness problem. The only must-do before commit is a **non-code** check: confirm the staged `tick_clock.ogg`/`tick_heartbeat.ogg` swap is intentional. Findings 2 and 3 are advisory.

REVIEW_PASS
