## Code Review Summary

**Files Reviewed:** 2 (`packages/mind_audio/lib/src/audio_looper.dart`, `packages/mind_audio/lib/mind_audio.dart`)
**Risk Level:** 🟢 Low

This is a clean mechanical extraction of the ping-pong crossfade mechanics out of `BreathSoundCoordinator` into a domain-free utility in `packages/mind_audio`. The public API, internal field shape, and every Phase 12 invariant called out in the plan and spec note are preserved.

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — `mind_audio` is not yet listed in the modules table. The current change is internal to an already-existing package, so the omission was inherited; flagging only so the next milestone that wires `AudioLooper` into the coordinator can update ARCHITECTURE.md at the same time.
- **Rules (`.ai-factory/RULES.md`):** PASS — `AudioLooper` is not an `IXxxService` (no notifier wiring, no Riverpod interaction), so the "stateless Module Services" rule does not apply. It has no constructor dependencies; the spec-defined `initialize(sources)` handoff is acceptable.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Not blocking — plan + spec note 09 cover the linkage.
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** absent — no project-specific overrides to apply.

### Critical Issues
None.

### Minor Observations (non-blocking)

1. **`fadeOut` / `fadeIn` null-assert `_activePlayer!` without doc or guard** (`audio_looper.dart:66`, `:69`).
   The plan-review for plan 19 flagged this as a "should-clarify": calling `fadeOut`/`fadeIn` before `initialize()` or after `dispose()` will throw a null check. The implementation chose to keep the bang-on-null contract (matches the spec note verbatim), but the suggested one-line `///` comment documenting "must be called after `initialize`" was not added. Not a bug — the original `BreathSoundCoordinator` guarded with `if (_activeLoop != null)` and the new utility tightens the contract. Worth adding a doc comment when the coordinator is migrated to use `AudioLooper` so the caller-side guard responsibility is explicit.

2. **`crossfadeTo` does not validate `index`** (`audio_looper.dart:54`).
   Intentional and consistent with the spec (caller-owned validation). `inactive.seek(Duration.zero, index: index)` will throw for out-of-range values; the outgoing player has already been faded to silence in the synchronous prologue, so a throw inside the IIFE leaves the looper in a quiet state without a new active player ever taking over. Caller (future coordinator) must continue to validate `_phaseOrder.indexOf(phase) != -1` before invoking. Acceptable as designed.

3. **Race window during `dispose()` vs. in-flight `crossfadeTo` IIFE** (`audio_looper.dart:48–62` vs. `:90–104`).
   `dispose()` nulls `_loadFuture` and the player fields, but a `crossfadeTo` IIFE captured `active`/`inactive` as locals at entry. After dispose, the IIFE's `await inactive.setVolume(0.0)` / `inactive.seek(...)` will run against just-disposed players, and the swap reassigns `_activePlayer = inactive` (a disposed instance), then `_fadePlayer(_activePlayer!, 1.0, …)` schedules a 16 ms timer that calls `setVolume` on the disposed player every tick until the fade completes. This race is inherited verbatim from `BreathSoundCoordinator._switchToPhase` and is not in scope to fix in this mechanical extraction, but it's worth flagging because `AudioLooper` is now a reusable utility — a future user that calls `dispose()` mid-crossfade may observe `just_audio` errors. Cheapest mitigation (later): bump `_switchGen` inside `dispose()` so the post-swap gen check (`audio_looper.dart:60`) trips and skips the final `_fadePlayer`. Not required by this plan.

4. **`stop()` does not bump `_switchGen`** (`audio_looper.dart:73–86`).
   Inherited from `BreathSoundCoordinator.reset()`. Any pending `crossfadeTo` IIFE will still run to completion and may re-assign `_activePlayer` from the swap, even though the user called `stop()` expecting "everything quiets down." Fade timers are cancelled, so audio stays silent, but `_activePlayer`/`_inactivePlayer` can flip back to a swapped pair seconds later. Consistent with the source; flag only so the coordinator-side rewrite (next milestone) doesn't assume "stop cancels in-flight crossfades."

### Positive Notes

- **Phase 12 invariants preserved exactly:**
  - Outgoing player begins fading synchronously before any `await` (`audio_looper.dart:46`).
  - `unawaited(inactive.play())` — `play()` is never awaited (`audio_looper.dart:55`).
  - Generation check both after `_loadFuture` (`:50`) and after the active/inactive swap (`:60`), matching `BreathSoundCoordinator.dart:261` and `:273`.
- **Domain bails correctly stay out.** `_currentStatus != BreathSessionStatus.breath` and `_phaseAssets[phase] == null` guards are absent here — the looper is genuinely domain-free as designed. The class doesn't import anything from `breath_module` or `lib/`.
- **`_fadePlayer` / `_cancelFadeFor`** are byte-equivalent to the source (16 ms step, `max(1, …)` floor on steps, per-player timer field assignment in both the periodic callback and the post-create assignment). The `kDebugMode` / `debugPrint` noise from the coordinator is correctly stripped (Settings: Logging minimal).
- **`dispose()` ordering is safe.** Timers are cancelled and nulled, player refs captured into locals, all fields nulled before `unawaited(player.dispose())` runs — prevents a fade timer callback from racing the teardown by writing to a stale `_fadeTimerA`/`_fadeTimerB`. The plan-review's suggested edit (null the timer fields too) was actually applied (`:92`, `:94`).
- **Barrel export is correct** — `packages/mind_audio/lib/mind_audio.dart` adds the export after the existing entries; `package:mind_audio/mind_audio.dart` now re-exports `AudioLooper`. No `pubspec.yaml` edits needed (`just_audio: ^0.10.5` already declared).
- **No tests, no docs, no migrations** — matches the plan's `Testing: no` / `Docs: no` settings; nothing extraneous was added.
- **Task-level dependencies preserved** — single new file, single one-line export edit; no incidental refactors of the still-existing coordinator code (the next milestone will migrate the coordinator to use `AudioLooper`).

REVIEW_PASS
