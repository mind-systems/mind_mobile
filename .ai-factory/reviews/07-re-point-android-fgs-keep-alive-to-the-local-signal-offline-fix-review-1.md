# Code Review: Re-point Android FGS keep-alive to the local signal (offline fix)

## Summary

**Files changed:** 3 source files
- `lib/Core/Background/KeepAliveCoordinator.dart` — added `_isAndroid` field + `onLocalLifecycle(bool)` method
- `lib/BreathModule/BreathModule.dart` — wired `onIsLiveChanged` callback in `buildSession`
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` — added `onIsLiveChanged` param, edge detection in `set state`, dispose guard

**Risk Level:** 🟢 Low — implementation matches the approved plan 1:1; `flutter analyze` clean on all three files; no bugs found.

## Verification

### Compilation
- `flutter analyze` on all three changed files: **No issues found.**
- `onLocalLifecycle` returns `Future<void>` and is assigned (via tearoff) to the `void Function(bool)?` param — legal in Dart (a `void`-typed function target accepts any return type). The returned future is fire-and-forget, consistent with the existing `onDispose`/`onReset` style.
- `_isAndroid` is correctly assigned in the **initializer list** (`KeepAliveCoordinator.dart:21-22`), resolving the only blocking item from plan-review-1. The existing constructor guard and the new `onLocalLifecycle` guard both reuse it. The field is genuinely needed: the local callback is wired on every platform in `buildSession`, whereas the server `_subscription` is skipped off Android.

### Edge-detection correctness (`set state`, `BreathSessionViewModel.dart:116-128`)
- Placed at the single publication funnel after the body, so it fires independent of the Riverpod-skip optimization. Both `_setupEngine` and `_onEngineState` route through `set state`; `lifecycle` is part of `equalsIgnoringTickFields`, so a lifecycle change always reaches here.
- Tick-only updates leave `isLive` unchanged → `next == _lastIsLive` → no edge. Verified.
- `toggleStar` / `initState` error-branch emit `copyWith` updates that do not change `lifecycle` → no spurious edge. Verified.
- `_lastIsLive = false` initial value matches `BreathLifecycle.notStarted` (`isLive == false`), so opening a session (first `_setupEngine` emit = `notStarted`) produces no spurious `true` edge → FGS does **not** start until the session is actually resumed. Confirmed against `BreathSessionState.dart:56-58, 78`.

### Lifecycle transitions traced
- **Resume** → `running` → edge `false→true` → `onLocalLifecycle(true)` → FGS start. ✅
- **Manual pause** → `paused` (still `isLive == true`) → no edge → FGS stays up (keep-alive-through-pause contract honored, no auto-`pause()` reintroduced). ✅
- **Complete** → `completed` (`isLive == false`) → edge `true→false` → FGS stop; `_lastIsLive = false`, so the dispose guard then sees `false` and does not double-fire. ✅
- **Restart** (`restartEngine` → `_setupEngine` → `notStarted`) from a live state → edge `true→false` → stop, then a later resume restarts. ✅
- **Navigate away while live** → no terminal state edge, but the `ref.onDispose` guard (`:83-86`) fires `_onIsLiveChanged?.call(false)` when `_lastIsLive` is true → no orphan FGS. ✅

### Wiring & scope
- `App.shared.keepAliveCoordinator.onLocalLifecycle` tearoff — `keepAliveCoordinator` is a real field on `App.shared`; no `App.dart` change required (correctly avoided). ✅
- `onIsLiveChanged` is optional/null-default, so the untouched `BreathActivityHarness.dart:113` caller still compiles. ✅
- Server-event path (`_onEvent`) retained unchanged — meditation FGS keep-alive preserved (parity deferred). Biometrics (`BiometricStreamClient`) untouched, still server-gated. ✅

## Observations (non-blocking, no change required)

- **Online breath now has two FGS drivers (server `_onEvent` + local `onLocalLifecycle`).** `ForegroundKeepAlive.start()/stop()` are idempotent via `_wantRunning`/`_running`, so redundant start/stop is harmless. The one theoretical divergence — a mid-session server `Abandoned`/`Ended` stopping the FGS while the local session is still live — is **pre-existing** behavior (the server path drove everything before this change) and only affects the *online* case, not the offline freeze this milestone targets. Not a regression; out of scope. Worth keeping in mind if meditation/breath FGS are later unified.
- **`_lastIsLive` is only updated inside the callback-guarded block.** If a state were ever emitted before `attachModuleChannel` wired the callback, `_lastIsLive` would not track and a later edge could be missed. This cannot occur with the current wiring (the callback is attached synchronously in the provider factory before `initState`/any emit), so it is safe as written.

## Verdict

The change is correct, minimal, well-scoped, and compiles cleanly. All lifecycle transitions and the orphan-FGS dispose guard behave as specified. No bugs, security issues, or correctness problems found.

REVIEW_PASS
