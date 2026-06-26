# Plan Review: Re-point Android FGS keep-alive to the local signal (offline fix)

## Code Review Summary

**Files Reviewed:** 4 (plan + 3 target source files) + state/state-machine/harness cross-checks
**Risk Level:** 🟡 Medium — one instruction would not compile if followed literally; otherwise sound.

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** ✅ Aligned. The callback bridge keeps `packages/breath_module` unaware of the FGS (it only fires a `bool`), and the FGS coupling is wired at the app assembly point (`lib/BreathModule/BreathModule.dart`). Domain → module boundary respected; no domain leakage into the package.
- **Rules (`.ai-factory/RULES.md`):** ✅ WARN-clear.
  - Rule "Never add module-specific state/streams/triggers to App.dart" — honored. Task 3 explicitly requires **no** `App.dart` change; `keepAliveCoordinator` already exists as a field (`lib/Core/App.dart:112`, constructed `:233`). Confirmed.
  - Rule "all dependencies injected via constructor; never wire a class from the outside by calling its methods on its behalf" — the new `onIsLiveChanged` callback follows the **existing** `attachModuleChannel(onDispose:, onReset:)` precedent exactly (method references passed at the assembly point; the VM only *invokes* a callback, it does not subscribe to anything on another object's behalf). Consistent with established pattern — not a violation.
- **Roadmap (`.ai-factory/ROADMAP.md`):** ✅ Linked. Maps 1:1 to the Phase 58 open milestone "Re-point Android FGS keep-alive to the local signal (offline fix)" (`ROADMAP.md:26`), and correctly inherits its constraints (biometrics stay server-gated; meditation FGS parity deferred; no running-session auto-`pause()`). Spec note `07-breath-fgs-local-keepalive.md` referenced.

### Critical Issues

**1. `final bool _isAndroid` cannot be assigned in the constructor body — must be set in the initializer list (Task 2).**

Task 2 says: *"store the constructor's `isAndroid()` result in a `final bool _isAndroid;` field (set it before the early `return` so it is assigned on all paths)."*

In Dart, a `final` instance field **cannot be assigned inside the constructor body** — it must be initialized in the field declaration or the **initializer list**. Taking "set it before the early `return`" literally (i.e. `_isAndroid = isAndroid();` as the first statement of the body) is a compile error (`'_isAndroid' must be initialized` / final-field-already-initialized). The "assigned on all paths" worry is moot precisely *because* it has to go in the initializer list.

Correct shape:
```dart
KeepAliveCoordinator({
  required ForegroundKeepAlive foregroundKeepAlive,
  required Stream<ModuleStateEvent> moduleStateEvents,
  bool Function() isAndroid = _platformIsAndroid,
})  : _foregroundKeepAlive = foregroundKeepAlive,
      _isAndroid = isAndroid() {          // <-- initializer list, not body
  if (!_isAndroid) return;
  _subscription = moduleStateEvents.listen(_onEvent);
}
```
The implementer should use the initializer list and reuse `_isAndroid` in the existing guard. A non-final field set in the body would also work, but `final` is preferable and is what the plan asks for — so the initializer-list form is the intended fix. Worth correcting in the plan text so the implementer doesn't burn a compile cycle.

### Minor Notes / Observations (non-blocking)

- **Async callback is fire-and-forget — acceptable.** `KeepAliveCoordinator.onLocalLifecycle` returns `Future<void>`; the callback field type is `void Function(bool)`. This is assignable in Dart (target return type `void` accepts any return type), so it compiles, but the returned `Future` is dropped — errors are swallowed at the call site. This is fine here: `ForegroundKeepAlive.start()/stop()` log internally and reconcile rapid toggles via their `_wantRunning`/`_running` flags (a `stop()` arriving mid-`start()` is already guarded). Matches the existing fire-and-forget style of `onDispose`/`onReset`. No change needed; just be aware errors won't surface to the VM.
- **Edge-detection placement is correct.** Putting the edge check in `set state` (`BreathSessionViewModel.dart:107-115`) is the right single funnel — both `_setupEngine` and `_onEngineState` route through it, and `lifecycle` is part of `equalsIgnoringTickFields` so a lifecycle change always publishes. The edge fires unconditionally after the body, independent of whether the Riverpod publication is skipped — so tick-only updates (isLive unchanged) correctly produce no edge. Verified.
- **`_lastIsLive = false` initial value is correct.** First state emitted by `_setupEngine` carries `lifecycle: notStarted` (`isLive == false`), so no spurious `true` edge on session open. Confirmed against `BreathSessionState` defaults (`:78`) and `_lifecycleFor` (`BreathSessionStateMachine.dart:494`).
- **No double-fire on complete→dispose.** `complete()` emits `status: complete` → `_emit` stamps `completed` (`BreathSessionStateMachine.dart:214-222, 507-508`) → setter fires `true→false` and sets `_lastIsLive = false`; the dispose guard then sees `_lastIsLive == false` and does not re-fire. The dispose guard only fires when navigating away while still live (no terminal state edge). Logic verified — matches the plan's stated reasoning.
- **Backward compatibility confirmed.** Only two `attachModuleChannel` call sites exist: `lib/BreathModule/BreathModule.dart:54` (prod, updated by Task 3) and `test/BreathModule/Support/BreathActivityHarness.dart:113` (test). Making `onIsLiveChanged` optional keeps the harness compiling unchanged. Verified by grep.
- **Idempotency claim holds.** `ForegroundKeepAlive.start()/stop()` are guarded by `_wantRunning`/`_running` and early-return off Android, so the online double-driver (server path + local path both firing) is harmless, as the plan states.

### Positive Notes

- File paths, line references, and field/method names in the plan all check out against the actual source (`keepAliveCoordinator` field at `App.dart:112`/`:233`, `set state` at `:107-115`, `ref.onDispose` at `:78-88`, harness at `:113`).
- The dispose guard (Task 1) genuinely closes the orphan-FGS gap for the "navigate away while running/paused" case that no state edge would otherwise cover — a subtle case the plan caught and reasoned through correctly.
- Scope discipline is excellent: biometrics untouched, meditation server path retained, no re-introduction of auto-`pause()`, single-commit constraint — all consistent with the roadmap milestone and superseded-note history.
- The plan correctly identifies the keep-alive-through-manual-pause contract (`isLive` stays `true` on pause) so no spurious stop fires when the user pauses.

### Verdict

The plan is architecturally sound, well-scoped, and accurate about the codebase. The only blocking item is the Task 2 `final`-field-in-body instruction, which will not compile as literally worded — it must use the initializer list. Because that is a real correctness defect in the plan's instructions (not merely stylistic), this review does not pass clean.

Fix Task 2's wording (assign `_isAndroid` in the initializer list) and the plan is ready to implement.
