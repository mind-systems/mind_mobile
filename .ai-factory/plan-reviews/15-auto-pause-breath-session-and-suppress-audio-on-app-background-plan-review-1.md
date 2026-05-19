# Plan Review: Auto-pause breath session and suppress audio on app background

**Plan:** `15-auto-pause-breath-session-and-suppress-audio-on-app-background.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** Not directly relevant — this is a screen-level wiring change inside the presentation package.
- **RULES.md:** No violations. The plan does not touch App.dart, does not add streams/state to module Services, and does not introduce non-DI wiring.
- **ROADMAP.md:** Not inspected for milestone linkage; task is a small follow-up to plan 14 (suspend/resume API). WARN: no explicit ROADMAP linkage in the plan body, but this is consistent with other recent fix-style plans in the directory.

## Verification of Plan Assumptions

All structural assumptions verified against the live source:

| Plan claim | Source check | Result |
|---|---|---|
| Line 33: class declaration uses `TickerProviderStateMixin` | BreathSessionScreen.dart:33 | ✅ Matches verbatim |
| Line 45: `initState()` opens at this line | BreathSessionScreen.dart:44–45 | ✅ Matches |
| Line 46: `super.initState();` | BreathSessionScreen.dart:46 | ✅ Matches |
| Line 97: `dispose()` opens at this line | BreathSessionScreen.dart:96–97 | ✅ Matches |
| Line 105: `super.dispose();` | BreathSessionScreen.dart:105 | ✅ Matches |
| Line 108: `_scrollToActive` declared next | BreathSessionScreen.dart:108 | ✅ Matches |
| `BreathSessionStatus` enum visible via `Models/BreathSessionState.dart` import | line 6 in screen, line 5 in state file | ✅ Enum exists with `breath`, `rest`, `pause`, `complete` |
| `WidgetsBindingObserver` available through `package:flutter/material.dart` | line 1 import | ✅ Re-exported via `widgets.dart` |
| `_soundCoordinator.suspend()` / `.resume()` exist on `BreathSoundCoordinator` | Audio/BreathSoundCoordinator.dart:160–167 | ✅ Both present (added by plan 14) |
| `viewModel.pause()` exists | BreathSessionViewModel.dart:231 | ✅ `void pause() => _stateMachine?.pause();` |
| `ref.read(breathViewModelProvider).status` gives `BreathSessionStatus` | `breathViewModelProvider` is `NotifierProvider<BreathViewModel, BreathSessionState>` | ✅ Reads state with `.status` field |

The plan's file paths, line numbers, and API references are all accurate.

## Behavioral Analysis

The two-step background sequence (`suspend()` first, then conditional `pause()`) is correct:

1. `_soundCoordinator.suspend()` flips `_isSuspended=true` and stops the tick player immediately — synchronous mute of the most audible asset.
2. `viewModel.pause()` then propagates through `_onStateChanged`, which hits the `BreathSessionStatus.pause` branch in `BreathSoundCoordinator` (line 185–186) and fades the active loop down to 0.0 over 200 ms. No extra audio plumbing needed — this matches plan note 2.

The plan's gating on `status ∈ {breath, rest}` is correct:
- `complete` → no-op (already terminal).
- `pause` → already paused, calling `pause()` again would be redundant churn.
- `loadState != ready` defaults to `status=pause`, so loading sessions are also skipped — correct.

Resume-side behavior (only un-suspend, do not auto-resume the session) matches platform UX expectations for breath/meditation apps and is the safe default.

## Issues

### Minor — `removeObserver` placement reasoning

The plan places `removeObserver` *after* all coordinator disposals and *before* `super.dispose()`, with the rationale: "the observer must outlive any callbacks the coordinators could schedule synchronously during their own disposal".

The rationale is incorrect. `WidgetsBindingObserver` only delivers OS lifecycle callbacks (`didChangeAppLifecycleState`, etc.) — coordinator disposal cannot synthesize lifecycle events. The actual hazard is the opposite: if the OS happens to deliver `didChangeAppLifecycleState` *during* dispose, the coordinators would already be disposed and `_soundCoordinator.suspend()` could touch nulled-out audio players.

In practice, `dispose()` runs synchronously on the platform thread between frames, so the race is essentially unreachable. The order is functionally fine, but the conventional Flutter pattern is `removeObserver` first. Suggest either:

- Move `WidgetsBinding.instance.removeObserver(this);` to be the first line of `dispose()` (before `widget.onDispose?.call();`), or
- Keep current order but drop the misleading justification comment from the plan body.

Not blocking — the implementation will work either way.

### Nit — Logging setting

`Settings: Logging: minimal` but the plan adds no `kDebugMode debugPrint` line on the lifecycle transition. Given that the audio coordinator is already verbose with `_ts() [Sound]` traces, adding a single matching log line on lifecycle transitions (e.g. `if (kDebugMode) debugPrint('${_ts()} [Screen] lifecycle=$state status=...');`) would help diagnose background-related audio bugs. Optional.

### Nit — Comment language

The existing file uses Russian comments (lines 19, 41, 48, 51, 57, 69, 76). The plan doesn't request comments, but if the implementer adds inline explanation, the project rule "All files must be written in English" (root CLAUDE.md) should override the file's existing convention.

## Edge Cases Considered

- **iOS `inactive → paused → inactive → resumed` sequence** (app-switcher peek): `inactive` is ignored, audio suspends on `paused`, un-suspends on `resumed`. ✅
- **Audio interruption (incoming call) during active session:** Not handled by this plan and not in scope — that's an `AVAudioSession` concern handled by `just_audio`. ✅ Acceptable scope cut.
- **Background during loading (`loadState=loading`):** `status` defaults to `pause`, so `viewModel.pause()` is correctly skipped. `_soundCoordinator.suspend()` still fires, which is safe (just sets a flag and stops a not-yet-playing tick player). ✅
- **Background during `complete` state:** Loop already faded to 0.0 (line 197–198), `viewModel.pause()` skipped. ✅
- **Manual pause before backgrounding:** Status is already `pause`, `viewModel.pause()` skipped, redundant churn avoided. ✅

## Positive Notes

- Plan correctly leverages the suspend/resume API delivered by plan 14 rather than re-implementing audio gating in the screen.
- Status gate (`breath` or `rest` only) is precise and avoids the common bug of double-pausing.
- Decision to *not* auto-resume on `AppLifecycleState.resumed` is the correct UX choice and is explicitly called out.
- Order of operations (`suspend()` synchronous mute before `pause()` async fade) is right for minimizing audible artifacts.
- All file paths, line numbers, and method signatures verified accurate.

PLAN_REVIEW_PASS
