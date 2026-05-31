# Plan Review: Build `MeditationSession` (screen + VM + status stream)

**Plan:** `.ai-factory/plans/95-build-meditationsession-screen-vm-status-stream.md`
**Risk Level:** 🟢 Low

## Summary

The plan is accurate, well-scoped, and faithfully grounded in the actual codebase. Every claimed reference was verified against the real source:

- `ControlButton` (`packages/mind_ui/lib/src/ControlButton.dart`) — confirmed `StatelessWidget` with `icon`, `onPressed`, `destructive`, `iconSize` and **no `size` parameter**. The mandatory `SizedBox(80/80)` + `iconSize: 40` wrapper rationale is correct (the widget expands to fill its parent via `Material`/`InkWell`/`Center`). Exported from `mind_ui.dart`. ✅
- `BreathViewModel` stream mechanism — lines 46–49 (`_stateController` + `stream` getter) and 95–103 (`@override set state`) match the plan's references exactly. The plan correctly drops the tick-cadence filtering (`equalsIgnoringTickFields`) and keeps the `if (!_stateController.isClosed)` guard. ✅
- `BreathSessionScreen` — confirmed `ConsumerStatefulWidget`, `final VoidCallback? onDispose`, `static name/path`, and `dispose()` calling `widget.onDispose?.call()` then `super.dispose()`. The plan correctly omits `WidgetsBindingObserver` (intentional background-recording behavior). ✅
- `MeditationListViewModel`/`MeditationListScreen` — the throw-by-default `NotifierProvider` and `static name/path` patterns the plan mirrors are present as described. ✅
- `meditation_module/pubspec.yaml` — `flutter_riverpod ^3.0.0`, `mind_ui`, `mind_l10n` all already declared; **no dependency changes needed** for this plan. ✅
- No existing `src/MeditationSession/` directory — no file conflicts. ✅
- Plan body exactly matches spec note §B (`.ai-factory/notes/34-meditation-module-impl-specs.md`), which exists. ✅

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN (non-blocking). The architecture defines the ViewModel as the module boundary that receives a Service + Coordinator (as breath and the meditation *list* VM do). The session VM is intentionally created bare (no constructor deps) because the meditation session has no service and channel wiring is deferred to §D. This deviation is explicitly documented in both the plan (Task 2) and spec §B, so it is an accepted, intentional simplification rather than a violation.
- **Rules (`.ai-factory/RULES.md`):** Not present — no rule violations to report.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Clear linkage. The plan implements Phase 25 line 217 ("Build `MeditationSession` (screen + VM + status stream)") verbatim, including the `BreathSessionViewModel.dart:46-49` reference and the deferred §C/§D backend wiring. Milestone alignment confirmed. No missing linkage.

### Critical Issues

None. No missing steps, no wrong codebase assumptions, no incorrect file paths or API usage, no missing migrations (pure presentation-package code — no DB/proto changes in scope), and no security concerns (button drives local Riverpod state only; no I/O, network, auth, or user input).

### Minor Observations (non-blocking)

1. **`IMeditationSessionCoordinator` is unused within this plan's scope.** Task 3 creates the interface, but nothing in Tasks 1–5 injects or calls it — the VM has no coordinator dependency and the screen calls `vm.start()/stop()` directly. This is intentional ("boundary parity," concrete impl in §D per spec §B), but the symbol will be dead until §D wires `close()`. Implementer should not try to inject it into the VM. Consider a brief `// wired in §D` comment to prevent confusion.

2. **Barrel export ordering.** Task 5 lists exports as State → ViewModel → ICoordinator → Screen, whereas the existing `MeditationList` block orders them IService → ICoordinator → State → ViewModel → Screen. Export order is semantically irrelevant in Dart, but for consistency with the existing block, prefer interface(s) → State → ViewModel → Screen.

3. **Throw message wording.** The existing `meditationListViewModelProvider` uses `'MeditationListViewModel must be overridden via ProviderScope'`, while the plan specifies `'must be overridden via ProviderScope'`. Cosmetic only; matching the class-name-prefixed form would be marginally more consistent.

4. **Spec vs plan on the `isClosed` guard.** Spec §B's snippet omits the `if (!_stateController.isClosed)` guard around `_stateController.add(value)`; the plan (Task 2) adds it back to match breath. The plan's version is the safer one — follow the plan, not the spec snippet, here.

### Positive Notes

- Strong copy-from discipline: exact line references that all check out, preventing reinvention.
- Correctly identifies and justifies the non-obvious `SizedBox` wrapper requirement for `ControlButton`.
- Clean scope boundary — defers all channel/backend/route wiring to §C/§D and says so explicitly, avoiding scope creep.
- Sensible commit plan split (model+VM, then screen+interface+barrel) aligned with task dependencies.
- Dependency and file-existence assumptions all verified against the real tree.

PLAN_REVIEW_PASS
