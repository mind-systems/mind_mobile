# Review 2: Heart button in SessionBottomBar.leadingActions + alert + docs

Second-pass review. Staged tree is byte-identical to review-1 (no follow-up commits — same set of changes in `git status` and `git diff HEAD`). This pass independently re-walks every file in full and looks for anything review-1 missed.

## Code

### `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`

- Switch over `BreathSessionUiEvent` (lines 100–114) is well-formed for Dart 3 (sdk constraint `>=3.7.0 <4.0.0` in `packages/breath_module/pubspec.yaml`). Case bodies without explicit `break` are valid; the analyzer's no-fall-through rule is satisfied. Exhaustiveness checking will flag any future variant.
- Heart `Consumer` (lines 333–345) is wired correctly. `select((s) => s.tickSource)` narrows the rebuild scope to a field that mutates only on `sourceChanges` events (manual toggle / auto-fallback) — not on per-tick state churn. `viewModel` captured from `ref.read(breathViewModelProvider.notifier)` at line 170 is the same notifier instance across rebuilds (Riverpod guarantee), so the `toggleHeartTickSource` tear-off is stable.
- `TickSource` import via direct package-internal path (`../CommonModels/TickSource.dart`, line 7) is consistent with how `SetShape` is imported on the next line; no breakage.
- `AppAlert` resolves via the already-imported `package:mind_ui/mind_ui.dart` (re-export at `packages/mind_ui/lib/mind_ui.dart:7`). Module boundary preserved.
- `BreathSessionState.initial()` defaults `tickSource: TickSource.timer` (`Models/BreathSessionState.dart:57`), so the heart icon renders dim before `_setupEngine` runs — correct.
- Pre-existing risk (NOT a milestone-79 regression): `onUiEvent` is a closure over `context` and `ref`; if invoked after the State unmounts (e.g. the `starFailed` branch fires after the `toggleStar` `await` while the screen pops), it would touch a disposed context. The original code had the same exposure; no new path is added by this milestone. Worth a follow-up `mounted` guard but not blocking.

### `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` (read for context, unchanged this milestone)

- `toggleHeartTickSource` reads `state.tickSource` to compute the target, then calls `tickService.trySwitchTo(target)`. Theoretical race: between an auto-fallback emitting on `sourceChanges` and the VM's listener writing `state.tickSource`, a user tap would compute `target` from stale state. Worst case: a no-op `trySwitchTo` returns `true` without firing `noCardioSource`, and the next `sourceChanges` event reconciles `state.tickSource` to the truth. No corrupted state, no missed alert when one was warranted. Acceptable.

### l10n

- Both ARB files (`app_en.arb`, `app_ru.arb`) carry `heartTickNoSourceTitle` and `heartTickNoSourceDescription` with the exact spec strings, placed after `comingSoon` in both files.
- Generated `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart` expose matching getters. No hand-edits in the generated files.

### Tests (out of scope, sanity check only)

- All five test fakes implementing `ITickService` already declare `sourceChanges` and `trySwitchTo` (added in milestone 76/78). No compile breakage from this milestone.

## Docs

### `docs/breath/session/tick-sources.md`

Two factual inaccuracies remain (both unchanged from review-1):

1. **Ownership diagram, lines 70–71** says `ClockTickService` and `HeartRateTickService` are "(создаётся внутри SwitchableTickService)". The actual wiring in `lib/BreathModule/BreathModule.dart:32–34` creates `clock` and `heart` directly in `BreathModule.buildSession()` and injects them into `SwitchableTickService` via constructor. The facade owns `dispose()` but does not construct them. Suggested fix: replace "(создаётся внутри SwitchableTickService)" with something like "(создаются в BreathModule.buildSession() и инжектируются в фасад, который владеет dispose())".

2. **Ownership diagram, line 74** still says `tickService.ticks → BreathSessionStateMachine`. `ITickService` exposes the stream as `tickStream` (`packages/breath_module/lib/src/ITickService.dart:4`). Pre-existing typo, but the milestone rewrote this exact diagram and could have fixed it inline.

### `docs/biometrics/active-rr-source.md`

Accurate against `lib/Biometrics/ActiveRrSource.dart` and `lib/Core/App.dart:195` (`final activeRrSource = ActiveRrSource([bciProvider])`). All four spec topics covered. No structural problems.

### `docs/biometrics/capability-sources.md`

Appended paragraph at line 39 has an awkward em-dash chain that reads like an unfinished edit:

> «...выбирает ровно один активный источник для клиентского UX — текущий экземпляр — привод дыхательного движка от пульса.»

The phrase "текущий экземпляр" (current instance) doesn't grammatically agree with "привод" (driver) as a parenthetical insertion. Suggested rewording: «...для клиентского UX — сегодня единственный потребитель — привод дыхательного движка от пульса». Minor copy-edit issue.

### `CLAUDE.md`

Index entry on line 168 is correctly placed and formatted.

## Summary

No correctness, security, or runtime bugs in the code changes.

Carry-over doc nits from review-1 that still warrant a small cleanup before merge:

1. `tick-sources.md` line 70–71: wrong claim about Clock/Heart construction location.
2. `tick-sources.md` line 74: `tickService.ticks` should be `tickService.tickStream`.
3. `capability-sources.md` line 39: awkward em-dash phrasing.

All non-blocking — code can ship as-is; the three doc cleanups are minor polish.
