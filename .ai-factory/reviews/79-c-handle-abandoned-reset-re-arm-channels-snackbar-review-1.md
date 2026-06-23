# Code Review: C — Handle `ABANDONED`: reset + re-arm channels + snackbar

**Scope:** `git diff HEAD` — 5 source files + 3 generated l10n files + 2 test files (+ plan artifacts).
**Verification:** `flutter analyze` on all 5 changed source files → *No issues found*. `flutter test` on both affected suites → *76/76 passed*.
**Verdict:** Correct, faithful to the plan, compiles and the existing tests pass. No blocking findings. A few non-blocking observations below.

## What was checked

- **Task 1 — `BreathModuleStateChannel`** (`:45-47`, `:162`): additive `_eventsSub = channel.events.listen(...)`, calls the previously-uncalled `reset()` on `ModuleSessionAbandoned`, cancelled in `dispose()`. The existing `channel.state` sub is untouched. Import added. ✅
- **Task 2 — `MeditationModuleStateChannel`** (`:32-39`, `:65`): same additive `_eventsSub`, inline re-arm (`_started/_ended/_moduleSessionId/_previousStatus`), cancelled in `dispose()`, stale comment corrected to `:137-148`. ✅
- **Task 3 — `ModuleStateChannel` `no_active_session`** (`:94-96`): in the `sessionError` branch, on the literal `'no_active_session'` it adds `ModuleState.initial()` to `_state` only — emits no event, no snackbar; `logPrint` retained; other codes stay log-only. ✅
- **Task 4 — `GlobalListeners`**: new `sessionAbandonedStream` field + required ctor arg, `_sessionAbandonedSubscription` subscribed in `initState` / cancelled in `dispose`, `_sessionAbandonedMessage()` mirrors the expiry helper (incl. `context.mounted` guard and fallback), doc comment updated. ✅
- **Task 5 — `App.dart`** (`:312`): wires `moduleStateChannel.events.where((e) => e is ModuleSessionAbandoned).map((_) {})`; `ModuleStateEvent` imported. ✅
- **Task 6 — l10n**: abstract getter + en/ru overrides generated in the correct ARB position; matches `app_en.arb`/`app_ru.arb`. ✅

### Runtime-correctness checks (no defects found)

- **Broadcast fan-out is safe.** `_events` is an rxdart `PublishSubject` (broadcast), already consumed by `BiometricStreamClient`, `KeepAliveCoordinator`, and `HomeService`. The two new per-session subscriptions plus the App-level snackbar subscription are all independent broadcast listeners — no "stream already listened to" risk.
- **Event ordering on ABANDONED is harmless.** `_processProtoEvent` adds `ModuleState.initial()` then `ModuleSessionAbandoned`. Whether the state-listener (nulls `moduleSessionId`, no flush) or the events-listener (`reset()`) runs first, the end state is identical — fully re-armed. No race.
- **Single snackbar.** Only the App-level subscription shows UI; the silent `no_active_session` path emits nothing. No double-snackbar.
- **`.map((_) {})` typing.** Resolves to `Stream<void>` via the assignment context — compiles, confirmed by analyzer.
- **No other construction sites break.** The only `GlobalListeners(...)` call is in `App.dart` (updated); the only `ModuleStateChannel` fakes are the two test files (updated `events` getter + `start`/`end` optional-param signatures, backed by `noSuchMethod`).

## Non-blocking observations (no change required)

1. **No automated coverage of the new abandonment paths.** The plan declared `Testing: no`, and the test edits are compile-only (adding the `events` getter and aligning `start`/`end` signatures). Given both channels otherwise have dense lifecycle/reset suites, a future follow-up could add: (a) Breath — emit `ModuleSessionAbandoned` on `eventsController`, then assert the next `breath` emission calls `start` (not `unpause`); (b) Meditation — same, asserting re-arm. Worth noting so the gap is intentional rather than forgotten.

2. **`no_active_session` reset is partial by design.** It resets only `ModuleStateChannel._state`; because it emits no event, the module channels' `_started`/`_ended` latches are not cleared. If a session were genuinely mid-flight when this rejection arrives, the Breath channel could buffer a phase change into `_pendingInstruction` against a now-null session id. This matches the plan's stated intent (rare defensive command-rejection, stale-view reconciliation) and is acceptable. Also note `_isPendingPause`/`_isPendingStart` are not cleared here, but the `pause()`/`start()` guards key off `currentState.status` which is now `idle`, so no command is wrongly suppressed.

3. **`ModuleSessionAbandoned` carries no module identity.** The re-arm fires unconditionally for whichever module channel is alive. This is correct under the single-active-session invariant (one shared `ModuleStateChannel`, one session screen at a time) and `reset()` is idempotent when no session exists — flagged only for awareness if concurrent module sessions ever become possible.

4. **`GlobalListeners` is rebuilt on settings change.** `MyApp.build` re-evaluates the `builder`, creating a fresh `.where().map()` stream each time, but `GlobalListeners` State persists (no key) so `initState` runs once and only the first stream is ever `.listen()`-ed. Lazy transformed streams don't subscribe upstream until listened, so the discarded ones leak nothing. This is identical to the pre-existing `sessionExpiredStream` behaviour — no regression.

REVIEW_PASS
