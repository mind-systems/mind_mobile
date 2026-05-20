# Code Review: Expose `remainingTicksNotifier: ValueListenable<int>` on `BreathViewModel`

**Plan:** `.ai-factory/plans/26-expose-remainingticksnotifier-valuelistenable-int-on-breathviewmodel.md`
**Files changed:**
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` (modified)
- `.ai-factory/plans/26-...md` (new, plan)
- `.ai-factory/plan-reviews/26-...md` (new, plan review)

## Scope check

The diff matches the plan exactly:

1. Import `package:flutter/foundation.dart` added between `dart:async` and `flutter_riverpod` (line 2). ✓
2. Private `ValueNotifier<int> _remainingTicks = ValueNotifier<int>(0)` field and public `ValueListenable<int> get remainingTicksNotifier` getter declared near other private fields (lines 36–43). ✓
3. `_remainingTicks.value = initialEngineState.remainingTicks;` placed after `final initialEngineState = ...` and before `state = BreathSessionState(...)` in `_setupEngine` (line 116). ✓
4. `_remainingTicks.value = remaining;` placed after the timeline diff block and before the `state = BreathSessionState(...)` publication in `_onEngineState` (line 156). ✓
5. `_remainingTicks.dispose();` added to the existing `ref.onDispose(...)` block (line 72). ✓

No other code touched. `BreathSessionState.remainingTicks` is preserved (still set in both `_setupEngine` and `_onEngineState`).

## Correctness analysis

### Disposal ordering — safe

The `ref.onDispose` block now reads:
```
_sessionDeletionSubscription?.cancel();
_sessionUpdateSubscription?.cancel();
_stateMachineSubscription?.cancel();   // ← stops _onEngineState callbacks
_stateMachine?.dispose();
_stateController.close();
_remainingTicks.dispose();
tickService.dispose();
```
`_stateMachineSubscription` is cancelled before `_remainingTicks.dispose()`, so no late engine-state callback can write to a disposed notifier. `tickService.dispose()` happens after, but it cannot route through the cancelled subscription. Safe.

### Lifecycle across `_setupEngine` re-entry — correct

`_setupEngine` is invoked on initial load, on `observeSession` DTO updates, and on `restartEngine()`. The notifier instance is created once at class construction and reused on every re-setup — listeners (added by future consumers) stay attached. `_remainingTicks.value = initialEngineState.remainingTicks;` simply re-seeds the channel. No leak, no reattach churn.

### Initial-value coherence — correct

`build()` returns `BreathSessionState.initial()` before `initState()` runs. Seeding `_remainingTicks` with `0` matches that pre-engine state; once `_setupEngine` runs the value is overwritten with the engine's initial `remainingTicks`. No risk of leaking a stale `0` past the load-ready transition because the assignment in `_setupEngine` precedes the `loadState: SessionLoadState.ready` publication on `state`.

### Publication ordering — forward-compatible

Both call sites assign `_remainingTicks.value` **before** the `state = BreathSessionState(...)` write. This means a future short-circuit on the Riverpod publication (milestone 4 in the roadmap, filtering tick-only updates out of `super.state =`) will not starve this channel. The plan called this out explicitly and the implementation honours it.

### Equality semantics — fine

`ValueNotifier<int>.value` setter uses `==` to skip redundant notifications. Integer equality is well-defined; no edge cases.

### No public-API regression

- `BreathSessionState.remainingTicks` still flows through `state`, satisfying coordinators (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`) that read it from the raw `_stateController.stream`.
- The new getter returns a `ValueListenable<int>` (read-only view), so callers cannot mutate the notifier from outside the class.

### Concurrency / threading

All work runs on the main isolate. No new async edges introduced. No race conditions possible.

## Style / quality observations

- Field placement after `_sessionDTO` and before `_stateController` is sensible; the doc comment on the getter is concise and links the rationale note.
- The two `_remainingTicks.value = ...` lines lack inline comments, but the class-level doc comment on the getter already explains the channel's purpose. No comment needed at the call sites.
- No dead code, no orphaned imports.

## Build / analyze

Plan's verification checkbox indicates `flutter analyze` was run and passed. The diff is a pure additive change with imports declared explicitly — no plausible new analyzer warning.

REVIEW_PASS
