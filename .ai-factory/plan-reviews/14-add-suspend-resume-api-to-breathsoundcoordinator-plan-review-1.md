# Plan Review: Add `suspend()` / `resume()` API to `BreathSoundCoordinator`

**Plan:** `.ai-factory/plans/14-add-suspend-resume-api-to-breathsoundcoordinator.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** PASS — the change is contained inside the existing module package (`packages/breath_module/...`), no domain layer or App.dart involvement.
- **RULES.md:** PASS — no Module Service stateful additions, no App.dart wiring, no constructor changes; the modification is purely internal to an already-stateful coordinator.
- **ROADMAP.md:** PASS — the plan corresponds 1:1 to the open roadmap item "Add `suspend()` / `resume()` API to `BreathSoundCoordinator`" (line 25), and explicitly leaves the wire-up to the follow-up "Auto-pause breath session and suppress audio on app background" (line 27). The plan correctly defers caller additions to the next milestone.

## Verification Against Codebase

Cross-checked each plan claim against the actual file:

- ✅ `_fadeTimerA` / `_fadeTimerB` are at lines 29–30 — placement of `_isSuspended` alongside is accurate.
- ✅ `_onTick()` is at lines 215–225 — the line range cited in the plan is correct.
- ✅ `dispose()` ends at line 157, `_onStateChanged()` starts at line 159 — the requested insertion point ("after `dispose()` and before `_onStateChanged()`") is unambiguous.
- ✅ `_tickPlayer` is a nullable `AudioPlayer?` field initialized inside `initialize()` (line 103); `unawaited(_tickPlayer?.stop())` is safe both before initialization and after dispose (where `_tickPlayer` is nulled out, line 153).
- ✅ `_tickSub` is the stream subscription bound to `viewModel.tickStream.listen` (line 106). Plan correctly insists it must **not** be cancelled, so `_onTick()` keeps being invoked and observes `_isSuspended` on each event.
- ✅ Style notes (no trailing commas on single-arg calls, `unawaited(...)` for fire-and-forget, 2-space indentation) match the surrounding code.

## Findings

### Critical Issues
None.

### Suggestions (non-blocking)

1. **`reset()` interaction.** `reset()` (lines 110–129) intentionally clears playback state but does not touch `_isSuspended`. This is the correct behavior — `_isSuspended` reflects app lifecycle, not session lifecycle — but the plan doesn't mention `reset()` at all. Consider an explicit one-liner in Task 1 confirming that `reset()` should **not** mutate `_isSuspended` so the implementer doesn't second-guess and add it. Not a blocker; the omission is consistent with the "zero-behavior-change" framing.

2. **`dispose()` interaction.** Same reasoning: no cleanup required (it's just a `bool`), but worth a sentence so the implementer doesn't add a redundant reset there either. Optional.

3. **Idempotency wording.** The plan says "calling `suspend()` twice is a no-op beyond re-issuing `_tickPlayer?.stop()`." Re-issuing `stop()` on an already-stopped `just_audio` player is harmless (it's documented as idempotent), so the wording is fine — flagging only so the implementer knows there is no need to guard against repeated calls with `if (_isSuspended) return;` inside `suspend()`.

4. **Logging.** The plan deliberately places the `if (_isSuspended) return;` **before** the existing `debugPrint`. That's intentional and stated, but the project's "minimal logging" setting could equally justify a single `debugPrint('${_ts()} [Sound] _onTick suspended — skip')`. Not requesting a change; just confirming the silent-on-suspend behavior is a conscious choice.

### Positive Notes
- Plan correctly limits the surface to API-only, leaving the caller wiring (and the loop-audio strategy via session-layer pause) to the next milestone. This matches the roadmap's two-step decomposition.
- The plan is precise about what `suspend()` must **not** do (no `_tickSub` cancel, no loop player touches), which is the part most likely to be over-implemented by a careless agent. Good defensive specification.
- Both methods are described as idempotent, removing any ambiguity for the implementer.
- Line-number anchors are accurate, so the implementer can apply the edits without re-reading the full file.

## Conclusion

The plan is small, accurate, and matches both the codebase and the roadmap's explicit specification. The two tasks are well-scoped, the file paths and line ranges check out, and the deliberate "zero-behavior-change" framing is preserved by inserting the guard before any caller exists.

PLAN_REVIEW_PASS
