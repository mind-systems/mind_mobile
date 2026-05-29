# Plan Review: Mute button + orb-tap screen blackout on BreathSessionScreen

**Plan:** `.ai-factory/plans/62-mute-button-orb-tap-screen-blackout-on-breathsessionscreen.md`
**Spec source:** `.ai-factory/notes/25-breath-session-gold-theme-controls.md` (Milestone B)
**Files Reviewed:** 4 (`BreathSoundCoordinator.dart`, `EclipseOrb.dart`, `SessionBottomBar.dart`, `BreathSessionScreen.dart`)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture:** OK — all changes stay inside `packages/breath_module/` (the presentation module). No new domain coupling. `BreathSoundCoordinator` is already inside the module and owns its own lifecycle; adding a `ValueNotifier<bool> isMuted` does not cross the module boundary. `RULES.md` "Module Services must be stateless" rule does not apply — `BreathSoundCoordinator` is a Coordinator, not a Service.
- **Rules:** OK — no module-specific state added to `App.dart`; coordinator state stays in the coordinator; mute is exposed via a `ValueNotifier`, not via App-level wiring.
- **Roadmap:** WARN — plan does not link to a ROADMAP.md milestone. Likely belongs under the "Breath session gold theme + controls" feature implied by note #25. Non-blocking.

## Critical Issues

None — the plan is implementable as-is. The concerns below should be addressed during implementation but do not block plan approval.

## Concerns (Should Address During Implementation)

### 1. Task 2: Tension between "wrap audio side effects" and "keep state tracking unconditional"

The task says:
> keep state tracking (`_currentStatus`, `_currentPhase`, `_currentTickSource`, tick-source asset reload) running unconditionally, but skip audio side effects when `isMuted.value == true`: wrap the section that issues `_looper.fadeOut / _looper.crossfadeTo / _looper.fadeIn` in the status-change block (step 3) and the phase-change block (step 4) with `if (!isMuted.value) { ... }`.

The literal "wrap the whole switch/if-else" reading conflicts with the "keep `_currentPhase` updated" requirement, because `_currentPhase = state.phase;` lives **inside** the `case BreathSessionStatus.breath` audio branch in the current code (`BreathSoundCoordinator.dart:165-166`):

```dart
case BreathSessionStatus.breath:
  if (_phaseAssets.containsKey(state.phase) && state.phase != _currentPhase) {
    _currentPhase = state.phase;        // ← state tracking
    final fadeDuration = _computeFadeDuration(state);
    ...
    _looper.crossfadeTo(...);           // ← audio side effect
  } else {
    _looper.fadeIn(...);                // ← audio side effect
  }
```

If the implementer literally wraps the whole `switch` body in `if (!isMuted.value)`, the `_currentPhase` assignment is skipped while muted. Then, on unmute, the `toggleMute()` resume path:
```dart
if (_currentStatus == BreathSessionStatus.breath &&
    _currentPhase != null &&
    _phaseAssets.containsKey(_currentPhase)) {
  _looper.crossfadeTo(_phaseOrder.indexOf(_currentPhase!), ...);
}
```
would crossfade to a **stale** phase that was current at the moment of muting — not the actual current phase.

The phase-change block (step 4) is safer because `_currentPhase = state.phase;` is already outside the inner `if (_phaseAssets.containsKey(...))` audio branch — wrapping just the inner if/else is unambiguous there.

**Recommended fix in plan or during implementation:** Explicitly call out in Task 2 that `_currentPhase = state.phase;` must be hoisted out of the audio-guarded section in the `case BreathSessionStatus.breath` branch, e.g.:
```dart
case BreathSessionStatus.breath:
  final newPhase = _phaseAssets.containsKey(state.phase) && state.phase != _currentPhase
      ? state.phase
      : _currentPhase;
  _currentPhase = newPhase;
  if (!isMuted.value) {
    if (_phaseAssets.containsKey(state.phase) && state.phase != newPhase /* prev */) {
      ...
    } else {
      _looper.fadeIn(...);
    }
  }
```
Or restructure however the implementer prefers — the rule is "track always, audio only when not muted."

### 2. Task 1: `toggleMute()` may race with `_initAudio()`

If the user taps the mute button before `_initAudio()` finishes (i.e. before the looper has been initialized with sources), `_looper.fadeOut(...)` runs against an uninitialised `AudioLooper`. The existing `_onStateChanged` is gated by `state.loadState != SessionLoadState.ready`, but `toggleMute()` has no equivalent guard.

In practice this is unlikely (audio init usually completes before the user can tap), but consider either:
- Disabling the mute IconButton until `loadState == ready` (would need wiring); or
- Guarding `toggleMute()` with `if (!_isInitialized) { isMuted.value = !isMuted.value; return; }` so the flag toggles but no audio call is made.

Non-blocking — list as a "nice to verify."

### 3. Task 4: Nested `Row`s inside outer `Row` — verify cross-axis layout

The proposed layout:
```dart
Row(
  children: [
    Row(spacing: 8, children: leadingActions),
    const Spacer(),
    Row(spacing: 8, children: trailingActions),
  ],
)
```
Inner `Row`s default to `mainAxisSize: MainAxisSize.max`. When the outer `Row` lays out non-flex children with loose constraints, Flutter handles unbounded `mainAxisSize.max` by falling back to `allocatedSize` (children's intrinsic widths), so this typically works in practice **as long as none of the inner Row's children themselves use Expanded/Flexible**. Currently both rows hold only `IconButton` and (conditionally) a `ValueListenableBuilder<bool>` returning an `IconButton`, all with finite intrinsic widths — so the layout will work.

If future inner-row children include Expanded/Flexible, the layout will throw an "unbounded width" error. Consider adding `mainAxisSize: MainAxisSize.min` to both inner `Row`s defensively — it costs nothing and removes the fragility. Worth a one-line note in Task 4.

### 4. Task 5: Blackout opacity-fade subtleties

- `AnimatedOpacity` with `opacity: 0.0` keeps the child in the widget tree; the `IgnorePointer(ignoring: !_isBlackedOut, ...)` correctly suppresses taps in the off state. ✓
- Fade-out direction: when the user taps the black overlay, `_isBlackedOut` flips to `false`, `IgnorePointer.ignoring` becomes `true` immediately, and the overlay fades from 1.0 → 0.0 over 300 ms. During the fade-out the user can't dismiss again (already dismissed) and can't interact with the orb visually-occluded behind a semi-transparent black layer for 300 ms. Acceptable per spec.
- On iOS the status-bar tap-to-scroll area sits above the Scaffold body. The blackout `SizedBox.expand()` only fills the `Stack`'s constraint, which is the Scaffold body — i.e. it covers everything except the system status bar. That matches the spec ("blackout the screen"), but worth confirming with the user; if they want the status bar dimmed too, you'd need `SystemChrome.setSystemUIOverlayStyle` or a transparent status bar with `extendBody`.

Non-blocking — spec doesn't mention system UI.

### 5. Disposal order in `BreathSoundCoordinator.dispose()`

Task 1 says to dispose `isMuted` "after the existing cleanup." The existing `dispose()` calls `_looper.dispose()` and `_oneShot.dispose()` last. Disposing `isMuted` after them is fine because no listener should remain attached (the screen's `ValueListenableBuilder` widget is disposed when the screen is removed, which happens before the coordinator is disposed via the `_BreathSessionScreenState.dispose()` order). Just make sure the line is added.

## Positive Notes

- **Scope is tight and atomic.** Six tasks, three commits, no new packages, no dependency wiring in `App.dart`. The plan correctly identifies that `_soundCoordinator` is already constructed at the screen level (`BreathSessionScreen.dart:67-72`) and reused for the mute toggle.
- **No domain leakage.** Mute is a pure presentation concern — exposing it via `ValueNotifier<bool>` on the coordinator (rather than threading it through the ViewModel/Service interface) is the right call because it doesn't change session DTOs or domain state.
- **`EclipseOrb` change is correctly additive.** `onTap` is optional with a `?.call()` so existing call sites and the `pulse()` behavior are preserved.
- **`SessionBottomBar` rename is mechanical and locally contained.** The only caller is `BreathSessionScreen`, which is updated in Task 6 — no other file uses `actions:`. (Verified via current `SessionBottomBar.dart` having only the one parameter; the codebase has a single caller.)
- **Theme color usage is correct.** `cs.tertiary` for the active mute icon and `Colors.white.withValues(alpha: 0.3)` for muted state match the rest of the bar's iconography (consistent with the gold-theme milestone).
- **Sound coordinator's existing invariants are respected.** Plan leaves `_isSuspended`, `_currentTickSource`, init order untouched; mute is layered on top rather than replacing existing logic.
- **Dispose / setState safety.** `_isBlackedOut` is plain widget state — no async race against dispose because all mutations happen inside synchronous `GestureDetector.onTap` callbacks.

## Summary

The plan is solid and faithfully implements Milestone B of note #25. The single concern that warrants a clarifying edit is **Task 2's ambiguity around `_currentPhase` tracking inside the status-change `breath` case** — the plan's prose says "track unconditionally" but the literal wrap-instruction would skip the assignment. Calling that out explicitly in Task 2 would prevent a subtle unmute-to-stale-phase bug. The other items (toggleMute race, nested Row defensiveness, status-bar coverage) are non-blocking polish.

PLAN_REVIEW_PASS
