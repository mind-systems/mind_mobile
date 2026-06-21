# Plan Review: Move the auth gate off the Profile entry

**Plan:** `.ai-factory/plans/70-move-the-auth-gate-off-the-profile-entry.md`
**Files Reviewed:** 6 (plan, HomeCoordinator, HomeModule, ProfileScreen, ProfileViewModel, doc) + notes 135/136 + ROADMAP
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — not read in depth; the change is a coordinator-only simplification that respects the existing Coordinator pattern (navigation/side-effects stay in the coordinator). No boundary or DI-layering violation introduced.
- **Rules (`.ai-factory/RULES.md`):** PASS — no convention conflicts detected. The change removes code rather than adding new patterns.
- **Roadmap (`.ai-factory/ROADMAP.md`):** PASS — the plan maps 1:1 to milestone line 235 ("Move the auth gate off the Profile entry", spec note 136), which depends on the already-completed line 233 (note 135). Linkage is explicit and correct.

## Verification of Plan Assumptions (all confirmed)

1. **Internal gating already exists.** `ProfileScreen.dart` branches on `state.isAuthenticated` (line 31) and renders a login action cell (`viewModel.onLoginTap`) for guests. `ProfileViewModel.onLoginTap()` → `coordinator.login()` (pushes Onboarding, re-renders reactively on pop). Note 135 is fully implemented. ⇒ The core premise — "the screen now gates internally" — holds. No guest-exposure regression.
2. **`userNotifier` is used only by `openProfile`.** Grep confirms references in `HomeCoordinator.dart` only at lines 15 (field), 16 (ctor), 29 (the gate). After Task 1, the field is genuinely dead. ✓
3. **Imports to drop are not used elsewhere.** `GuestState` (line 30), `AuthResult` (line 32), `OnboardingScreen` (line 31), `UserNotifier` (lines 10/15) appear nowhere else in the file. `ProfileScreen`, `go_router`, and the `*_module` imports stay used. ✓
4. **Only one construction site.** `HomeCoordinator(...)` is instantiated solely in `HomeModule.dart:19`. No tests or other callers construct it, so Task 3 is the complete wiring change. ✓
5. **`IHomeCoordinator` does not declare `userNotifier`.** Confirmed — the interface lists only the five methods. The plan's instruction to leave it untouched is correct (and matches note 136's conditional "if it declares it").
6. **`HomeService` keeps its own `App.shared.userNotifier`.** Independent of the coordinator field; Task 3 correctly leaves it alone.
7. **Guard targets unchanged.** `BreathSessionCoordinator` / `BreathSessionListCoordinator` are not referenced by any task; the gated-action flow stays as the canonical doc example.

## Critical Issues

None.

## Minor Observations (non-blocking)

- **Doc Task 4 — surrounding sections stay coherent.** The plan preserves "Почему не context.go" and "Двойной pop при email-логине". These still describe a live path: `ProfileCoordinator.login()` pushes Onboarding, which pushes LoginScreen, and the double-pop on `AuthenticatedState` still occurs. Keeping them is correct; just ensure the rewritten "Навигация после логина" example no longer implies the *coordinator* reads `AuthResult` (per note 135, `ProfileCoordinator.login()` ignores the result and relies on reactive re-render). A one-line clarification there would make the doc fully accurate.
- **No routing change needed.** `ProfileScreen.path` (`/profile`) is already the route pushed by today's authenticated branch, so the always-push path is already proven to resolve its `ProviderScope` override. Correctly out of scope.
- **Settings alignment.** Plan declares `Testing: no` — consistent with note 136 (no test tasks) and the repo's no-test stance for this change. Logging minimal / Docs yes both honored by the task list.

## Positive Notes

- Tasks are correctly ordered with explicit dependencies (1→2→3, 4 after 1, 5 after 1–3).
- Each deletion is justified against an actual usage check rather than assumed, matching what grep confirms.
- Scope guards (don't touch breath coordinators, don't touch `IHomeCoordinator`, don't touch `HomeService` wiring) are precise and match the spec.
- Verification task (`flutter analyze` for unused imports / dead wiring) is the right closing gate for a deletion-heavy change.

PLAN_REVIEW_PASS
