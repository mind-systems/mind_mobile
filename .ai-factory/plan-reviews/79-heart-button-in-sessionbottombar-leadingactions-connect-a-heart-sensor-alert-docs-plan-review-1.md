# Plan Review: Heart button in SessionBottomBar.leadingActions + alert + docs

## Code Review Summary

**Files Reviewed:** 1 plan covering 10 tasks across 3 phases (ARB, screen wiring, docs).
**Risk Level:** 🟢 Low

The plan is tightly aligned with the M7 notes in `.ai-factory/notes/29-heart-rate-tick-source.md` and matches the actual codebase: `BreathSessionScreen.dart` (placeholder lines 99–104), `BreathSessionViewModel.toggleHeartTickSource()`, `SwitchableTickService`, `HeartRateTickService`, and `ActiveRrSource` are all in the state the plan assumes. l10n keys do not yet exist in EN/RU ARB files. The `AppAlert` symbol is exported by `mind_ui` and already visible through the existing `package:mind_ui/mind_ui.dart` import. `TickSource` is re-exported by `breath_module.dart`.

### Context Gates

- **ARCHITECTURE.md** — gate not enforced in detail; no obvious boundary violations. Service/coordinator pattern preserved. WARN: none.
- **RULES.md** — three rules: stateless module Services, no module state in App.dart, constructor-injected dependencies. None of Tasks 1–10 touch a Module Service, App.dart, or DI wiring. ✅ No violations.
- **ROADMAP.md** — milestone alignment: this is documented as "Phase 22 M7 — final UI/UX wiring for the heart-rate tick source," which matches the M7 spec in notes/29. ✅

### Critical Issues

_(None — no blocking findings.)_

### Minor Issues / Suggestions

1. **Task 5 — no `mounted` guard before `AppAlert.show(context, …)`.**
   The replacement `onUiEvent` lambda captures the State's `context` and is fired asynchronously from `viewModel.toggleHeartTickSource()`. If the lambda ever fires after the screen is disposed (e.g. user backgrounded the app mid-tap), calling `AppLocalizations.of(context)!` and `showDialog` will throw. The existing `starFailed` branch has the same latent issue, so this is **not a regression**, but the new path opens a dialog (more visible failure mode than a snackbar). Consider adding `if (!mounted) return;` at the top of the lambda. Not blocking — current code in the repo already follows the unguarded pattern.

2. **Task 5 — `viewModel.onUiEvent` is not cleared in `dispose()`.**
   The existing code does not null it either, so this is consistent with the prior pattern; only worth flagging if the project later refactors VM lifetime. Not blocking.

3. **Task 9 — paragraph placement at end of `capability-sources.md`.**
   The file currently ends with `См. [docs/biometrics/stream-pipeline.md](stream-pipeline.md) — …`. Appending the new paragraph **after** this line will visually orphan the existing "see" reference. Recommend the implementer insert the new paragraph **before** that final `См.` line so the inline reference remains the last thing in the file. The plan instruction "Append a single short paragraph … at the end" should be relaxed to "append before the trailing `См.` link." Cosmetic, not blocking.

4. **Task 4 — explicit `TickSource` import.**
   The plan correctly notes "add an explicit import only if the screen file does not already see it via existing imports." Confirmed by inspection: `BreathSessionScreen.dart` currently imports `BreathSessionViewModel.dart` (which imports `TickSource` transitively, but Dart imports are not transitive). The implementer must add `import '../CommonModels/TickSource.dart';` (relative — already used for `SetShape`) or rely on the package-internal path. The plan leaves the form to the implementer, which is acceptable.

5. **Task 3 — codegen specifics.**
   The plan says "typically `flutter gen-l10n` from inside `packages/mind_l10n`." This is the right intent. The implementer should ensure that whatever build invocation the package uses (there is an `l10n.yaml` convention or a `gen-l10n` step) does not regress generated header comments or trailing-newline handling. Not blocking — verifiable by running the analyzer.

6. **Task 7/8 — language rule.**
   Plan correctly requires Russian to match neighboring docs (matches the global "Match the language of existing docs" rule). ✅

7. **Doc rules check.**
   - No directory trees in the new file → explicitly required by plan ✅
   - No "See Also" section → required ✅
   - No prev/next nav → required ✅
   - Describe behavior, not code → the topic list in Task 8 (4 numbered topics) is behaviorally framed (policies, semantics, formulas, artifact handling). ✅

### Verified Codebase Assumptions

- **Lines 99–104 of `BreathSessionScreen.dart`** — exactly the placeholder the plan describes. ✅
- **`SessionBottomBar(...)` call site at ~line 304** — confirmed; mute is the only entry in `leadingActions` today. ✅
- **`BreathSessionUiEvent` enum** — `{ starFailed, noCardioSource }`, defined in `BreathSessionViewModel.dart` line 13. Two-case switch in plan is exhaustive. ✅
- **`viewModel.toggleHeartTickSource()`** — exists; correctly calls `tickService.trySwitchTo(target)` and emits `noCardioSource` on `false`. Does NOT mutate `state.tickSource` directly — single sync point via `_sourceChangesSub`. ✅
- **`tickService.sourceChanges`** — provided by `SwitchableTickService`; auto-fallback via `hasActiveSourceStream` is wired. ✅
- **`AppAlert.show(context, title:, description:)`** — signature matches; OK button auto-provided. ✅
- **`globalSnackBarNotifierProvider` / `SnackBarEvent.error`** — exported from `mind_ui`. ✅
- **`TickSource` enum** — `{ heartbeat, timer }`, re-exported from `breath_module.dart`. ✅
- **`CLAUDE.md` Documentation index** — `docs/biometrics/capability-sources.md` is at line 167; insertion point in Task 10 is correct. ✅
- **L10n keys do not yet exist** in `app_en.arb` or `app_ru.arb`. ✅

### Positive Notes

- Clear task ordering with explicit dependencies between tasks (1→2→3→…).
- Codegen step (Task 3) correctly placed before screen wiring — no broken intermediate compile state.
- Doc plan explicitly references the global CLAUDE.md rules (Russian language match, no See Also, no nav links, no directory tree).
- Exhaustive switch (no `default`) over `BreathSessionUiEvent` — correctly leverages Dart analyzer to enforce future-event coverage.
- Single-sync-point invariant for `state.tickSource` (only updated via `sourceChanges`) is preserved by the chosen implementation strategy.
- Commit plan (3 commits aligned with the 3 phases) is sensible and atomic.
- Visual rules (red active, white 30% inactive, always tappable) exactly mirror the M7 spec rationale.

PLAN_REVIEW_PASS
