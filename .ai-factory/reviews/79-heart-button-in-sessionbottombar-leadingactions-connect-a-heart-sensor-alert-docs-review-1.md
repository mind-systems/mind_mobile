# Review: Heart button in SessionBottomBar.leadingActions + alert + docs

Scope: changes staged on `bci-integration` for milestone 79 — heart button in `SessionBottomBar.leadingActions`, `noCardioSource` AppAlert handler, l10n keys, and docs (active-rr-source.md, tick-sources.md rewrite, capability-sources.md paragraph, CLAUDE.md index entry).

## Code changes

### `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`

The Phase 2 wiring is correct:

- Heart `Consumer` is appended as the second entry of `leadingActions` (line 333), after the existing mute `ValueListenableBuilder`. Watch scope is correctly narrowed to `s.tickSource`, so only the icon rebuilds on source changes.
- Visual rules match the spec: `Icons.favorite`, `Colors.red` when `tickSource == TickSource.heartbeat`, `Colors.white.withValues(alpha: 0.3)` otherwise, no disabled state.
- `viewModel.toggleHeartTickSource` is passed as a tear-off — fine, the captured `viewModel` notifier (line 170) is stable for the screen's lifetime.
- `TickSource` is imported directly from `../CommonModels/TickSource.dart` (line 7). That sidesteps the package-export round-trip and is consistent with how the screen already reaches `SetShape`.
- The `onUiEvent` handler is now an exhaustive Dart-3 switch over `BreathSessionUiEvent` (lines 100–114). No `default` branch, so adding a future variant fails the analyzer — desired. Dart-3 switch statements don't fall through implicitly, so the absence of `break` is correct (project targets `sdk: '>=3.7.0 <4.0.0'`).
- The `starFailed` branch preserves the pre-existing snackbar behavior verbatim (same provider, same `SnackBarEvent.error`, same `AppLocalizations.error` key).
- `AppAlert` reaches the screen through the already-present `package:mind_ui/mind_ui.dart` import — `mind_ui.dart` already re-exports `AlertModule/AppAlert.dart`. No deep import added. Module-boundary rule respected.

#### Minor: missing `mounted` guard before `AppAlert.show` and `ref.read`

`onUiEvent` is a captured closure that references `context` and `ref` from the `_BreathSessionScreenState`. It's invoked from `BreathViewModel.toggleHeartTickSource()` (synchronous from the button tap) and from `toggleStar()` (after an `await`, which is where the screen could be disposed mid-flight). Both branches would throw if invoked after the State is unmounted.

This risk is pre-existing for `starFailed` (the original code did the same `ref.read` + `AppLocalizations.of(context)`), so milestone 79 doesn't add a new regression. Worth flagging for a follow-up but not blocking — the practical reachability for `noCardioSource` is synchronous (button tap → `trySwitchTo` → callback), so the State is always mounted at that moment.

### `packages/mind_l10n/lib/l10n/app_en.arb` / `app_ru.arb`

Both keys (`heartTickNoSourceTitle`, `heartTickNoSourceDescription`) are present in both files with the exact spec strings. Placement after `comingSoon` in both files matches. JSON style consistent (two-space indent, comma separation). Regenerated `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart` expose both getters with matching values. l10n codegen output looks correct — no hand-edits visible.

## Doc changes

### `docs/breath/session/tick-sources.md`

Mostly accurate rewrite. Two factual issues:

1. **(minor inaccuracy)** Ownership diagram on lines 70–71 says `ClockTickService` and `HeartRateTickService` are "(создаётся внутри SwitchableTickService)" — but `lib/BreathModule/BreathModule.dart:32-34` creates `clock` and `heart` directly in `BreathModule.buildSession()` and passes them into `SwitchableTickService` via constructor. The facade owns their `dispose()` lifecycle, but it does not construct them. Suggest rewording to "(передаётся в конструктор; владение dispose() — у фасада)" or similar. This is a fresh inaccuracy introduced by this milestone.

2. **(pre-existing inaccuracy carried over)** Line 74 of the ownership diagram still says `tickService.ticks → BreathSessionStateMachine`, but `ITickService` exposes the stream as `tickStream` (see `packages/breath_module/lib/src/ITickService.dart:4`). This was wrong in the original file too, so it's not a regression — but the rewrite missed an opportunity to fix the obviously-wrong member name while touching the same section.

### `docs/biometrics/active-rr-source.md`

New file is accurate against `lib/Biometrics/ActiveRrSource.dart` and the `App.initialize()` wiring (`lib/Core/App.dart:195` — `final activeRrSource = ActiveRrSource([bciProvider])`). All four spec topics covered: two-policy split, preferred-with-fallback, silence-window formula, artifact policy. No directory tree, no See Also, no prev/next nav — global doc rules respected.

### `docs/biometrics/capability-sources.md`

**(minor copy edit)** The appended paragraph at line 39 has a grammatically awkward em-dash chain:

> «...выбирает ровно один активный источник для клиентского UX — текущий экземпляр — привод дыхательного движка от пульса.»

The phrase `текущий экземпляр — привод дыхательного движка от пульса` reads like an unfinished edit — `текущий экземпляр` (current instance) doesn't agree with `привод` (driver) without a connector. Suggest rewording, e.g. «...для клиентского UX — сегодня единственный потребитель — привод дыхательного движка от пульса». Not a blocker.

### `CLAUDE.md`

Index entry inserted between `capability-sources.md` and `stream-pipeline.md` (line 168). Format matches sibling entries — single-line bullet with backticked path and em-dash summary. Correct.

## Runtime / wiring sanity checks

- `BreathSessionState.initial()` defaults `tickSource: TickSource.timer` (`Models/BreathSessionState.dart:57`), so before `BreathViewModel._setupEngine()` runs, the heart Consumer renders the dim/inactive state — correct.
- `BreathViewModel.initState()` (line 112–114) subscribes to `tickService.sourceChanges` and writes incoming values into `state.tickSource`. Cancellation is wired in `build()`'s `ref.onDispose` (line 71) — clean.
- `ITickService` now declares `sourceChanges` and `trySwitchTo` (`packages/breath_module/lib/src/ITickService.dart:8,13`); all in-repo implementors (Switchable, Clock, Heart, and the five test fakes) already implement them. No compile breakage from this milestone.
- `BreathModule.buildSession()` wiring (`lib/BreathModule/BreathModule.dart:32-34`) creates Clock + Heart + Switchable and injects the Switchable as `ITickService` — matches the doc.
- Button position: mute occupies index 0 from Phase 20 M2, heart goes to index 1 — matches spec.

## Summary

- No correctness or security bugs in the code changes.
- Two minor doc inaccuracies in `docs/breath/session/tick-sources.md` (ownership diagram: "созда­ётся внутри" is wrong; pre-existing `tickService.ticks` typo carried over).
- One minor copy-edit nit in the appended paragraph of `docs/biometrics/capability-sources.md`.
- Pre-existing `mounted` guard gap in the `onUiEvent` callback is not a new regression but worth a future follow-up.

Non-blocking — recommend small doc cleanups before merge.
