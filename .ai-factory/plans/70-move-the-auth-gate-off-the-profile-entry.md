# Plan: Move the auth gate off the Profile entry

## Context
The Profile screen becomes the single entry point that is always pushed; the guest/authenticated split moves inside the screen (note 135). `HomeCoordinator.openProfile()` stops gating at the entry and just pushes the profile.

## Settings
- Testing: no
- Logging: minimal
- Docs: yes

## Tasks

### Phase 1: Simplify the coordinator

- [x] **Task 1: Make `openProfile()` always push Profile**
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`
  Replace the body of `openProfile()` with a single `context.push(ProfileScreen.path);`. Remove the `GuestState` branch and the `OnboardingScreen` / `AuthResult.success` push-then-push logic. The screen now gates internally via its login cell (note 135), so no return-path handling is needed.

- [x] **Task 2: Remove now-unused `userNotifier` field and dead imports** (depends on Task 1)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`
  After Task 1, `userNotifier` is used by no other method in this class (verified: only referenced in the old `openProfile` gate). Drop the `final UserNotifier userNotifier;` field and the `{required this.userNotifier}` constructor parameter. Remove the now-unused imports: `AuthState.dart` (`GuestState`), `AuthResult.dart` (`AuthResult`), `OnboardingScreen.dart` (`OnboardingScreen`), and `UserNotifier.dart`. Keep `ProfileScreen`, `go_router`, and the other screen imports. Do not touch `IHomeCoordinator` — it does not declare `userNotifier`.

- [x] **Task 3: Drop `userNotifier` from `HomeCoordinator` construction** (depends on Task 2)
  Files: `lib/HomeModule/HomeModule.dart`
  Update the `HomeCoordinator(context, userNotifier: App.shared.userNotifier)` construction to `HomeCoordinator(context)`. Leave the `HomeService` wiring (which also uses `App.shared.userNotifier`) untouched — only the coordinator argument changes.

### Phase 2: Documentation

- [x] **Task 4: Update auth-gated-navigation doc** (depends on Task 1)
  Files: `docs/core/auth-gated-navigation.md`
  The "Навигация после логина" example currently shows `openProfile` with an entry gate — it no longer represents the profile flow. Remove/replace that example: state that the profile is always opened directly and gates internally via its login cell. Keep the "Side effect без навигации" (breath-session star) example as the canonical illustration of an auth-gated action, since `BreathSessionCoordinator` / `BreathSessionListCoordinator` are unchanged. Preserve the surrounding sections (`AuthResult`, "Почему не context.go", "Двойной pop"). Match the existing Russian language of the doc.

### Phase 3: Verification

- [x] **Task 5: Confirm clean analyze** (depends on Tasks 1-3)
  Files: (no edits)
  Run `/usr/local/bin/flutter analyze` and confirm no unused imports, no dead `userNotifier` wiring, and no other errors introduced. Do NOT modify `BreathSessionCoordinator` / `BreathSessionListCoordinator` — their gated-action flow stays.
