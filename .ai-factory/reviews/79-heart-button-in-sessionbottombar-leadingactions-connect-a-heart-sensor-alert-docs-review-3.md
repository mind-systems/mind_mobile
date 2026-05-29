# Review 3: Heart button in SessionBottomBar.leadingActions + alert + docs

Third-pass review. Staged tree is unchanged since review-1 / review-2 — the only new file in `git status` is `review-2.md` itself. Independent re-walk of every changed file in full.

## Code

### `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`

- Heart `Consumer` (lines 333–345): correct `select` scope on `s.tickSource`, stable `viewModel` capture from `ref.read(breathViewModelProvider.notifier)` (Riverpod notifier identity guarantee), spec-matching colors (`Colors.red` active, `Colors.white.withValues(alpha: 0.3)` inactive), no disabled state. Button is appended at index 1 of `leadingActions`, mute remains at index 0.
- Exhaustive Dart-3 switch over `BreathSessionUiEvent` (lines 100–114): valid syntax for `sdk: '>=3.7.0 <4.0.0'`. No `default` branch — future variants will fail the analyzer. The `starFailed` branch preserves the original snackbar behavior verbatim.
- `AppAlert` reaches the screen via the already-present `package:mind_ui/mind_ui.dart` import (re-export at `packages/mind_ui/lib/mind_ui.dart:7`). No deep import added — module boundary preserved.
- `TickSource` imported from `../CommonModels/TickSource.dart` (line 7), consistent with the existing `SetShape` import on the next line.

### `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` (context only — unchanged this milestone)

- `toggleHeartTickSource` reads `state.tickSource` to compute the toggle target, calls `tickService.trySwitchTo(target)`, fires `onUiEvent?.call(BreathSessionUiEvent.noCardioSource)` on failure. The actual `state.tickSource` write happens in the `_sourceChangesSub` listener — single sync point covers both manual toggle and watchdog auto-fallback. Dispose order in `build()`'s `ref.onDispose` cancels `_sourceChangesSub` before disposing `tickService`. Clean.
- Theoretical race (mid-fallback tap) computes a stale target; worst case is a no-op `trySwitchTo(true)` followed by the reconciling `sourceChanges` event. No corrupted state, no missed alert when one was warranted.

### l10n

- `app_en.arb` and `app_ru.arb` both carry `heartTickNoSourceTitle` and `heartTickNoSourceDescription` with the exact spec strings, placed identically after `comingSoon`.
- Generated `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart` expose matching getters with consistent strings. No hand-edits.

### Wiring sanity

- `ITickService` declares `sourceChanges` and `trySwitchTo` (`packages/breath_module/lib/src/ITickService.dart:8,13`). All five test fakes plus `SwitchableTickService`, `ClockTickService`, `HeartRateTickService` implement them. No compile breakage.
- `BreathModule.buildSession()` (`lib/BreathModule/BreathModule.dart:32–34`) creates Clock + Heart + Switchable and injects the Switchable as `ITickService`. `App.shared.activeRrSource` (`lib/Core/App.dart:195, 90, 117, 224`) is the singleton consumed by `HeartRateTickService`.
- `BreathSessionState.initial()` defaults `tickSource: TickSource.timer` — heart icon renders dim/inactive before `_setupEngine` runs. Correct.

## Runtime / correctness

- No bugs, security issues, type mismatches, or migrations affected.
- No new race conditions introduced by this milestone beyond the harmless mid-fallback-tap window analyzed above.
- No memory or subscription leaks — the new `Consumer` is a `StatelessWidget` Flutter widget without its own subscriptions; the VM's `_sourceChangesSub` is cancelled in `ref.onDispose` (`BreathSessionViewModel.dart:71`).

REVIEW_PASS
