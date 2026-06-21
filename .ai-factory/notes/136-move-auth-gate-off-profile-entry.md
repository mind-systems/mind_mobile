# Move the auth gate off the Profile entry

**Date:** 2026-06-21
**Source:** conversation context

## Key Findings

- Today `HomeCoordinator.openProfile()` gates the entry: `GuestState` → `push<AuthResult>(OnboardingScreen.path)` then, on success, `push(ProfileScreen.path)`; authenticated → `push(ProfileScreen.path)`. The auth requirement lives at the entry point.
- Target: the Profile screen is the single entry and is **always** pushed; the guest/authenticated split lives **inside** the screen (note 135). Tapping Profile as a guest opens the profile directly, showing the login action cell. Logging in from there returns to the profile via the existing pop — no return-path logic, because the login cell lives inside the profile.
- Depends on note 135 (the guest variant must exist, otherwise a guest landing on the profile would have nothing meaningful to do / the old dismiss path would fire).
- Other onboarding entry points are **not** touched: `BreathSessionCoordinator` and `BreathSessionListCoordinator` keep their gated-action flow (push Onboarding for a guest, run the action on success). They remain the canonical "auth-gated action" example.

## Details

### Affected files

- `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart` — `openProfile()` becomes just `context.push(ProfileScreen.path)`. Remove the `GuestState` branch. Remove now-unused imports (`AuthState`, `AuthResult`, `OnboardingScreen`). If the `userNotifier` constructor field becomes unused after dropping the branch, remove it from `HomeCoordinator` and its construction site in `lib/HomeModule/HomeModule.dart` (and the `IHomeCoordinator` signature if it declares it) — verify it is not used by any other method first.
- `docs/core/auth-gated-navigation.md` — the canonical example currently shown is exactly `openProfile` with the entry gate; it no longer represents the profile flow. Update it: the profile is always opened directly and gates internally via its login cell. Keep the breath-session "side effect without navigation" example — that pattern is still valid and now the primary illustration of auth-gated actions.

### Guards

- Do **not** modify `BreathSessionCoordinator` / `BreathSessionListCoordinator` — their gated-action flow stays.
- Do **not** reintroduce a return-path/`context.go` scheme — the profile-internal login relies on the existing `push`/`pop` `AuthResult` mechanism (note: the coordinator's `login()` from note 135 does not even read the result; the profile re-renders reactively on pop).
- `flutter analyze` must be clean — no unused imports or dead `userNotifier` wiring left behind.

### Verification

1. Guest taps Profile from Home → the profile opens directly in the guest variant (no Onboarding interstitial at entry).
2. Guest taps the login cell → Onboarding → complete login → returns to the profile, now authenticated.
3. Guest cancels Onboarding → back on the guest profile.
4. Authenticated user taps Profile → opens directly, unchanged.
5. Starring as a guest from a breath session/list still opens Onboarding and runs the action on success (unchanged).

## Open Questions

- None.
