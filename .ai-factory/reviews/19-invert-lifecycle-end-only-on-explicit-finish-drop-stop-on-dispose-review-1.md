# Code Review: Invert lifecycle: end only on explicit finish (drop stop-on-dispose)

**Reviewed:** `git diff HEAD` — 2 adapters + 2 test suites (plan/JSON artifacts excluded from code review).
**Risk:** 🟢 Low. Pure deletion of two implicit-teardown `stop()` calls; no new code paths.

## Scope of change

- `lib/BreathModule/Core/BreathModuleStateChannel.dart` — `dispose()` no longer sends `_channel.stop(...)`; only cancels the three subscriptions.
- `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` — same: `dispose()` drops the `stop()` line, keeps subscription cancellation.
- `test/BreathModule/breath_module_state_channel_test.dart` — the two `breath -> dispose` / `breath -> pause -> dispose` cases flipped to `stopCount == 0` with renamed descriptions.
- `test/MeditationModule/meditation_module_state_channel_test.dart` — the `active -> dispose` case flipped to `stopCount == 0` with renamed description.

## Correctness verification

- **No dangling references after removal.** In `BreathModuleStateChannel`, `logPrint` (used at `:73`, `:91`, `:105`, …), `_childSessionId` (used in `unpause`/`pause`/`end`), and `_started`/`_ended` remain live. In `MeditationModuleStateChannel`, `_childSessionId` is still used by the `end` path (`:63`). No import becomes unused; nothing fails to compile.
- **Explicit-finish `end` paths preserved.** Breath `→completed` (`:117-123`) and meditation `active → idle` (`:62-69`) are untouched and remain the sole terminators — matching the spec's "end only on explicit finish" guard.
- **Subscription teardown intact.** All three `.cancel()` calls remain in both `dispose()` bodies, so navigating away still tears down the local listeners (no stream leak); only the wire-level `stop` is dropped. The post-dispose "no further dispatch" and "moduleSessionId frozen" tests still pass, confirming this.
- **No other implicit teardown paths.** Independently reconfirmed the navigation-path audit: a `.stop(`/`.end(` sweep over `lib/BreathModule` + `lib/MeditationModule` + `ModuleStateChannel` surfaces only the two (now-removed) dispose calls plus the two explicit-finish `end` calls. No coordinator, screen pop, or route change sends `end`/`stop` independently.
- **Test suite integrity.** No orphaned `stopCount, 1` assertions remain in either file; every `stopCount` assertion now expects `0`, and the fakes still define `stop`. Ran both suites: **90 tests pass**.

## Out-of-scope observations (no action — informational)

- After this change, `ModuleStateChannel.stop()` has no remaining production caller. Expected and harmless — it is a legitimate public wire method the spec does not ask to remove; leaving it is correct.
- A never-finished child (start breath, walk away, never finish) now stays live server-side. This is the deliberate consequence of the inversion, handled by the registry + reconnect/eviction milestones (Phase 64), not here. Correctly out of scope.
- Pre-existing (not introduced here): in `MeditationModuleStateChannel`, `_ended` is only ever set to `false`, never `true`, so `&& !_ended` guards are effectively always-true. Benign and unrelated to this change.

No correctness, security, or runtime-break findings.

REVIEW_PASS
