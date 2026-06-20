# Plan Review 2: Render the list from Drift (offline-first cold start; invalidate() re-reads Drift)

**Plan:** `66-render-the-list-from-drift-offline-first-cold-start-invalidate-re-reads-drift.md`
**Files inspected:** notifier, repository + interface, DAO interface, event model, list service, ViewModel, App.dart, SyncEngine, SyncGrpcListener, notifier test
**Risk Level:** 🟡 Medium

This is the second-pass review. The plan was revised after review-1 and **both blocking issues from review-1 are now resolved**:

1. **Test breakage (was HIGH):** Task 5 now exists and explicitly adds `localSessions()` to `FakeBreathSessionRepository` and updates the line-557 assertion from `isA<SessionsInvalidated>()` to `isA<LocalSessionsLoaded>()`, with the test rename. Verified against the test file: `FakeBreathSessionRepository` (line 17) implements the interface and would otherwise fail to compile; the target test is at line 546–558 exactly as described. ✓
2. **Empty-Drift flash (was MEDIUM):** The "Empty-Drift semantics" design note now resolves this deliberately — `loadLocal()` returns without emitting when Drift is empty (skeleton holds, `lastEvent` stays `null`), while `invalidate()` always emits (privacy wipe + SyncEngine delta). The shared helper computes entries but the two callers differ on the empty case. This matches the ViewModel reality: a replayed `null` `lastEvent` makes `observeChanges()` emit nothing (line 19–20), so the skeleton holds. ✓

File paths, line numbers, and API names re-verified and accurate: `_dao.getSessions()` exists (returns full set, `createdAt DESC`), `buildSectionedEntries(sessions, currentUserId())` signature matches, `BreathSession` imported in both repository files, App.dart line 176 is the notifier construction immediately before `syncEngine`/`waitForColdStart`, and `observeChanges()` routes every non-`SessionsInvalidated` event to `ListUpdatedEvent`.

## Context Gates

- **Architecture (WARN):** No boundary violation. Service stays stateless (`observeChanges()` keeps using `notifier.stream.expand(...)`; no new Service state). Domain layer stays pure Dart.
- **Rules (WARN):** Task 4 calls `breathSessionNotifier.loadLocal()` from inside `App.initialize()`. As review-1 noted, this brushes the "don't wire a class from the outside" / "no module-specific triggers in App.dart" rules, but an awaited one-shot seed is the only way to warm `currentState.entries` before first build, and it mirrors the existing `await syncEngine.waitForColdStart(...)` / `await appSettingsRepository.init()` steps. The plan now documents this rationale explicitly. Acceptable.
- **Roadmap (WARN):** Offline-first (perf/feat) work with no matching `ROADMAP.md` entry. The deliberate reversal of note 100 / Phase 34 is now called out in the Design notes and instructed to be flagged in the commit. Good. Consider adding a roadmap line for traceability.

## Important Issues

### 1. Background `_loadInitialPage()` truncates the full Drift seed to one page — content shrink when Drift holds > `pageSize` rows (MEDIUM, unaddressed)

`localSessions()` returns the **entire** cached set (no `limit`), so `loadLocal()` seeds the list with every row Drift has accumulated from prior pages + SyncEngine deltas. But the ViewModel `build()` always fires `_loadInitialPage()` in the background (line 34), which calls `load(null, pageSize=50)`. In the notifier, the `cursor == null` branch **replaces** the entry set entirely with just the first network page (`sessions = _uniqueSessions(result.entries)`, line 130–131).

So for a user whose Drift cache exceeds 50 sessions (plausible over time — own + shared + accumulated sync deltas), the cold-start sequence becomes **content(N) → content(50)**: the list visibly shrinks from the full cached set to a single page once the background load resolves. The plan's Task 4/Task 6 claim "no shimmer flash for the cached case" — technically true (no skeleton), but it does not acknowledge this content-jump, which is a different and arguably more jarring regression for heavy users.

The plan carves network-refresh rework out to note 133 ("Do not change the network refresh behaviour"), so a fix may be intended there. But this plan ships the Drift seed **without** note 133, so the shrink is live in the interim. At minimum the plan should:
- State explicitly that for Drift > `pageSize` the first network page truncates the seed (content shrink), and
- Confirm this is acceptable until note 133, or sequence note 133 to land together.

## Minor Issues / Notes

- **`invalidate()` retires the `SessionsInvalidated` reload path — branch becomes dead (LOW).** `invalidate()` is the *only* emitter of `SessionsInvalidated` (confirmed by grep). After Task 3 it emits `LocalSessionsLoaded` instead, so `observeChanges()`'s `if (event is SessionsInvalidated)` branch (line 21–22), `SessionsInvalidatedEvent`, and the ViewModel's `_handleSessionsInvalidated()` (skeleton + `_loadInitialPage()`) all become unreachable. The plan says "leave `SessionsInvalidated` in place" but does not note it is now effectively dead. This is intentional (the whole point is to render from Drift rather than force a network reload), and the practical impact is small: the SyncEngine **delta** path — the only `invalidate()` caller that fires while the list is mounted (via `SyncGrpcListener.processEvents` → `_processEvents`, which never reaches `_handleFullResync`) — is strictly improved by rendering Drift rows directly. `_handleFullResync` is only reachable from the REST `sync()` poll (app init / login), when the list is not mounted. So no live regression. Worth one sentence in the plan acknowledging the retired path so a future reader doesn't treat the dead branch as a bug.
- **`invalidate()` now preserves `nextCursor` across the privacy wipe (LOW, benign).** Task 3 emits `nextCursor: _subject.value.nextCursor`; the original `invalidate()` hard-reset it to `null`. On a user switch the previous user's cursor is preserved alongside the (empty) entry list, so `hasMore` could briefly be `true` with zero items. Benign — the list rebuilds fresh on next open (`build()` runs `_loadInitialPage()` with `cursor = null`) and entries are empty so no cross-user leakage. The user-change unit test still passes because that path's cursor is `null` after the single-session load. Mentioning for completeness.
- **Transient `hasMore` after seed (LOW).** Already captured in the plan's Design notes #3 and self-correcting. No action needed.

## Positive Notes

- Both review-1 blockers are genuinely resolved (test fixes in Task 5; empty-Drift seed/invalidate asymmetry resolved in Design notes).
- Privacy-wipe ordering is correct: `_onUserIdChanged` awaits `deleteAll()` before the now-async `invalidate()` reads `localSessions()`, so the re-read returns empty — no cross-user leakage. The fake's `localSessions()` returning post-`deleteAll` `_sessions` preserves this in the test.
- STARRED duplication is reconstructed correctly from `session.isStarred` in `buildSectionedEntries`, not from stored duplicate rows — the offline path does not lose the STARRED section (note 100's concern is handled).
- SyncEngine delta path is strictly improved: rows are written to Drift before `invalidate()`, so re-reading renders the just-saved rows without a skeleton flash or extra network round-trip.
- Phasing and dependency annotations are correct; the note-100 reversal is called out as a deliberate design change.

## Verdict

The two blocking issues from review-1 are fixed and the core mechanism is sound. One unaddressed gap remains — the background first-page load truncates a > `pageSize` Drift seed, producing a content shrink the plan does not acknowledge (Important #1). It is not catastrophic (it self-heals into a valid one-page list and is deferred to note 133), but the plan should explicitly state the intended behavior for the Drift-larger-than-a-page case before implementation, and add a sentence noting the `SessionsInvalidated` reload path is being retired. Add those two acknowledgments and the plan is ready.
