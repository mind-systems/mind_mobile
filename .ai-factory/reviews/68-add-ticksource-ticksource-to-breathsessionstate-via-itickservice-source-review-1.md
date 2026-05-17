# Code Review: Add `tickSource` to `BreathSessionState` via `ITickService.source`

## Code Review Summary

**Files Reviewed:** 8 (1 interface, 1 model, 1 viewmodel, 1 concrete service, 5 test fakes — note 5th test file was already imported but only 4 from the diff have explicit `TickSource` show clause adjustments; actual changes touch 5 test files per `git status`)
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)**: PASS — change respects the package boundary. `TickSource` enum is declared inside `packages/breath_module/lib/src/CommonModels/`, exported via the barrel, and the concrete `ClockTickService` in `lib/BreathModule/` only depends on the public package surface. Domain models do not leak into the module; the field is added to the package's own `BreathSessionState`.
- **Rules (`.ai-factory/RULES.md`)**: Not present — gate skipped.
- **Roadmap (`.ai-factory/ROADMAP.md`)**: PASS — milestone reference matches; this is preparatory work for the upcoming `BreathSoundCoordinator` milestone.

### Critical Issues

None.

### Findings

None of severity above informational. Notes below are observational, not bugs.

#### Observation 1 — `_onEngineState` carries `state.tickSource` forward (informational)

`packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart:163`

```dart
tickSource: state.tickSource,
```

The plan itself flagged this. Today it is safe because:

1. `_stateMachine!.stateStream.listen(_onEngineState)` is a regular broadcast/single-subscription stream `listen` — events are delivered asynchronously via the microtask queue, so by the time `_onEngineState` first fires, `_setupEngine` has already assigned `state` with `tickSource: tickService.source`.
2. The only `ITickService` implementation today is `ClockTickService`, whose `source` is `TickSource.timer` — identical to the default in `BreathSessionState`'s constructor and `BreathSessionState.initial()`. So even in a hypothetical synchronous emission, the value would coincide.

When `HeartbeatTickService` lands, the safer expression is `tickService.source` directly (sourced from the field that is by definition stable per session). Worth a TODO in the upcoming milestone, but not a fix for this patch.

#### Observation 2 — `BreathSessionState.initial()` still relies on the default

`packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart:60-69`

The factory does not pass `tickSource` explicitly. This is intentional per the plan and uses the constructor default `TickSource.timer`. Acceptable — the field is set to a real value by `_setupEngine` before any UI consumer would care.

### Positive Notes

- All five known `implements ITickService` sites (4 test fakes + `ClockTickService`) are updated. A repository-wide search for `implements ITickService` confirms no fake was missed; no Mocktail/Mockito-based `ITickService` mocks exist.
- `TickSource` is already exported from `packages/breath_module/lib/breath_module.dart`, so the test files' `show TickSource` additions are well-formed.
- The `copyWith` parameter follows the existing pattern; the comment about nullable-field caveats remains accurate (tickSource is non-nullable so `??` works fine).
- `flutter analyze` over all touched files (lib, package, tests) is clean.
- The change is minimal and surgical — no incidental refactors, no unrelated edits.

REVIEW_PASS
