# Plan Review: Re-tether breath screen audio to `isLive`

**Plan:** `06-re-tether-breath-screen-audio-to-islive-supersedes-phase-56-note-162.md`
**Files reviewed against:** 4 (plan target + 3 supporting source files)
**Risk Level:** 🟢 Low

## Verification of plan claims

Every concrete claim in the plan was checked against the actual source:

| Claim | Status |
|---|---|
| `_BreathSessionScreenState` already mixes `TickerProviderStateMixin` | ✅ Confirmed (`BreathSessionScreen.dart:33-34`) |
| Screen currently has **no** `WidgetsBindingObserver` / `didChangeAppLifecycleState` | ✅ Confirmed — clean re-add, no conflict |
| Observer idiom in `BreathSessionConstructorScreen` (`addObserver` in `initState`, `removeObserver` first in `dispose`) | ✅ Confirmed (`BreathSessionConstructorScreen.dart:24,36,43`) |
| `suspend()` at `:136`, `resume()` at `:141` exist on `BreathSoundCoordinator` | ✅ Exact line match |
| `_onTick` early-return `if (_isSuspended) return;` at `:198` | ✅ Exact line match |
| `suspend()` sets `_isSuspended` + stops one-shot; `resume()` only clears the flag | ✅ Confirmed (`:136-143`) |
| `BreathSessionState.isLive` getter exists, true for `running`/`paused` only | ✅ Confirmed (`BreathSessionState.dart:56-58`) |
| `ref.read(breathViewModelProvider)` returns `BreathSessionState` (so `.isLive` is valid) | ✅ Confirmed — same access pattern used at `BreathSessionScreen.dart:81` |
| `_soundCoordinator` assigned synchronously in `initState` (`:71`) before any lifecycle callback | ✅ No null/late-init risk |

The gate logic is sound:
- `notStarted` → `isLive == false` → `suspend()` stops the `tick_clock.ogg` one-shot — this is exactly the reported bug (`allowTick` includes `BreathSessionStatus.pause`, `:200`).
- `completed` → `isLive == false` → `suspend()` (harmless; `allowTick` is already false for `complete`, but safe).
- `running` / manual-`paused` → `isLive == true` → no-op, audio survives backgrounding, matching the stated constraint.
- `resumed` → unconditional `resume()` is safe on a never-suspended coordinator (flag already `false`).

Disposal ordering (remove observer **before** coordinator disposals + `super.dispose()`) correctly prevents a lifecycle callback from touching a disposed coordinator.

## Context Gates

- **Architecture** (`ARCHITECTURE.md` present): ✅ No boundary violation. The change lives entirely in the presentation package screen state calling existing coordinator methods — no domain leakage, no new cross-layer dependency.
- **Rules** (`RULES.md` present): ✅ No conflict. The three rules concern Module Services (statelessness), App.dart purity, and constructor injection — none apply to a screen `State` adding a `WidgetsBindingObserver`. `_soundCoordinator` is already constructor-injected into the coordinator; the plan only calls its existing public methods.
- **Roadmap** (`ROADMAP.md` present): ✅ Strong linkage. The plan is a verbatim match for the Phase 58 "Consumer migration (keep-alive fix)" task *"Re-tether breath screen audio to `isLive` (supersedes Phase 56 / note 162)"* (`ROADMAP.md:25`), including the "do NOT re-add Phase 51's running-session auto-`pause()`" constraint.

## Critical Issues

None.

## Minor Notes (non-blocking)

1. **Line-number references may drift.** The plan cites `BreathSoundCoordinator.dart:136/141/198`. They are exact today, but once Task 1 edits the *screen* (different file) these stay valid — no action needed, just be aware they are not load-bearing for the edit itself.
2. **Logging facade.** Setting is "minimal" and the plan adds no logs, which is fine. If the implementer chooses to add even one diagnostic line in `didChangeAppLifecycleState`, it must go through `logPrint` (import `package:mind/Logger.dart` re-export is not available inside the package — use `package:mind_logger/mind_logger.dart` directly per project CLAUDE.md), never `print`/`debugPrint`.
3. **Commit message.** The proposed message *"Re-tether breath screen audio to isLive lifecycle gate"* complies with the global git convention (sentence case, no type prefix, no trailing period). Good.

## Positive Notes

- The plan correctly chose the *local* `isLive` signal over note 162's server-derived `_started && !_ended`, keeping the fix offline-correct (matches the roadmap's "strictly better than note 162" rationale).
- Scope is tightly fenced: explicit "do not touch" list for FGS, biometrics, state machine, tick sources, and `BreathSoundCoordinator` internals — and the dead `suspend()`/`resume()` API being reused means no new coordinator surface.
- Reusing the existing, proven observer idiom from the sibling constructor screen minimizes the chance of lifecycle-handling mistakes.

PLAN_REVIEW_PASS
