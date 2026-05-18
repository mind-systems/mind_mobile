# Plan Review: 09-fix-two-crossfade-bugs-hung-play-on-first-cycle-and-late-crossfade-start

## Summary

**Files Targeted:** 1 (`packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`)
**Risk Level:** 🟢 Low

The plan is well-scoped, surgically small, and the diagnosis of both bugs matches what the code currently does at lines 200–236. File path, line numbers, and method/field names referenced by the plan all match the source. No new APIs are required, no migrations, no proto changes, no cross-project coordination.

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. `BreathSoundCoordinator` lives inside the `packages/breath_module/` standalone package and only depends on `just_audio` plus the module's own models (`BreathSessionState`, `BreathSessionViewModel`, `TickSource`). The plan touches one private method (`_switchToPhase`) and respects the existing layering — no leakage into `lib/`, no new domain-model imports.
- **Rules (`.ai-factory/RULES.md`):** PASS. The rules cover Module Services (statelessness, stream ownership, DI). `BreathSoundCoordinator` is a coordinator, not a Service, and the plan does not add new state, streams, or app-layer wiring.
- **Roadmap (`.ai-factory/ROADMAP.md`):** WARN. The plan file does not explicitly link to a roadmap item, but the roadmap contains an in-flight audio/crossfade thread that this naturally continues. Not a blocker for a `fix`.

## Findings

### Critical Issues
None.

### Major Issues
None.

### Minor / Worth Noting

**M1. Residual race between two concurrent `_switchToPhase` invocations at `await setVolume` / `await seek` on the same `inactive` player.**
Task 1 eliminates the `await inactive.play()` window where the most damaging race occurs, but a smaller window remains: if invocation 2 starts while invocation 1 is suspended in `await inactive.setVolume(0.0)` or `await inactive.seek(...)`, both invocations end up operating on the same `inactive` reference (since invocation 1 has not yet reached the `_activeLoop = inactive; _inactiveLoop = active;` swap). After both resume, the *later*-finishing invocation's swap can revert the earlier-finishing one's swap, and the *earlier*-finishing invocation's `seek(index=phase_old)` can overwrite the new invocation's `seek(index=phase_new)` on the same player. The post-swap `gen` BAIL guard mitigates state divergence in some sub-traces but not all of them.
This is not a regression introduced by this plan (the race partially existed before), and per-phase intervals are typically long enough that real-world hitting is rare. Mentioning here so the implementer is aware: if log evidence after deployment shows another oddity, this is the next thing to harden (e.g., by capturing `inactive` *only after* the gen-check, or by cancelling/awaiting an in-flight `_switchToPhase` Future before starting a new one).

**M2. Outgoing fade started before the gen / status BAIL guards.**
Task 2 deliberately places `_fadePlayer(active, 0.0, fadeDuration)` *before* `await _loadFuture` and the two BAIL checks. That's correct for the bug being fixed (you want the fade-out to begin immediately, not after seek latency), but it does mean: if the method BAILs (gen mismatch or status change to pause/rest/complete), the outgoing fade keeps running. In practice this is benign — the only downside is that pause/rest will independently target the same player to 0.0, and `_fadePlayer`'s built-in `_cancelFadeFor(player)` ensures the more recent fade wins. Worth noting in the implementation log, no code change needed.

**M3. The new flow makes the crossfade asymmetric in time.**
Outgoing fade begins at T = 0, incoming fade begins at T ≈ `seek_latency` (~150–270 ms). With a typical `fadeDuration` ≈ phase interval, this means there is a brief sub-second region where the outgoing has already faded ~20% but the incoming hasn't yet started — a slight perceptible volume dip. This is strictly better than the current behaviour (silent gap at the *start* of the new phase), and the plan correctly identifies this trade-off implicitly. If a fully overlapping fade is later desired, the only way to get it without removing the seek-latency dependency would be to start `seek()` on the inactive player one tick early — out of scope for this fix.

**M4. Edge case: very short `fadeDuration` (< seek latency).**
If `state.currentIntervalMs` is, say, 100 ms (very fast breathing), the outgoing fade completes before the incoming fade even begins — perceptible silence gap. This was already true before the fix (and arguably less bad than the current "outgoing stays full → silent gap at start"), so not a blocker, but the implementer should sanity-check the minimum allowed `currentIntervalMs` in the session model to confirm this regime is unreachable. From the code, `intervalMs > 0 ? intervalMs : 1000`, so values like 50 ms are theoretically possible if the upstream session config permits.

**M5. Task 1 log-rename detail is good but incomplete.**
Renaming `play() done` → `play() dispatched` (line 228) is correctly called out. There is also a `play() on $inactiveName` log on line 226 immediately before the call — this one is still accurate (it logs the *intent* to call play, which still happens), so no change needed. The plan does not over-reach into unrelated log lines — good.

**M6. Task 4 (verification) is manual-only.**
This is fine for a 3-line change with `Testing: no`. Just make sure during implementation that step 4 of the verification (`_cancelFadeFor(inactive)` runs before `setVolume(0.0)`) is genuinely preserved — the plan does *not* call for removing `_cancelFadeFor(inactive)`, but the implementer should not "tidy" it away.

### Positive Notes

- The diagnosis is concrete and grounded in observed log evidence (`play() done gen=1 BAIL` ~36 s late). The proposed fix (drop `await` on `play()`) targets the exact suspension window described.
- Capturing `final active = _activeLoop` locally and using that for the early fade-out is the correct defence against the concurrent-swap race — better than reading `_activeLoop` again later inside the same method.
- The plan correctly preserves both `gen != _switchGen` BAIL guards and explicitly calls out that they remain necessary.
- Task 4 (re-read the final ordering top-to-bottom) is a useful belt-and-braces verification step for an async method this dense.
- Log messages are updated alongside semantics (`play() done` → `play() dispatched`, dropping `old-active→0.0` from the post-swap log) so future diagnostics stay honest.
- Scope is correctly narrow: only `_switchToPhase` changes; `_onStateChanged`, `_fadePlayer`, `_cancelFadeFor`, `reset`, and `dispose` are untouched, and rightly so.
- No call sites or fakes reference the awaited `play()` contract (grep confirms: only the one site at line 227 awaits a player's `play()`), so Task 4's caveat about updating test doubles is informational rather than required.

## Verdict

The plan is internally consistent, the file paths and line numbers are accurate against the current source, the surgical edits are well-justified, and the change preserves the existing concurrency guards. The minor concerns above are either pre-existing (M1, M4) or informational (M2, M3, M5, M6) and do not warrant a revision.

PLAN_REVIEW_PASS
