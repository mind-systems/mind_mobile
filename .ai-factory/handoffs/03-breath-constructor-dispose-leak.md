# Handoff — breath constructor dispose leak / zombie sound coordinator

## 1. Frame
Opening the breath-session editor (constructor) from an active session leaves a "zombie" screen alive — the clock tick sound never stops; the diagnosis is blocked by a logging-architecture gap that is itself now a planned fix (Phase 40). The chat is compacted but the knowledge is durable in the files below — rehydrate from them, don't trust memory.

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `lib/BreathModule/BreathSessionCoordinator.dart` — `openConstructor()` uses `context.push(...)` → the constructor is pushed **over** the session screen, so the session screen state is never disposed. This is the root of the leak.
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` — `openEditor()` = `pause()` + `coordinator.openConstructor(sessionId)`. It does **not** suspend/dispose the sound coordinator.
- `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` — `_onTick()` plays the tick `AudioOneShot` (`tick_clock.ogg`) while status is `pause` OR `rest` (`allowTick` includes both). `dispose()`/`suspend()`/`reset()` are the only things that silence it.
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` — `_BreathSessionScreenState` owns `_soundCoordinator` and disposes it in `State.dispose()`; `didChangeAppLifecycleState` calls `suspend()`/`resume()` on app background only.
- `.ai-factory/notes/118-extract-logger-into-shared-package.md` + `119-route-module-package-logs-to-loki.md` — the logger-package fix (Phase 40) that unblocks Loki-visible logging inside packages, needed to confirm this bug "properly".

### Read on demand
- `lib/BreathModule/BreathModule.dart` — `buildSession()` assembly; `onDispose: () => stateChannel.dispose()` wired to the screen.
- `lib/Logger.dart` — `logPrint` → console + `observeSink` (Loki). Lives in `lib/`; packages can't import it (the gap).
- `docs/breath/session/audio.md` — BreathSoundCoordinator, tick sounds, crossfade, background pause.
- `docs/breath/session/session-lifecycle.md` — completion / idle / restart flow.
- `.ai-factory/ROADMAP.md` Phase 40 — the two logger tasks (notes 118/119).

## 3. Current state

**Done:**
- Root-cause hypothesis formed (see §4/§11) by reading the suspect chain.
- Confirmed **one** link via Loki: a `lib/`-level `logPrint` probe in `openConstructor` proved it fires `context.push` (session screen stays mounted). Loki line at `12:26:59Z`, `service_name=mind_mobile`.
- Found the blocker: package-side probes (`debugPrint`) never reach Loki, so the decisive evidence (dispose-not-called, tick-keeps-playing) was not observable in Loki.
- Filed the logger fix as **Phase 40** in `.ai-factory/ROADMAP.md` (notes 118 + 119). Not implemented.

**In-flight:**
- The dispose bug is **not confirmed by logs end-to-end** and **not fixed**. No spec note exists for it yet.

**Uncommitted working-tree state:**
- mind_mobile working tree is **clean**. All throwaway probe instrumentation (the `[probe]` lines in 4 files, the new `packages/breath_module/lib/src/probe_log.dart` seam, and its barrel export) was **rolled back** at the user's instruction. The only persisted artifacts are the Phase 40 roadmap entry + notes 118/119 (committed-or-tracked planning docs, intentional).

## 4. Next step
Decide the diagnosis path, then confirm before fixing:
- **Option A (preferred by the architecture):** implement Phase 40 first (extract `packages/mind_logger`, note 118 → wire packages, note 119) so `logPrint` works inside `breath_module`; then re-instrument the suspect lifecycle with real `logPrint` and confirm the chain in Loki.
- **Option B (faster, console-only):** re-add the throwaway `debugPrint` probes and read them in the `flutter run` console (not Loki) to confirm now.
Either way, confirm this exact chain before any fix: `openEditor` → `openConstructor` (push) → `BreathSessionScreen.dispose` **NOT** called → `SoundCoordinator.dispose`/`suspend` **NOT** called → `_onTick PLAY status=pause` keeps firing. Only after confirmation, choose a fix (candidates in §11). The dispose bug has no roadmap task yet — file one (two-tier) once confirmed.

## 5. Working discipline
- **Verification before fixing.** The user insists on logs/repro to root cause — no theory-only fixes. They pushed back hard on guessing and on workarounds.
- **Commit only on explicit permission.** Nothing here should be committed without being told.
- **Route fixes to the owning project**; don't patch someone else's repo in place.
- Roadmap tasks are **two-tier**: a contract line + a spec note (aif-note format); `/aif-plan` then STOP — implementation is a separate `/aif-implement` session.
- Docs: target-state, present tense, no history language, no class names, Russian (match neighbours); roadmaps/notes/handoffs in English.

## 6. Error log
- **Built a throwaway logging seam instead of fixing the cause.** To get package probes into Loki, a `probe_log.dart` + injected `breathProbeLog` (= `logPrint`) hook was added across `breath_module`. The user rejected it as a workaround for the real gap (the logger isn't importable in packages) and told us to roll it back. Correction: extract a shared `mind_logger` package (Phase 40) so packages can call the real `logPrint`. The seam and all probes were reverted; tree is clean.
- **Package probes were placed as `debugPrint` → invisible in Loki.** Only the single `lib/`-level `logPrint` probe surfaced. This is the symptom of the gap, not a coding slip, but it is why the first Loki read showed just one line.

## 7. Orientation
- **Two different "tick" sounds.** (1) `BreathSoundCoordinator._oneShot` playing `tick_clock.ogg` in the breath session — **this** is the leaking sound. (2) A separate clock tick in BCI calibration (`packages/bci_module/.../BciCalibrationSection.dart`). Do not conflate.
- **`suspend()` vs `dispose()` on the sound coordinator.** `suspend()` (app background, stops the one-shot, sets `_isSuspended`) vs `dispose()` (screen teardown, cancels tick sub + state listener + looper/oneShot). On `context.push` to the constructor, **neither** fires.
- **`_onTick` `allowTick` deliberately includes `pause` and `rest`** — the clock keeps ticking while paused/resting by design. That design is what makes the un-disposed screen audible.
- **Package logs (`debugPrint`) ≠ Loki; `lib/` logs (`logPrint`) = Loki.** This distinction is the whole reason diagnosis stalled.

## 8. Domain model spine
- **`breath_module` is a standalone Flutter package and cannot import `lib/`** (module boundary) — so it cannot import `package:mind/Logger.dart`. Don't try to "just import logPrint" in the package; that's exactly what Phase 40 fixes by extracting `mind_logger`. (`packages/breath_module/`, `lib/Logger.dart`.)
- **`BreathSessionScreen` (the package screen) owns the animation/orb/sound coordinators** and disposes them in `State.dispose()`; lifecycle is wired via `onRestart`/`onDispose` callbacks injected by `BreathModule.buildSession()`. The dispose path only runs when the screen's `State` is actually disposed — which `context.push` does not trigger.

## 9. Hard rules
- No commits without explicit permission.
- All logs through `logPrint` (`package:mind/Logger.dart`) — but inside packages this is currently impossible; Phase 40 makes it possible. Never add raw `print`/`debugPrint`/`dart:developer` as a permanent solution.
- Memory writes only on an explicit trigger phrase (global rule).
- Flutter binary is at `/usr/local/bin/flutter` (full path).

## 11. Per-unit map with watch-points
- **`BreathSessionCoordinator.openConstructor` (lib)** — uses `context.push(BreathSessionConstructorScreen.path, ...)` (and a guest-auth `OnboardingScreen` push first). Watch-point: `push` keeps the session screen mounted underneath; a fix that relies on the screen disposing must change this to a replace, or suspend the sound explicitly.
- **`BreathViewModel.openEditor` (package)** — `pause()` then `openConstructor`. Watch-point: the cleanest fix may be to `_soundCoordinator.suspend()` (or stop the tick) here before navigating — but the coordinator is owned by the screen, not the viewmodel, so wiring a suspend hook through is the tricky part.
- **`BreathSoundCoordinator` (package)** — `_onTick` plays `tick_clock.ogg` during pause/rest; `dispose`/`suspend`/`reset` silence it. Watch-point: if the fix is "don't tick during pause", verify it doesn't break the intended paused/rest ticking UX (the clock is *meant* to tick at rest); prefer route-aware suspend over changing `allowTick`.
- **`BreathSessionScreen` (package)** — `State.dispose()` calls `_soundCoordinator.dispose()`; `didChangeAppLifecycleState` suspends on app background. Watch-point: a route-aware approach (e.g. `didPushNext`/`RouteAware`, or a "screen lost focus" signal) is the natural place to suspend the sound when the constructor covers it, mirroring the app-background `suspend()`.
- **Phase 40 logger package (notes 118/119)** — extract `mind_logger`, re-export from `lib/Logger.dart` (57 call sites untouched), wire into packages, migrate 3 stray `debugPrint`s. Watch-point: `observe` git ref must match the app pin (`main`); keep `logPrint` behavior byte-identical; this is the prerequisite for confirming the dispose bug in Loki.
