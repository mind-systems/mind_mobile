# Code Review: Make the Profile screen guest-aware

**Plan:** `69-make-the-profile-screen-guest-aware-render-both-variants-stop-dismissing-on-guest.md`
**Scope reviewed:** the Profile-related code changes (DTOs, state, service, view model, coordinator, screen, l10n).

## Summary

The implementation matches the plan and is correct. All seven tasks landed:
the `ProfileSessionExpired` → `ProfileGuest` rename, the `isAuthenticated` flag on `ProfileState`, the synchronous service getter, the continuous bidirectional `observeProfile()`, the seed-and-flip view model, the `dismiss()` → `login()` coordinator swap, the screen branching, and the `logIn` ARB key + regenerated localizations.

I verified the runtime-critical assumptions against the real code rather than the plan's claims:

- `UserNotifier.currentState` (`lib/User/UserNotifier.dart:39`) and `UserNotifier.stream` (line 33) both exist and are backed by a seeded `BehaviorSubject<AuthState>`. So `service.isAuthenticated` reads a real synchronous value, and `observeProfile()` replays the current auth state on subscribe — the synchronous seed in `build()` is purely flash-prevention, exactly as intended.
- `AuthState` is a sealed hierarchy of exactly `GuestState` / `AuthenticatedState`, both exposing `.user`. The `if (s is GuestState) ProfileGuest() else ProfileLoaded(...)` rewrite is exhaustive and safe; `s.user.name` in the `else` branch resolves on `AuthenticatedState`.
- Removing `import 'package:rxdart/rxdart.dart';` from `ProfileService.dart` is correct — the only rxdart-specific API used (`mergeWith`) is gone; `.map` is a plain `Stream` method. No unused-import or missing-symbol risk.
- No leftover references to `ProfileSessionExpired` or a Profile `dismiss()` caller anywhere in `lib/`. The only `IProfileService` / `IProfileCoordinator` implementers are the two concrete classes, both updated. No test fakes implement these interfaces, so the interface additions/removals break nothing.

## Behavior verification (traced through the code)

- **Logout while on Profile:** `onLogoutTap` → `userNotifier.logout()` emits `GuestState` → `observeProfile()` emits `ProfileGuest` → `_onEvent` sets `isAuthenticated: false`. No `dismiss`/pop — the screen flips in place. Correct, and this is the milestone's observable value.
- **Login from guest variant:** `onLoginTap` → `coordinator.login()` pushes Onboarding. On success `UserNotifier` emits `AuthenticatedState` → `ProfileLoaded` → state flips to authenticated; Onboarding then pops back to the still-mounted Profile. The flip is driven by the observable, not by the pop, so it works regardless of how Onboarding returns. Onboarding/`LoginScreen` pop behavior is untouched, per the guard.
- **Screen composition:** the `children` list omits the MCP and Session/logout sections entirely for guests (no empty headers), and keeps Appearance + version footer for both variants. Guest Account section shows a single `SettingsCell(title: Text(l10n.logIn), onTap: viewModel.onLoginTap)`, mirroring the logout cell shape.

## Non-blocking observations

- **Duplicate-ish ARB key.** A `"login"` key already exists (EN `"Login"`, RU `"Войти"`); the new `"logIn"` is EN `"Log in"` / RU `"Войти"` (RU identical). This is a deliberate parallel to the `logOut` action key and reads better as a verb on an action cell, but the two near-identical keys are an easy future trip hazard. Acceptable as-is; just avoid introducing a third spelling later.
- **Stale `userName` after logout.** `ProfileGuest` flips `isAuthenticated` but leaves the prior `userName` in state. Harmless — the guest variant renders no name cell, and the next `ProfileLoaded` overwrites it. No change needed.
- **Out-of-scope changes in the working tree.** The diff also contains unrelated BCI calibration changes (`packages/bci_module/.../BciCalibrationSection.dart` and the `bciPairingCalibrationInstruction` ARB key, which the l10n regen picked up alongside `logIn`). These are not part of this plan and are not reviewed here; just flagging that they ride along in the same uncommitted set, so keep them out of this milestone's commits if the commit plan is to stay clean.

No correctness, security, or runtime defects found in the Profile changes.

REVIEW_PASS
