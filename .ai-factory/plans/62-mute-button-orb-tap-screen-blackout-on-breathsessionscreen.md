# Plan: Mute button + orb-tap screen blackout on BreathSessionScreen

## Context
Add a mute control to the bottom bar (left side) of `BreathSessionScreen` and a tap-to-blackout overlay triggered by tapping the central orb. Implementation follows the full spec in `.ai-factory/notes/25-breath-session-gold-theme-controls.md` (Milestone B). No new packages, all five touched files already exist.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Audio mute capability

- [x] **Task 1: Add mute state and toggle to BreathSoundCoordinator**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Add a public `final ValueNotifier<bool> isMuted = ValueNotifier(false);` field on `BreathSoundCoordinator`. Add public `void toggleMute()` that flips `isMuted.value`. On transition to muted: call `_looper.fadeOut(const Duration(milliseconds: 300))` and `_oneShot.stop()`. On transition to unmuted: if `_currentStatus == BreathSessionStatus.breath` and `_currentPhase != null` and `_phaseAssets.containsKey(_currentPhase)`, call `_looper.crossfadeTo(_phaseOrder.indexOf(_currentPhase!), const Duration(milliseconds: 300))`. Dispose `isMuted` inside `dispose()` (after the existing cleanup; before `super` is not applicable since `dispose()` here is not a Flutter override).

- [x] **Task 2: Guard audio playback when muted** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `_onTick`, after the existing `if (_isSuspended) return;` add `if (isMuted.value) return;` so muted state suppresses one-shot tick playback. In `_onStateChanged`, keep state tracking (`_currentStatus`, `_currentPhase`, `_currentTickSource`, tick-source asset reload) running unconditionally, but skip audio side effects when `isMuted.value == true`: wrap the section that issues `_looper.fadeOut / _looper.crossfadeTo / _looper.fadeIn` in the status-change block (step 3) and the phase-change block (step 4) with `if (!isMuted.value) { ... }`. The early `return;` after handling status/phase change must stay outside the mute guard so subsequent state changes still reach their tracking branches consistently.

### Phase 2: Orb tap hook

- [x] **Task 3: Add optional onTap to EclipseOrb**
  Files: `packages/breath_module/lib/src/BreathSession/Views/EclipseOrb.dart`
  Add `final VoidCallback? onTap;` field on `EclipseOrb` and a `this.onTap` named parameter in the const constructor (placed after the existing parameters, defaulting to null). In `_EclipseOrbState.build()`, change the existing `GestureDetector(onTap: pulse, ...)` to `GestureDetector(onTap: () { pulse(); widget.onTap?.call(); }, ...)`. Do not change `pulseStream` behavior or any painter parameters.

### Phase 3: Bottom bar layout

- [x] **Task 4: Split SessionBottomBar into leading + trailing actions**
  Files: `packages/breath_module/lib/src/BreathSession/Views/SessionBottomBar.dart`
  Rename the existing `actions` parameter to `trailingActions` (keep it required). Add a new `final List<Widget> leadingActions;` field with a `this.leadingActions = const []` default in the constructor. Replace the single trailing `Row(mainAxisAlignment: MainAxisAlignment.end, spacing: 8, children: actions)` with a top-level `Row` containing: `Row(spacing: 8, children: leadingActions)`, `const Spacer()`, `Row(spacing: 8, children: trailingActions)`. The outer `Row` should not specify `mainAxisAlignment` (the `Spacer` handles distribution). Keep the `IconTheme.merge` wrapper and the existing `ColoredBox` / padding intact.

### Phase 4: Screen wiring

- [x] **Task 5: Add blackout state and overlay to BreathSessionScreen** (depends on Task 3, Task 4)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Add `bool _isBlackedOut = false;` as a private field on `_BreathSessionScreenState`. In the `EclipseOrb(...)` inside the existing `ValueListenableBuilder<double>(valueListenable: _orbCoordinator.orbProgress, ...)`, pass `onTap: () => setState(() => _isBlackedOut = true)`. Wrap `Scaffold.body` in a `Stack` whose first child is the existing `SafeArea(bottom: false, child: Column(...))`, and whose second child is an `AnimatedOpacity` with `opacity: _isBlackedOut ? 1.0 : 0.0`, `duration: const Duration(milliseconds: 300)`, wrapping an `IgnorePointer(ignoring: !_isBlackedOut, child: GestureDetector(onTap: () => setState(() => _isBlackedOut = false), child: const ColoredBox(color: Colors.black, child: SizedBox.expand())))`. Keep `resizeToAvoidBottomInset: false` and `backgroundColor: Theme.of(context).scaffoldBackgroundColor` on the `Scaffold`.

- [x] **Task 6: Wire mute button into SessionBottomBar** (depends on Task 1, Task 2, Task 4, Task 5)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Update the `SessionBottomBar` call inside the existing trailing `Consumer`: rename the existing `actions:` parameter to `trailingActions:` (children unchanged: share icon, conditional star icon, edit icon — all already using `cs.tertiary`). Add a new `leadingActions:` list containing a single `ValueListenableBuilder<bool>(valueListenable: _soundCoordinator.isMuted, builder: (context, isMuted, _) => IconButton(icon: Icon(isMuted ? Icons.volume_off_outlined : Icons.volume_up), color: isMuted ? Colors.white.withValues(alpha: 0.3) : cs.tertiary, onPressed: _soundCoordinator.toggleMute))`. The `cs` local is already defined earlier in `build()`; no extra imports are needed (`ValueListenableBuilder` comes via `flutter/material.dart`, already imported).

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add mute state and audio guards to BreathSoundCoordinator"
- **Commit 2** (after tasks 3-4): "Add onTap to EclipseOrb and split SessionBottomBar into leading/trailing actions"
- **Commit 3** (after tasks 5-6): "Wire mute button and orb-tap blackout overlay into BreathSessionScreen"

<!-- orchestrator-sessions
planner: 57817400-91d2-4c59-b5b3-ed018351eac7
elapsed: 1034
implementer: c22b22cd-3a18-4f10-895c-0ea7bfc91632
-->
