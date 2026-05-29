# Code Review — M6: `toggleHeartTickSource()` + `sourceChanges` subscription + `noCardioSource` UI event

**Plan:** `.ai-factory/plans/78-add-toggleheartticksource-sourcechanges-subscription-nocardiosource-ui-event-to-breathviewmodel.md`
**Files changed:**
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` (modified)
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (modified)

## Scope of review

Read both modified files in full, compared against `ITickService` (`packages/breath_module/lib/src/ITickService.dart`), `SwitchableTickService` (`lib/BreathModule/SwitchableTickService.dart`, M4 spec), `BreathSessionState` (`packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`), and the spec in `.ai-factory/notes/29-heart-rate-tick-source.md` Milestone 6. No other files in the working tree were touched; `git diff HEAD` and `git status` are consistent with the plan.

## Verification of each task

- **Task 1 (enum rename + new variant):** `enum BreathSessionUiEvent { starFailed, noCardioSource }` correctly replaces the prior `BreathSessionError`. The field is renamed `onUiEvent` with signature `void Function(BreathSessionUiEvent event)?`. The single internal emit site in `toggleStar()` (line 304) is updated. No other production code referenced `BreathSessionError`/`onErrorEvent` for this VM (verified — `BreathSessionListViewModel` and `LoginViewModel` keep their own unrelated enums).
- **Task 2 (screen callsite):** `BreathSessionScreen.dart:99` correctly renames to `viewModel.onUiEvent = (_) { ... }` and adds the explanatory `// noCardioSource handled in M7` comment.
- **Task 3 (subscription + import):** New `import '../CommonModels/TickSource.dart';` added (line 5); `StreamSubscription<TickSource>? _sourceChangesSub;` declared (line 32); subscription created inside `initState()` after `_setupEngine(dto)` and before the other two subscriptions (lines 112–114). Subscription writes `state = state.copyWith(tickSource: src)` — exactly what the spec asks for.
- **Task 4 (dispose):** `_sourceChangesSub?.cancel();` placed in the `ref.onDispose` block (line 71), between the other subscription cancellations and `_stateMachine?.dispose()`, matching the existing ordering convention.
- **Task 5 (toggle method):** `toggleHeartTickSource()` (lines 283–293) computes the target, calls `tickService.trySwitchTo(target)` directly on the `ITickService` interface (no cast), and fires `onUiEvent?.call(BreathSessionUiEvent.noCardioSource)` when the switch is rejected. `state.tickSource` is not written from inside the method — single sync point is preserved.

## Correctness analysis

- **Interface contract honored.** `ITickService` exposes both `Stream<TickSource> get sourceChanges` and `bool trySwitchTo(TickSource target)`, so the implementation needs no cast — confirmed in `packages/breath_module/lib/src/ITickService.dart:8–13`. The plan's "no cast" requirement is satisfied.
- **`state.copyWith(tickSource: ...)` will publish through Riverpod.** `BreathSessionState.equalsIgnoringTickFields` includes `tickSource` (line 108), so a change in `tickSource` is not classified as a tick-only update — `super.state = value` runs and Riverpod consumers (the future heart icon selector) will rebuild. This is the intended behavior.
- **Initial value sync is safe.** `_setupEngine` seeds `state.tickSource = tickService.source` synchronously before the subscription is created. `SwitchableTickService` emits on `sourceChanges` only on actual switches (never for the initial source), so no missed initial emit — the seed in `_setupEngine` is the entire source-of-truth for the initial value, and the subscription handles every change thereafter.
- **Subscription lifetime.** Created once in `initState()` (not in `_setupEngine`), so re-entries via `service.observeSession(sessionId).listen` (which re-runs `_setupEngine`) do not stack subscriptions. Canceled in `ref.onDispose` before `tickService.dispose()` — correct ordering (cancel-then-dispose).
- **Error-path safety.** If `service.getSession(sessionId)` throws, control jumps to the catch block before the subscription is created. `_sourceChangesSub` stays null; `cancel()` on null is a no-op via the `?.` operator. `tickService.dispose()` still runs in `ref.onDispose`. No leak.
- **Double-tap behavior.** A second `toggleHeartTickSource()` call before the first `sourceChanges` event drains finds `state.tickSource` still showing the old value, so the computed `target` is the same as the just-issued switch. `SwitchableTickService.trySwitchTo` short-circuits with `return true` when `target == _activeSource` (no re-emit, no `onUiEvent`), so the second tap is a silent no-op. Net effect: rapid double-tap switches once instead of toggling twice. Not a bug per the spec, but it is a UX subtlety worth knowing — once M7 wires the button, fast double-taps will net to "switched", not "no change".

## Findings

### Minor

1. **`noCardioSource` will surface as a generic error snackbar if invoked before M7.**
   File: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart:99–104`.
   The handler uses a `(_)` discard, so both `starFailed` and `noCardioSource` route to the red `SnackBarEvent.error(...error)` snackbar with the localized "Error" string. There is no UI hook into `toggleHeartTickSource()` in this milestone (no button is wired until M7), so this is not user-reachable in production. However, anyone manually calling `viewModel.toggleHeartTickSource()` during testing (e.g. a debug button, hot-reload experimentation, devtools) without a cardio source will get a misleading "Error" snackbar rather than the intended `AppAlert`. The inline `// noCardioSource handled in M7` comment correctly flags this for the next milestone author. Acceptable for M6.

2. **`SwitchableTickService.trySwitchTo` calls outside this module rely on milestone-5 wiring.**
   File: `lib/BreathModule/BreathModule.dart` (not modified in this milestone).
   `toggleHeartTickSource()` will throw at runtime if `tickService` is not a `SwitchableTickService` — e.g. a unit test that injects a stub `ITickService` whose `trySwitchTo` is unimplemented or whose `sourceChanges` is a closed stream. The current production wiring (M5) always injects a `SwitchableTickService`, so no production runtime risk. Worth flagging only for future test authors.

3. **No null-safety issue, but a subtle ordering note.**
   File: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart:107–125`.
   The `_sourceChangesSub` assignment lives inside the `try` block alongside the other two subscriptions. If `service.getSession(sessionId)` succeeds but `tickService.sourceChanges` somehow throws synchronously during `.listen(...)` (it does not for `StreamController.broadcast`, but in theory a stub could), the catch path sets `loadState: error` and leaves `_sessionUpdateSubscription`/`_sessionDeletionSubscription` null — correct, though the partial setup means the VM is in a half-initialized state. Not actionable; spec-compliant; mentioned only as a completeness check.

### Nits (not blocking)

- The new import on line 5 (`import '../CommonModels/TickSource.dart';`) sits between the two third-party imports group and the local-relative imports group. Existing style in the file already mixes `../` imports with `./` imports, so this is consistent; no change requested.
- The terminating comment inside `toggleHeartTickSource()` (lines 291–292) is explanatory rather than describing non-obvious behavior. It is borderline per the project's "no comments unless WHY is non-obvious" rule, but the rationale (single sync point, covers auto-fallback too) is genuinely non-obvious from the code alone and matches the spec's emphasis. Keep as-is.

## What was checked and is fine

- No new `App.dart` touchpoints — RULES.md rule about App.dart infrastructure isolation is honored.
- No new module Service state — the ViewModel is the correct owner of this subscription per the RULES.md "stateless Services" rule.
- All dependencies still injected via constructor — no out-of-band wiring introduced.
- No proto, DB, migration, or auth changes — no cross-project coordination required.
- `flutter analyze` should be clean: enum rename is fully scoped to two files; no dangling references to `BreathSessionError` or `onErrorEvent` in this VM's call graph (verified via grep — every remaining match is on `BreathSessionListViewModel` / `LoginViewModel` / docs / notes).

## Verdict

No critical issues, no architectural mistakes, no missing steps. Minor findings #1 and #2 are forward-looking notes for M7 and test wiring respectively; neither blocks this milestone.

REVIEW_PASS
