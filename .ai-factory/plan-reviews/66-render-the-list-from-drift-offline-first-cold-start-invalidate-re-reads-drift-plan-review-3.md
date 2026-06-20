# Plan Review (3): Render the list from Drift (offline-first cold start; invalidate() re-reads Drift)

**Plan:** `66-render-the-list-from-drift-offline-first-cold-start-invalidate-re-reads-drift.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — all assumptions verified against the codebase.

## Verification performed

Every file path, symbol, and behavioral claim in the plan was checked against the current source.

| Plan claim | Verified |
|---|---|
| `IBreathSessionRepository` is an interface to extend (Task 1) | ✅ `abstract interface class IBreathSessionRepository` — `BreathSession` already imported (line 1) |
| `_dao.getSessions()` exists and is currently unused by the repo (Task 1) | ✅ `IBreathSessionDao.getSessions({int? limit, int? offset})` exists; `BreathSessionRepository` never calls it (uses `_api.fetchPage`). `BreathSession` imported (line 6) |
| `BreathSessionNotifierEvent` is sealed; add `LocalSessionsLoaded` (Task 2) | ✅ `sealed class BreathSessionNotifierEvent {}`. No **exhaustive** switch over it exists anywhere (only `if (event is SessionsInvalidated)` in the service), so adding a subtype compiles cleanly |
| `invalidate()` currently emits empty `entries` + `SessionsInvalidated` (Task 3) | ✅ lines 104–110 match exactly |
| `currentUserId` is `String Function()` usable in the helper (Task 3) | ✅ field at line 78, called as `currentUserId()` in `load`/`refresh` |
| `_onUserIdChanged → deleteAll() → invalidate()` ordering (Task 3) | ✅ lines 99–102; `deleteAll()` is awaited before `invalidate()` |
| App.dart line 176 constructs `breathSessionNotifier`, 177 `syncEngine` (Task 4) | ✅ exact match; `userNotifier` already exists (line 175) so `currentUserId()` resolves at seed time |
| Both `invalidate()` callers are fire-and-forget (Task 3 / async safety) | ✅ `SyncEngine` lines 120 (`_processEvents` delta) and 126 (`_handleFullResync`), plus `_onUserIdChanged` line 101 — none await; making it `Future<void>` is safe |
| Test fake at line 17 `implements IBreathSessionRepository` (Task 5) | ✅ adding to the interface forces the override; plan's `localSessions() async => List.of(_sessions)` is correct |
| Test assertion at line 546–557 expects `SessionsInvalidated` (Task 5) | ✅ line 557 `isA<SessionsInvalidated>()`; `entries isEmpty` (555) and `nextCursor isNull` (556) hold after the fix because the fetched single session yields `nextCursor == null` and `deleteAll` empties `_sessions` |
| `currentItems()` reads `notifier.currentState.entries` (Task 6) | ✅ service line 47–48 |
| `observeChanges()` maps non-`SessionsInvalidated` events to `ListUpdatedEvent` (Task 6) | ✅ service lines 21–31 — `LocalSessionsLoaded` falls into the "all other events" branch |
| ViewModel `build()` reads `currentItems()` synchronously, skeleton otherwise (Task 6) | ✅ VM lines 30–50 |

## Behavioral reasoning confirmed correct

- **Empty-seed-no-emit vs. invalidate-always-emit asymmetry** is sound. On empty Drift, `loadLocal()` not emitting leaves the seeded state at `lastEvent: null`; `observeChanges()`'s `if (event == null) return const []` (service line 19) means the BehaviorSubject replay produces no event, so the ViewModel's `initialLoading` skeleton holds until the background `_loadInitialPage()`. Verified against both the service and VM.
- **Non-empty seed replay path** works: the seeded state carries `lastEvent: LocalSessionsLoaded`, BehaviorSubject replays it to the VM's new subscription → `ListUpdatedEvent` → `_handleListUpdated`. This is redundant with `build()`'s synchronous `currentItems()` read but harmless (same data).
- **Dead `SessionsInvalidated` branch** reasoning holds: after Task 3, nothing emits `SessionsInvalidated`, so the service's special-case (lines 21–23), `SessionsInvalidatedEvent`, and the VM's `_handleSessionsInvalidated()` become unreachable. The plan correctly chooses to leave them in place.
- **Async timing in the privacy-wipe test** is safe: `_onUserIdChanged` now chains two microtask awaits (`deleteAll` → `invalidate`'s `localSessions`), but the test's `await Future.delayed(Duration.zero)` is a timer (macrotask) that fires only after the microtask queue drains, so the emission is observed before the assertions.

## Context Gates

- **ARCHITECTURE.md** — No boundary violation. The plan keeps the layering intact: the Drift read stays inside `BreathSessionRepository`, the notifier owns domain state, the service remains a stateless `notifier.stream.expand(...)` derivation, and no domain model crosses into the package (DTOs unchanged). `WARN`: none.
- **RULES.md** — `WARN` (non-blocking). Rule: *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only."* Task 4 adds `await breathSessionNotifier.loadLocal();` to `App.initialize()`. This adds **no** stream/subscription/state — it is a one-shot awaited init call that mirrors the already-accepted `await syncEngine.waitForColdStart(...)` (line 178) and `await appSettingsRepository.init()` (line 196), both of which warm notifier/repository state at init. The plan explicitly justifies why a constructor can't satisfy "warm before build" (constructors can't await). Consistent with the rule's intent and existing precedent; flagged only for awareness, not a blocker. The companion rule (line 7 — stateless services) is **upheld**: no service changes.
- **ROADMAP.md** — Not re-derived here; the plan is sequenced against notes 100/131/133 and an explicit interim-behavior decision, which is the appropriate linkage for this milestone.

## Critical Issues

None.

## Minor Observations (non-blocking)

1. **Task 1 ordering claim is cosmetic.** The plan says `localSessions()` returns rows "ordered `createdAt` DESC." Whatever order `_dao.getSessions()` returns is irrelevant to correctness — `buildSectionedEntries` (notifier lines 39–43) re-sorts by `createdAt` DESC with an `id` tie-breaker before building entries. No action needed; just don't rely on DAO order for any guarantee.
2. **Pre-existing (not introduced) cross-user cache note.** `getSessions()` has no `userId` filter, so `loadLocal()` renders whatever rows Drift holds, tagged mine/shared by the *current* user. This is safe in practice because logout/user-switch runs `deleteAll()` first, and the same unfiltered-cache assumption already governs `getById`/`fetchById`. The plan's privacy-wipe ordering (`deleteAll()` awaited before the now-async `invalidate()` re-reads) preserves the existing guarantee. No new exposure; noted for completeness.
3. **Empty-state vs. skeleton on a *mounted* user switch.** With the `SessionsInvalidated` path retired, if the list were ever mounted during a user switch, `invalidate()` → `LocalSessionsLoaded` (empty) → `ListUpdatedEvent(items: [])` would drive the VM to the `empty` mode (VM lines 76–81) rather than the old skeleton+reload. The plan's Design note 15 correctly argues this path isn't reachable with the list mounted (user switch happens at login). Accurate given the current navigation; worth keeping in mind if that invariant ever changes.

## Positive Notes

- Exceptionally thorough design notes: the seed/invalidate empty-case asymmetry, the transient `hasMore` oscillation, the content(N)→content(50) shrink, the retired `SessionsInvalidated` branch, and the preserved-cursor edge case are each identified, reasoned about, and explicitly scoped in or out — every one checks out against the code.
- Correct dependency ordering across the 6 tasks (interface → event → notifier → wiring → tests → verify), and Task 5 keeps the existing suite green rather than leaving a broken compile.
- Scope discipline: the plan resists fixing the content-shrink here and correctly defers it to note 133, keeping this milestone to "add the Drift read path" only.

PLAN_REVIEW_PASS
