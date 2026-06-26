# Plan Review 2: Re-point Android FGS keep-alive to the local signal (offline fix)

## Code Review Summary

**Files Reviewed:** 5 (plan + `BreathSessionViewModel.dart`, `KeepAliveCoordinator.dart`, `BreathModule.dart`, `BreathSessionState.dart`, `ForegroundKeepAlive.dart`) + `App.dart` / `BreathActivityHarness.dart` cross-checks + review-1 diff
**Risk Level:** 🟢 Low — the single blocking defect from review 1 is fixed; all instructions now compile and match the codebase.

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** ✅ Aligned. The `bool` callback keeps `packages/breath_module` unaware of the FGS; the FGS coupling is wired only at the app assembly point (`lib/BreathModule/BreathModule.dart`). Domain → module boundary respected, no domain leakage into the package.
- **Rules (`.ai-factory/RULES.md`):** ✅ Clear. No module-specific state added to `App.dart` (Task 3 reuses the existing `keepAliveCoordinator` field). The new `onIsLiveChanged` callback follows the existing `attachModuleChannel(onDispose:, onReset:)` injection precedent exactly — the VM only invokes a callback, it does not externally wire another object.
- **Roadmap (`.ai-factory/ROADMAP.md`):** ✅ Linked. Maps 1:1 to the open Phase 58 milestone and correctly inherits its constraints (biometrics stay server-gated, meditation FGS parity deferred, no auto-`pause()` reintroduced).

### Resolution of Review-1 Blocking Issue

Review 1's only blocking item was that Task 2 instructed assigning `final bool _isAndroid` "before the early return" in the constructor **body**, which is a Dart compile error. The revised plan (Task 2, lines 37–48) now assigns `_isAndroid` in the **initializer list**:

```dart
})  : _foregroundKeepAlive = foregroundKeepAlive,
      _isAndroid = isAndroid() {          // initializer list, not body
  if (!_isAndroid) return;
  _subscription = moduleStateEvents.listen(_onEvent);
}
```

This compiles, keeps the field `final`, and reuses `_isAndroid` in both the constructor guard and the new `onLocalLifecycle` guard. The defect is fully resolved.

### Critical Issues

None.

### Verification of remaining claims (all confirmed against source)

- `set state` funnel at `BreathSessionViewModel.dart:108–115` — both `_setupEngine` and `_onEngineState` route through it; `lifecycle` is part of `equalsIgnoringTickFields`, and the edge check is placed *after* the publication body so it fires independent of the Riverpod-skip optimization. Correct.
- `_lastIsLive = false` initial value matches `BreathLifecycle.notStarted` (`isLive == false`, `BreathSessionState.dart:56–58, 78`) — no spurious `true` edge on session open.
- No double-fire on `complete()` → dispose: `complete` drives a `true→false` setter edge that sets `_lastIsLive = false`, so the `ref.onDispose` guard (`:78–88`) then sees `false` and does not re-fire. The guard only fires for "navigate away while still live." Correct.
- `ForegroundKeepAlive.start()/stop()` are idempotent via `_wantRunning`/`_running` and no-op off Android (`ForegroundKeepAlive.dart:31–32, 82–83`), so the online double-driver (server + local paths) is harmless, as stated.
- Backward compatibility: only two `attachModuleChannel` callers exist — `BreathModule.dart:54` (updated by Task 3) and `BreathActivityHarness.dart:113` (untouched). Making `onIsLiveChanged` optional/`null`-default keeps the harness compiling. Confirmed by grep.
- `App.shared.keepAliveCoordinator` exists as a field (`App.dart:112`) and is constructed at `:233` — no `App.dart` change required, as Task 3 states.

### Minor Notes (non-blocking, no change required)

- `onLocalLifecycle` returns `Future<void>` assigned to a `void Function(bool)` field — legal in Dart; the returned future is fire-and-forget, so errors are swallowed at the call site. Acceptable and consistent with the existing `onDispose`/`onReset` style; `ForegroundKeepAlive` logs internally and reconciles rapid toggles.
- The `_isAndroid` guard inside `onLocalLifecycle` is genuinely needed (not redundant with the constructor guard): the local callback is wired in `BreathModule.buildSession` on every platform, whereas the server-event `_subscription` is skipped off Android. The plan keeps this field for exactly that reason — correct.

### Positive Notes

- The dispose guard closes the orphan-FGS gap for "navigate away while running/paused," a case no state edge would otherwise cover — caught and reasoned correctly.
- Scope discipline is excellent: biometrics untouched, meditation server path retained, no auto-`pause()`, single-commit constraint — all consistent with the roadmap milestone.
- All file paths, line references, and field/method names in the plan check out against current source.

### Verdict

The blocking issue from review 1 is fixed, and every remaining instruction compiles and matches the codebase. The plan is architecturally sound, well-scoped, and accurate. Ready to implement.

PLAN_REVIEW_PASS
