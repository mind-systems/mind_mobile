# Handoff — heart-tick-source-gap-tolerance

## 1. Frame
We are on a rolling debug-and-fix run in the `mind_mobile` Flutter repo (branch `dev`) — sometimes executing roadmap tasks, sometimes ad-hoc fixes the user spots live. The breath-dot motion engine fix just landed and is committed; the chat is compacted but the knowledge is durable in files — rehydrate from them, don't trust memory. The next task is heart-rate tick-source stability (below).

## 2. Read-first map

### Must-read now (minimal rehydration set — for the NEXT task)
- `docs/breath/session/tick-sources.md` — authoritative on the tick engine: `ClockTickService` (timer, 1000ms), `HeartRateTickService` (one RR interval → one `TickData`), `SwitchableTickService` (facade owning both; **auto-falls-back to timer when all RR sources go silent** — this is exactly the behavior the task changes), `ITickService.trySwitchTo`/`sourceChanges`.
- `docs/biometrics/active-rr-source.md` — `ActiveRrSource`: single-active RR source, **preferred-with-fallback policy, silence window, artifact handling**. The "silence window" is almost certainly where the 10s grace logic belongs or attaches.
- `lib/Biometrics/` — `ActiveRrSource` (app-level singleton) lives here; grep `ActiveRrSource`, `silence`, `Timer`.

### Read on demand
- `lib/BreathModule/BreathModule.dart` — `buildSession()` creates `ClockTickService`, `HeartRateTickService`, `SwitchableTickService(clock, heart)` and injects the switchable one into `BreathViewModel` as `ITickService`. Wiring/ownership point.
- `packages/breath_module/lib/src/ITickService.dart` — the `ITickService` contract (`tickStream`, `source`, `sourceChanges`, `trySwitchTo`, `nominalIntervalMs`).
- `BreathViewModel` (`packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`) — subscribes to `tickService.sourceChanges` → writes `BreathSessionState.tickSource`; `toggleHeartTickSource()` emits `BreathSessionUiEvent.noCardioSource` on failure. The heart feature is toggled from the heart button in `SessionBottomBar.leadingActions` on the breath screen.
- `.ai-factory/notes/90-test-plan-active-rr-source.md` — `ActiveRrSource` already has injectable `clock` + `timerFactory` (added for testability) → use them to test the 10s grace deterministically.
- `.ai-factory/notes/129-breath-dot-motion-engine-fix.md` — full write-up of the work just completed (the motion engine).

## 3. Current state

**Done (committed, `b17fe81` on `dev`):**
- Breath-dot motion engine fix — 4 latent bugs that surfaced together on uneven phase durations (e.g. inhale 2s / exhale 1s). Two files: `BreathMotionEngine.dart`, `BreathAnimationCoordinator.dart`. Full spec in note 129; Phase 44 in ROADMAP is one `[x]` line pointing there. Also swept the pre-existing untracked `.ai-factory/notes/100-grpc-client-keepalive.md` into that same commit at the user's request (it is unrelated to the motion work — do not assume it is).

**In-flight:** none.

**Uncommitted working-tree state:** none (clean as of the amend).

## 4. Next step
Make the heart tick source tolerant of device data gaps. **Today:** the moment RR data from the device drops (a gap), the heart-driven breathing feature falls back to the clock timer immediately (`SwitchableTickService` auto-switches to timer on RR silence). **Wanted:** on a gap, keep driving breathing using the **last known RR interval** for **at least 10 seconds** (synthesize ticks at that cadence so the animation keeps its rhythm), and only after ~10s of continued silence disable the heart feature and reset to the standard clock timer (the existing auto-fallback). Start by reading `docs/breath/session/tick-sources.md` + `docs/biometrics/active-rr-source.md` to locate the exact silence-window/fallback code, then decide whether the 10s grace belongs in `ActiveRrSource` (silence window) or `HeartRateTickService`/`SwitchableTickService` (coast-on-last-interval before signaling silence). The fallback must still surface through the single `sourceChanges` channel so `BreathSessionState.tickSource` flips correctly.

## 5. Working discipline
- Mode is debug-and-fix: fix first, ask only when ambiguous or risky.
- **Never commit without explicit user permission** ("закомить"/"коммить"/"амменд"). The user drives commit/amend timing explicitly.
- Debugging uses the local Loki backend via the `observe-logs` skill: temporary `logPrint` instrumentation (tagged like `[MOTION]`/`[ANIMCOORD]`) → user runs the app → pull with `bash ~/.claude/skills/observe-logs/scripts/query-loki.sh since-restart mind_mobile --project mind`. Strip all debug logs before finishing.
- The build must be a full restart to pick up engine/coordinator changes — hot reload on already-constructed long-lived objects/tickers is unreliable. Tell the user to relaunch.
- After a fix is accepted: clean logs → add/condense a ROADMAP task (one `[x]` contract line) → write a spec note in `.ai-factory/notes/` → commit only when told.

## 6. Error log
- **Amend swept in a stray file.** `git add -A` for the amend pulled in untracked `.ai-factory/notes/100-grpc-client-keepalive.md` (not part of the breath work). Caught it, removed via `git rm --cached` + amend, then the user explicitly asked to put it back — so it now lives in `b17fe81`. Lesson: prefer staging explicit paths over `git add -A` when an unrelated untracked file may be present.
- **Stale binary masquerading as "nothing logged".** First debug run showed zero of the new logs in Loki while old `[SM]` logs were present → the running app predated the edits. Always confirm a fresh build before trusting "the logs are empty."

## 7. Orientation
- **`logPrint` only** — never raw `print`/`debugPrint`/`dart:developer`. In packages import `package:mind_logger/mind_logger.dart`; in `lib/` import `package:mind/Logger.dart`.
- Two distinct tick concepts: `ITickService.nominalIntervalMs` (a static nominal, 1000ms placeholder) vs the measured `TickData.intervalMs` per tick. The 10s-grace work is about the *measured last interval*, not the nominal.
- `BreathMotionEngine._minRemainingTimeMs` / `_rampTimeConstantFraction` are the motion-engine tuning knobs from the last task — unrelated to the tick source; don't conflate.

## 9. Hard rules
- All generated/edited files in English; conversation is in Russian.
- Commit messages: short imperative, sentence case, no `feat:`/`fix:` prefixes, no trailing period; end with the `Co-Authored-By: Claude Opus 4.8 (1M context)` trailer.
- `flutter` is at `/usr/local/bin/flutter` — always full path.
- `flutter gen-l10n` runs inside `packages/mind_l10n`, not repo root (only if ARB strings change).
- Memory writes only on explicit trigger phrases.
- `mind_api/proto/` is the single source of truth for `.proto`; this repo only copies + regenerates.
