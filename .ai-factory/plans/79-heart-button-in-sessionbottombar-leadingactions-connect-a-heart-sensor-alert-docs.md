# Plan: Heart button in SessionBottomBar.leadingActions + "connect a heart sensor" alert + docs

## Context
Phase 22 M7 — final UI/UX wiring for the heart-rate tick source. Adds a tappable heart icon to the breath session bottom bar that toggles between clock and heart tick sources, surfaces an `AppAlert` when no cardio source is available, and rewrites/creates documentation so the new ActiveRrSource + SwitchableTickService stack is discoverable from `CLAUDE.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: yes (this milestone explicitly ships docs)

## Tasks

### Phase 1: l10n keys

- [x] **Task 1: Add `heartTickNoSourceTitle` and `heartTickNoSourceDescription` to EN ARB**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`
  Append the two keys near other simple string keys (e.g. after `error` / `comingSoon` block at the top of the file). Exact values:
  - `"heartTickNoSourceTitle": "Connect a heart sensor"`
  - `"heartTickNoSourceDescription": "Pair a BCI device to drive the breathing rhythm from your heartbeat."`
  Match the existing JSON style (two-space indent, comma separation, no metadata blocks unless needed). Do not edit `placeholders` blocks of unrelated keys.

- [x] **Task 2: Add matching RU translations to RU ARB** (depends on Task 1)
  Files: `packages/mind_l10n/lib/l10n/app_ru.arb`
  Append the two keys at the same logical position as in `app_en.arb`. Exact values:
  - `"heartTickNoSourceTitle": "Подключите датчик сердца"`
  - `"heartTickNoSourceDescription": "Чтобы дышать в ритм с сердцем, подключите BCI-устройство."`
  Keys must exist in both ARB files (Flutter l10n codegen fails otherwise).

- [x] **Task 3: Regenerate `AppLocalizations`** (depends on Task 2)
  Files: `packages/mind_l10n/lib/l10n/app_localizations.dart`, `packages/mind_l10n/lib/l10n/app_localizations_en.dart`, `packages/mind_l10n/lib/l10n/app_localizations_ru.dart`
  Run the codegen step the project uses for `mind_l10n` (typically `flutter gen-l10n` from inside `packages/mind_l10n` — full Flutter path `/usr/local/bin/flutter`). Verify that both `AppLocalizations.heartTickNoSourceTitle` and `AppLocalizations.heartTickNoSourceDescription` getters appear in the generated files. Do not hand-edit generated files.

### Phase 2: Screen wiring (heart button + alert handler)

- [x] **Task 4: Add heart `Consumer` button as second entry in `leadingActions`** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Inside `build()`, in the `SessionBottomBar(...)` call (around line 304), append a new entry to `leadingActions` directly after the existing mute `ValueListenableBuilder` (so mute stays at index 0, heart goes at index 1). Use a `Consumer` that watches only `tickSource`:
  ```dart
  Consumer(builder: (context, ref, _) {
    final tickSource = ref.watch(
      breathViewModelProvider.select((s) => s.tickSource),
    );
    final isActive = tickSource == TickSource.heartbeat;
    return IconButton(
      icon: const Icon(Icons.favorite),
      color: isActive ? Colors.red : Colors.white.withValues(alpha: 0.3),
      onPressed: viewModel.toggleHeartTickSource,
    );
  }),
  ```
  Match the exact visual rules from `.ai-factory/notes/29-heart-rate-tick-source.md` Milestone 7: filled red `Colors.red` when active, filled white at 30% alpha when inactive, no disabled state — always tappable. `TickSource` is already re-exported by `breath_module` (used in the VM); add an explicit import only if the screen file does not already see it via existing imports.

- [x] **Task 5: Replace the placeholder `onUiEvent` handler with a `switch` on `BreathSessionUiEvent`** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Replace the current handler in `initState()` (lines 99–104, the lambda `viewModel.onUiEvent = (_) { ... }` with the `// noCardioSource handled in M7` placeholder) with an exhaustive `switch` over `BreathSessionUiEvent`:
  ```dart
  viewModel.onUiEvent = (event) {
    switch (event) {
      case BreathSessionUiEvent.starFailed:
        ref.read(globalSnackBarNotifierProvider.notifier).show(
              SnackBarEvent.error(AppLocalizations.of(context)!.error),
            );
      case BreathSessionUiEvent.noCardioSource:
        AppAlert.show(
          context,
          title: AppLocalizations.of(context)!.heartTickNoSourceTitle,
          description: AppLocalizations.of(context)!.heartTickNoSourceDescription,
        );
    }
  };
  ```
  - The `starFailed` branch must preserve the current behavior verbatim (same `globalSnackBarNotifierProvider` + `SnackBarEvent.error` + `AppLocalizations.error` flow).
  - `AppAlert` already provides the OK button — no extra wiring.
  - Use exhaustive switch (no `default`) so adding new `BreathSessionUiEvent` variants in the future fails the analyzer instead of silently swallowing.
  - Remove the placeholder `// noCardioSource handled in M7` comment.

- [x] **Task 6: Add the `AppAlert` import** (depends on Task 5)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  `AppAlert` is exported from `package:mind_ui/mind_ui.dart` (the screen already imports `mind_ui`, so verify the export reaches this file — `packages/mind_ui/lib/mind_ui.dart` should already re-export `AlertModule/AppAlert.dart`). If `AppAlert` is not visible through the existing `mind_ui` import, add the explicit re-export to `packages/mind_ui/lib/mind_ui.dart` (do NOT add a deep import inside the screen — module-boundary rule). Verify analyzer is clean.

### Phase 3: Documentation

- [x] **Task 7: Rewrite `docs/breath/session/tick-sources.md` to describe both implementations + the Switchable facade** (depends on Task 6)
  Files: `docs/breath/session/tick-sources.md`
  Match the language of the existing file (Russian — per global doc rule "match the language of neighboring docs"). Replace the "Текущая реализация" section so it describes:
  - `ClockTickService` — `Timer.periodic(1000ms)`, `TickSource.timer`.
  - `HeartRateTickService` — subscribes to `ActiveRrSource.stream`, emits one `TickData(rr.intervalMs)` per RR-interval, `TickSource.heartbeat`. Lifetime: per-session (disposed with VM), but its upstream `ActiveRrSource` is app-singleton.
  - `SwitchableTickService` — facade owning both children. Default active source is `TickSource.timer`. Exposes `trySwitchTo(target)` (manual toggle) and `sourceChanges` stream (single sync point for both manual toggle and watchdog auto-fallback). Owns `dispose()` of both children.
  Add a new section "Переключение источника" describing:
  - Manual toggle from the heart button in `SessionBottomBar.leadingActions`.
  - Auto-fallback: when all RR sources go silent, `SwitchableTickService` swaps back to the clock automatically and emits on `sourceChanges`.
  - `BreathViewModel` subscribes to `sourceChanges` and writes the value into `BreathSessionState.tickSource`; the manual `toggleHeartTickSource()` method does NOT write `tickSource` directly — single sync point.
  Add a link to the new `docs/biometrics/active-rr-source.md` for the upstream policy.
  Update "Границы владения" to show `SwitchableTickService` as the injected `ITickService`, with `ClockTickService` + `HeartRateTickService` as owned children. Do NOT add a "See Also" footer or prev/next nav.

- [x] **Task 8: Create `docs/biometrics/active-rr-source.md`** (depends on Task 7)
  Files: `docs/biometrics/active-rr-source.md`
  New file. Language: Russian (match neighboring `docs/biometrics/` files). Cover the four topics from the spec:
  1. **Две политики потребления RR.** `BioStreamRouter` (Phase 21) — server pipeline, merges every registered source, each sample carries a `source` tag, aggregation happens server-side. `ActiveRrSource` — client pipeline, picks one currently-active source.
  2. **Preferred-with-fallback semantics.** Sources are registered in priority order at `App.initialize()`; index 0 wins. A higher-priority source that revives mid-session steals the active slot on its next interval. Source list is immutable post-construction.
  3. **Silence window formula.** `max(2000ms, lastIntervalMs × 2)` — two beats of silence at the current cadence is the threshold for declaring the active source dead. On silence, walk the list in priority order picking the next source seen within the floor; if none, `hasActiveSource` flips to `false` and the stream goes quiet.
  4. **Artifact policy.** `RrInterval.isArtifact == true` is logged and forwarded as-is in MVP. The single `if (rr.isArtifact)` branch in `_onInterval` is the future filter insertion point. Animation absorbs ±10–20% beat-to-beat variation (respiratory sinus arrhythmia) without smoothing.
  Add a short note that the only consumer today is `HeartRateTickService`, and that the contract supports any heart-driven client UX. No directory tree, no See Also, no prev/next links.

- [x] **Task 9: Append paragraph to `docs/biometrics/capability-sources.md`** (depends on Task 8)
  Files: `docs/biometrics/capability-sources.md`
  Append a single short paragraph (Russian, matching the file) at the end noting that some capabilities — concretely RR-intervals today — are consumed by **two** parallel policies: the server-bound merge policy in `BioStreamRouter`, and the client-side single-active-source policy in `ActiveRrSource`. Link to `active-rr-source.md` as the canonical example of the second policy. Keep it short — one paragraph, no new top-level section header unless the file already uses one (verify by reading the tail of the file before editing).

- [x] **Task 10: Add `docs/biometrics/active-rr-source.md` to the Documentation index in `mind_mobile/CLAUDE.md`** (depends on Task 8)
  Files: `CLAUDE.md` (at `mind_mobile/` repo root)
  Locate the documentation index list under the "## Documentation" heading. Insert a bullet for `docs/biometrics/active-rr-source.md` immediately after the existing `docs/biometrics/capability-sources.md` line (line ~167) and before `docs/biometrics/stream-pipeline.md`. Suggested entry:
  - `` `docs/biometrics/active-rr-source.md` — client-side single-active RR source: preferred-with-fallback policy, silence window, artifact handling ``
  Do NOT touch unrelated documentation rows. Match the existing bullet style exactly.

## Commit Plan
- **Commit 1** (after tasks 1–3): Add heart-tick l10n keys (EN/RU) and regenerate AppLocalizations
- **Commit 2** (after tasks 4–6): Wire heart button in SessionBottomBar.leadingActions and noCardioSource alert handler
- **Commit 3** (after tasks 7–10): Document active RR source, switchable tick service, and update Documentation index

<!-- orchestrator-sessions
planner: 4f6deebe-3c7c-4849-abe7-ac9812316418
elapsed: 1259
implementer: 7b4a7dda-0477-4bb5-8929-53ef19b35283
-->
