# Plan Review 2: Smoothed-RR metronome for breath ticks (heart gap tolerance)

**Plan:** `.ai-factory/plans/64-smoothed-rr-metronome-for-breath-ticks-heart-gap-tolerance.md`
**Spec:** `.ai-factory/notes/130-heart-tick-source-gap-tolerance.md`
**Files Reviewed:** plan, spec note 130, plan-review-1, `HeartRateTickService`, `ActiveRrSource`, `SwitchableTickService`, `ClockTickService`, `BreathModule`, `App.dart`, `RrInterval`, `switchable_tick_service_test.dart`, `RULES.md`, `ROADMAP.md`, `docs/breath/session/tick-sources.md`, `docs/biometrics/active-rr-source.md`
**Risk Level:** 🟡 Medium

This revision faithfully resolves the two blockers raised in plan-review-1, and I re-verified each resolution against the actual code. The architecture (reusable `SmoothedRrSource` metric + breath-specific metronome/grace, "mirror `ClockTickService`", "real beats never emit ticks") is correct and maps cleanly to the existing files. One **new finding** remains: the prescribed replay-guard (`.skip(1)`) is only correct on the *warm* path — on a *cold* start it silently drops the first real beat, violating the plan's own stated invariant ("first real beat activates — matches today's behavior"). It is a narrow, self-healing edge case, not a build breaker, but the plan literally tells the implementer to write the buggy version, so it should be tightened before implementation.

---

## Verification of plan-review-1 resolutions

- **Critical #1 — `start()` vs. "test untouched" — RESOLVED.** Confirmed: `_FakeHeartRateTickService implements HeartRateTickService` (test line 50), so a new public `start()` on the concrete class forces the fake to provide it. The precedent is real — `_FakeClockTickService` has `@override void simulateTick() {}` at line 41. Task 4 now adds the matching `@override void start() {}` no-op and the constraint is reworded from "green untouched" to "stays green with one no-op override added." Correct, and no other implementer of `HeartRateTickService` exists (only `BreathModule` constructs it by concrete type and uses interface members + `hasActiveSource`, which `start()` does not affect). ✓
- **Issue #2 — `BehaviorSubject` replay — addressed, but see Issue A below.** The plan now explicitly guards the replayed value and relies on the constructor seed for initial activation. The intent is right; the prescribed mechanism has a cold-start gap. ✓ (with caveat)
- **Issue #3 — metronome timer type — RESOLVED.** Now unambiguous: "a one-shot timer that reschedules itself at the current `_currentPeriodMs` after each fire — NOT `Timer.periodic`." Grace is also one-shot. ✓
- **Issue #4 — redundant artifact logging — RESOLVED.** `SmoothedRrSource` is now a silent filter; confirmed `ActiveRrSource._onInterval` already `logPrint`s every artifact (line 74), so double-logging is correctly avoided. ✓

---

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — PASS. Placing `SmoothedRrSource` in `lib/Biometrics/` next to `ActiveRrSource` matches the existing layering; nothing to violate.
- **Rules (`.ai-factory/RULES.md`)** — PASS. The rule *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only"* applies, and the plan correctly frames `SmoothedRrSource` as general **biometric infrastructure** (mirrors `activeRrSource`, which already lives in `App` at lines 98/214/243). *"All dependencies must be injected via constructor"* is honored (`SmoothedRrSource(ActiveRrSource)`, `HeartRateTickService({required SmoothedRrSource, <timer factories>})`).
- **Roadmap (`.ai-factory/ROADMAP.md`)** — WARN. The entry **already exists**: *Phase 45 — Heart tick source: smoothed-cadence metronome (gap tolerance)*, with a `[ ]` task that already references `notes/130-heart-tick-source-gap-tolerance.md`. Task 6 ("Add a roadmap entry") is therefore largely redundant — it risks creating a duplicate phase. Reframe Task 6 as "verify Phase 45 is present and correctly linked to note 130 (it is); mark it `[x]` on completion" rather than adding a new entry.

---

## Issues / Risks

**A. (New) The `.skip(1)` replay-guard drops the first real beat on a cold start.**

Task 1 defines `smoothedIntervalStream` as a `BehaviorSubject<int>` and `smoothedIntervalMs` as "`null` before the first accepted beat" — i.e. the subject is created **unseeded** and has no value until the first non-artifact interval is published. A `BehaviorSubject` only replays synchronously to a new listener **when it `hasValue`**.

Task 3 instructs `HeartRateTickService` to "skip the first (replayed) emission (`.skip(1)` or a `bool _sawReplay` flag)." That assumes a replay is *always* pending. It is not:

- **Warm path** (a beat has arrived since app launch → `smoothedIntervalMs != null`): the first delivered event *is* the replay → `.skip(1)` correctly drops it, and real beats follow. ✓
- **Cold path** (no RR ever seen since app launch → `smoothedIntervalMs == null`): there is **no** replay, so the first delivered event is the **first genuine beat** → `.skip(1)` wrongly drops it. `_effectiveActive` stays `false`, `_currentPeriodMs` is not updated, and the grace timer is not armed until the **second** beat.

This contradicts the plan's own Task 3 invariant: *"Before the first beat ever … until the first real beat … `trySwitchTo(heartbeat)` is rejected — matches today's behavior."* With unconditional `.skip(1)` the feature actually activates only on the *second* real beat in the cold path. Today (`HeartRateTickService` proxying `ActiveRrSource.hasActiveSource`) it activates on the **first** beat. The scenario is narrow (app launched with no RR, sensor first connects mid-session) and self-heals on beat two (~1 s), so impact is low — but the plan as written directs the implementer to code exactly the broken variant.

**Fix to bake into Task 3:** make the skip *conditional on whether a replay is actually pending at construction time*. Capture `final bool _expectReplay = smoothedRrSource.smoothedIntervalMs != null;` (equivalently, whether the subject `hasValue`) and skip the first emission **only if** `_expectReplay`; otherwise treat the first emission as a real beat. A blanket `.skip(1)` — or a `_sawReplay` flag that ignores the first emission unconditionally — is correct only for the warm path. The constructor seed (`smoothedRrSource.hasActiveSource`) still governs initial activation in both paths.

**B. (Minor) Confirm grace-arm vs. cold-path interaction after the fix.** With the conditional-skip fix, on the cold path the first real beat must both set `_effectiveActive` true **and** arm/reset the grace timer (Task 3 already says "every subsequent emission … reset the grace timer" — just ensure "subsequent" is interpreted as "every non-replay emission," which the conditional guard makes precise). No code change beyond Issue A; just don't let the wording reintroduce the skip.

---

## Minor Notes

- **Subscription ordering is safe.** `BreathModule.buildSession` constructs `heart …()..start()` *before* `SwitchableTickService(clock, heart)`, and `SwitchableTickService` subscribes to `heart.hasActiveSourceStream` in its constructor (line 16). Since `_effectiveActive` is a seeded `BehaviorSubject`, the switchable service receives the seed on subscribe; while the active source is `timer` a `true`/`false` seed is ignored (the `_activeSource == TickSource.heartbeat` guard, verified at line 17 and by the test "should not switch … when active is timer"). ✓
- **Ignoring `ActiveRrSource`'s own silence window is intentional and correct.** The metronome deliberately does **not** subscribe to `hasActiveSourceStream`; it coasts on its own 10 s grace, overriding `ActiveRrSource`'s `max(2 s, lastInterval×2)` watchdog. That is the whole point of the feature and is consistent with the spec. ✓
- **No stuck-`true`.** Seeded-active with no further beats → grace (reset on each beat) fires at 10 s → `_effectiveActive.add(false)` → `SwitchableTickService` auto-falls-back. Verified against `SwitchableTickService._healthSub`. ✓
- **Broadcast `_tickController` + no prime tick** — early metronome ticks before a switch-to-heartbeat are dropped, matching `ClockTickService`'s free-running behavior. ✓
- **Docs language (Task 5).** `docs/breath/session/tick-sources.md` and `docs/biometrics/active-rr-source.md` are written in **Russian**. Task 5 correctly says "match the language and style of the existing docs," which aligns with the global doc rule ("match the language of existing docs even if project instructions say otherwise"). The implementer must write these doc updates in Russian, not English — worth making explicit so the English-files project rule isn't applied here by reflex. ✓ (plan is correct; flagging only to prevent a wrong-language edit)
- **`nominalIntervalMs => 1000` retained** — correct; the real cadence rides on `TickData(_currentPeriodMs)`, and `SwitchableTickService.nominalIntervalMs` reads it only while heartbeat is active (line 43). ✓

---

## Positive Notes

- Both plan-review-1 blockers are genuinely resolved, not papered over, and the resolutions are traceable to exact line numbers in the real files (test line 41/50, `App` lines 98/214/243, `ActiveRrSource` line 74).
- The ownership split, the "mirror `ClockTickService`" binding rule, and the "real beats never emit ticks" double-count fix are all faithful to spec note 130's settled decisions (SMA window 7, 10 s grace, no prime tick, no pause logic, never stop on grace).
- `SwitchableTickService` correctly requires **no** change — verified the metronome/grace sit above `hasActiveSourceStream` so the single `sourceChanges` channel keeps `tickSource` correct.
- Commit plan is sensibly staged (metric + wiring → rewrite → docs), each commit independently coherent.

---

**Verdict:** The plan is close and the architecture is right; both prior blockers are resolved. Before implementing, tighten **Issue A** (make the replay-skip conditional on `smoothedIntervalMs != null` so the cold-start first beat is not dropped) and reframe **Task 6** to acknowledge that ROADMAP Phase 45 already exists (avoid a duplicate). These are small, localized edits — but because the plan currently prescribes the buggy `.skip(1)` variant verbatim, it should not pass as-is.
