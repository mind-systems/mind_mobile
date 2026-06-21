# Code Review: Move the auth gate off the Profile entry

**Plan:** `.ai-factory/plans/70-move-the-auth-gate-off-the-profile-entry.md`
**Reviewed:** `git diff HEAD` + full read of all changed files and the gating dependency (`ProfileScreen`, `ProfileViewModel`)
**Risk:** 🟢 Low — deletion-only behavioral simplification

## Changes Reviewed

- `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart` — `openProfile()` reduced to `context.push(ProfileScreen.path)`; `userNotifier` field + ctor param removed; `AuthState`, `AuthResult`, `OnboardingScreen`, `UserNotifier` imports dropped.
- `lib/HomeModule/HomeModule.dart` — construction updated to `HomeCoordinator(context)`.
- `docs/core/auth-gated-navigation.md` — entry-gate `openProfile` example replaced with a description of always-push + internal gating; breath-session side-effect example kept as canonical.

## Correctness Verification

1. **Internal gating premise holds.** `ProfileScreen.dart:31` branches on `state.isAuthenticated`, rendering a login cell (`viewModel.onLoginTap` → `coordinator.login()`) for guests and the account cells otherwise. A guest pushed straight to the profile lands on a meaningful screen — no dismiss/empty-state regression.
2. **Reactive re-render after login works.** `ProfileViewModel.build()` subscribes to `service.observeProfile()`; on `AuthenticatedState` the service emits `ProfileLoaded`, flipping `isAuthenticated: true` (`ProfileViewModel.dart:40-41`). Logging in from the profile (via the existing `push`/`pop` `AuthResult` mechanism inside `ProfileCoordinator.login()`) re-renders the same screen authenticated, with no return-path logic — exactly as the plan/spec intends.
3. **No dead references.** Grep confirms `userNotifier` no longer appears in `HomeCoordinator`. The four removed imports are unused elsewhere in the file. `IHomeCoordinator` never declared `userNotifier`, so it correctly stays untouched.
4. **Single construction site.** `HomeCoordinator(...)` is instantiated only at `HomeModule.dart:19`; no tests or other callers construct it. `HomeService`'s independent `App.shared.userNotifier` is left intact.
5. **Guards respected.** `BreathSessionCoordinator` / `BreathSessionListCoordinator` are not touched; the gated-action flow remains the canonical doc example.
6. **Analyzer clean.** `flutter analyze lib/HomeModule lib/ProfileModule` → "No issues found!" — no unused imports or dead wiring.

## Runtime Risk Assessment

- No type mismatches, no migrations, no async/race concerns. `context.push` is the same call already used by the authenticated branch, so the `/profile` route + its `ProviderScope` override is already proven to resolve.
- Documentation change is prose/example only; no behavioral impact.

## Findings

None.

REVIEW_PASS
