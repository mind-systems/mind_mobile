# Plan Review: Render the list from Drift (offline-first cold start; invalidate() re-reads Drift)

**Plan:** `66-render-the-list-from-drift-offline-first-cold-start-invalidate-re-reads-drift.md`
**Files inspected:** 11 (plan + notifier, repository + interface, DAO + interface, event model, list service, ViewModel, App.dart, SyncEngine, notifier test)
**Risk Level:** 🟡 Medium

The plan is well-scoped and the file paths, line references, and API names are accurate. `_dao.getSessions()` exists and already returns `createdAt DESC` (no `limit`/`offset` returns the full set), `buildSectionedEntries(sessions, currentUserId())` has the claimed signature, `BreathSession` is imported in both repository files, App.dart line 176 is indeed the `breathSessionNotifier` construction immediately before `syncEngine`, and `observeChanges()` does route every non-`SessionsInvalidated` event to `ListUpdatedEvent`. The core mechanism is sound. There are, however, two real gaps the plan does not address.

## Context Gates

- **Architecture (WARN):** No direct boundary violation. The Service-stays-stateless rule (`RULES.md`) is respected — `observeChanges()` keeps using `notifier.stream.expand(...)` and no new Service state is introduced.
- **Rules (WARN):** Task 4 calls `breathSessionNotifier.loadLocal()` from inside `App.initialize()`. This brushes against two `RULES.md` items: "Never add module-specific … triggers to App.dart" and "Never wire a class from the outside by calling its methods … let the class manage [it] itself." The pragmatic counter-argument is that an *awaited one-shot seed* is the only way to guarantee `currentState.entries` is warm before the first screen builds, and it mirrors the existing `await syncEngine.waitForColdStart(...)` / `await appSettingsRepository.init()` init steps already in `initialize()`. Acceptable as-is, but the implementer should be conscious it is an external-wiring call, not a constructor-managed one. Self-seeding in the constructor cannot satisfy the "warm before build" requirement because the constructor can't await.
- **Roadmap (WARN):** This is offline-first work (perf/feat) but there is no corresponding phase/task in `ROADMAP.md`. Consider adding a roadmap entry. Also note the plan intentionally **reverses** the Phase 34 / note 100 decision ("the list must render from cursor API responses; Drift stays write-through for detail/`getById` only"). That is a deliberate design change, not an oversight, but it should be stated explicitly so future readers don't treat it as a regression of note 100.

## Critical Issues

### 1. Existing tests will break — the plan marks Testing: no but does not update them (HIGH)
`test/BreathModule/breath_session_notifier_test.dart` will fail, and not just at the assertion level — it won't compile:

- **Compilation break:** `FakeBreathSessionRepository` (line 17) `implements IBreathSessionRepository`. Adding `Future<List<BreathSession>> localSessions()` to the interface (Task 1) makes the fake an incomplete implementation → the whole test file fails to compile → `flutter test` is red. The plan must include "add `localSessions()` to `FakeBreathSessionRepository`" (it should return its in-memory `_sessions`, so the privacy-wipe assertion still works after `deleteAll()` empties it).
- **Assertion break:** The test at line 546 (`'user id change calls deleteAll and emits empty entries with SessionsInvalidated'`) asserts `notifier.currentState.lastEvent` is `isA<SessionsInvalidated>()` (line 557). After Task 3, `_onUserIdChanged` → `invalidate()` emits `LocalSessionsLoaded`, not `SessionsInvalidated`. This assertion (and the test name) must be updated to `isA<LocalSessionsLoaded>()`. `entries isEmpty` (line 555) and `nextCursor isNull` (line 556) still hold **only if** the fake's `localSessions()` returns the post-`deleteAll` empty list and the helper preserves a null cursor.

Recommendation: add an explicit task to update the fake and the affected assertion. "Testing: no" means *no new test coverage*, but it cannot mean *leave the build broken*.

## Important Issues

### 2. Empty-Drift cold start now flashes the empty state (MEDIUM, partially contradicts the plan's goal)
The plan unifies the seed and the privacy-wipe into one always-emitting `_emitFromLocal()` that emits `LocalSessionsLoaded` even when entries are empty. Trace the fresh-install / guest path **with network available**:

1. `loadLocal()` runs in `initialize()`, Drift empty → emits `BreathSessionsState(entries: [], lastEvent: LocalSessionsLoaded())`.
2. ViewModel `build()` reads `currentItems()` synchronously → empty → returns `initialLoading` skeleton (good).
3. The `BehaviorSubject` replays its latest value to the new subscriber on a microtask → `observeChanges()` maps it to `ListUpdatedEvent(items: [], hasMore: false)` → `_handleListUpdated` sees empty cells → sets `mode: BreathSessionListMode.empty`.
4. The background `_loadInitialPage()` network call resolves seconds later → `ListUpdatedEvent(content)` → content.

Net first-launch sequence becomes **skeleton → empty "no sessions" view → content**, where the empty view lingers for the full network latency. The *current* code avoids this: the initial seeded state has `lastEvent: null`, so `observeChanges()` emits nothing on replay and the skeleton holds until the network corrects. So the plan trades a clean "skeleton → content" for a "skeleton → empty-flash → content" on every fresh/empty-Drift launch — the opposite of the "no shimmer flash" intent for that path.

The tension is real and the plan should resolve it consciously: the **privacy-wipe** path genuinely needs the empty emission (to clear the previous user's rows immediately — a security property), but the **seed** path does not. Options:
- Keep them unified but have the ViewModel not downgrade to `empty` while an initial load is in flight (the ViewModel has no in-flight flag today, so this needs one); or
- Split the empty handling: the *seed* skips emitting when Drift is empty (skeleton holds), while *invalidate* still emits empty. This keeps cross-user privacy correct and avoids the fresh-launch flash. (This means `loadLocal()` and `invalidate()` would not be byte-identical, which contradicts the "extract one shared helper used by both" instruction in Task 3 — so the plan should be explicit about the intended empty-state semantics rather than blindly sharing the helper.)

At minimum, the plan should state which behavior is intended for empty Drift so the implementer doesn't silently introduce the flash.

## Minor Issues / Notes

- **Transient `hasMore` after seed (LOW):** `loadLocal()` preserves the current `nextCursor`, which on first seed is `null` (the initial subject value). `observeChanges()` then computes `hasMore = false` for the replayed seed event, while `build()`'s synchronous branch hard-codes `hasMore: true`. So `hasMore` briefly oscillates true→false until `_loadInitialPage()` corrects it. Self-correcting and already covered by the existing "conservative — background load … corrects it" comment, but worth a sentence in the plan.
- **Duplication is handled correctly (positive):** note 100 warned that Drift's id-keyed cache "can't hold dup ids" (the STARRED duplicate). The Drift read path reconstructs that duplication correctly because `buildSectionedEntries` re-derives the STARRED entry from `session.isStarred`, not from stored duplicate rows. No issue here — just confirming the offline path doesn't lose the STARRED section.
- **SyncEngine behavior change is intended and efficient (positive):** after Task 3, `SyncEngine`'s post-delta `invalidate()` renders directly from the just-saved Drift rows instead of forcing a fresh network page (the old `SessionsInvalidated` → skeleton → `_loadInitialPage` path). This is the explicit goal and is sound, since SyncEngine writes to Drift before calling `invalidate()`.
- **Async `invalidate()` fire-and-forget is safe:** `_onUserIdChanged` awaits `deleteAll()` before the (now-async) `invalidate()` reads `localSessions()`, so the wipe-then-read ordering is preserved even without awaiting `invalidate()` itself.

## Positive Notes

- File paths, line numbers, and API signatures in the plan are all accurate against the codebase.
- The phasing (repository read → event type → notifier seed/invalidate → wiring → verify) and the dependency annotations are correct.
- The privacy-wipe reasoning (deleteAll → empty re-read) is correct and preserves no-cross-user-leak.
- The plan correctly anticipates that `observeChanges()` and the ViewModel need no mapping changes for `LocalSessionsLoaded`.

## Verdict

Two blocking gaps prevent a clean pass: (1) the plan leaves the existing notifier test uncompilable/failing and does not include the required fake + assertion updates, and (2) the seed/invalidate unification silently introduces an empty-state flash on fresh/empty-Drift cold start that contradicts the stated goal and needs an explicit design decision. Address both — at minimum add a task to fix the test fake and the `SessionsInvalidated` assertion, and specify the intended empty-Drift seed behavior — then the plan is ready.
