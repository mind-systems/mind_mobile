## Plan Review: Make the Profile screen guest-aware

**Plan:** `69-make-the-profile-screen-guest-aware-render-both-variants-stop-dismissing-on-guest.md`
**Files Reviewed:** 9 source files + plan + research note 135 + ROADMAP
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`ARCHITECTURE.md`)** — WARN/none. The plan respects the layered module boundary: DTO change in `Models/ProfileDTOs.dart`, service implements the interface declared at the module boundary (`IProfileService`), coordinator owns navigation, ViewModel owns the cell-set decision via `ProfileState`. Domain models (`AuthState`) stay behind the service and are converted to DTOs (`ProfileLoaded`/`ProfileGuest`) before crossing into presentation. No layering violations.
- **Rules (`RULES.md`)** — none. No raw `print`/`debugPrint` introduced; navigation stays in the coordinator; `flutter pub add` not needed (no new deps).
- **Roadmap (`ROADMAP.md`)** — PASS. Plan maps 1:1 to Phase 49 milestone "Make the Profile screen guest-aware" (line 233), and correctly leaves the entry-gate change to the separate milestone "Move the auth gate off the Profile entry" (line 235 / note 136). Good linkage.

### Critical Issues

None. All file paths, API signatures, and assumptions check out against the codebase:

- `UserNotifier.stream` is `BehaviorSubject`-backed (replays current value on subscribe), so the plan's claim that `observeProfile()` emits the current status on subscribe — and that the synchronous `build()` seed is just flash-prevention — is correct.
- `AuthState` is a sealed hierarchy with exactly `GuestState` / `AuthenticatedState`, both exposing `.user`. The "branch on state type" rewrite of `observeProfile()` is sound (`s is GuestState ? ProfileGuest() : ProfileLoaded(...)`).
- `dismiss()` in `ProfileModule` has exactly one caller (`ProfileViewModel:42`); the other `dismiss()` hits are in unrelated Breath/Mcp coordinators. Removing it from `IProfileCoordinator` + `ProfileCoordinator` is safe.
- `OnboardingScreen.path` = `/onboarding_screen` exists and is registered; on auth success it `context.pop(AuthResult.success)`, returning to Profile — so the "re-render on pop via the observable" flow holds without any post-navigation callback.
- `SettingsCell` takes `title: Widget` + `onTap` — the proposed guest login cell (`title: Text(l10n.logIn)`, `onTap: viewModel.onLoginTap`) mirrors the existing logout cell exactly.
- l10n codegen: `packages/mind_l10n/l10n.yaml` has `synthetic-package: false` with committed output `lib/l10n/app_localizations*.dart`, so `flutter gen-l10n` from the package dir is the right command (Task 1).
- No existing Profile tests reference `ProfileSessionExpired` / `dismiss()` / `observeProfile`, so the rename causes no test breakage. Consistent with `Testing: no`.

### Minor Notes (non-blocking)

- **Duplicate-ish ARB key.** An entry `"login"` already exists — EN `"Login"`, RU `"Войти"`. The plan adds a new `"logIn"` — EN `"Log in"`, RU `"Войти"` (RU value identical). This is defensible (mirrors the `logOut` action key, and "Log in" as a verb reads better on an action cell than the noun "Login"), but the near-collision is worth a deliberate choice rather than an accident. Either keep the new key (recommended, parallels `logOut`) or reuse `login`; just don't introduce a third spelling later. Verify the existing `login` key isn't expected to serve this exact purpose before duplicating.
- **`userName` staleness after logout.** When the user logs out in place, `ProfileGuest` sets `isAuthenticated: false` but leaves the old `userName` in `ProfileState`. That is harmless because the guest variant omits the name cell, and a subsequent `ProfileLoaded` overwrites it — no action needed, just noting it's intentional.
- **Task 6 wording vs. existing `_onEvent`.** Today `ProfileLoaded` does `copyWith(userName: e.user.name)`; the plan adds `isAuthenticated: true` to the same `copyWith`. Straightforward, no concern.

### Positive Notes

- Correctly scopes out `HomeCoordinator.openProfile()`'s auth gate (separate milestone) and explicitly preserves Onboarding/`LoginScreen` pop behavior — avoids scope creep that would couple two roadmap items.
- Dependency ordering between tasks is accurate (DTO rename → state/service → VM → screen; coordinator login depends on the ARB key).
- Synchronous seed + continuous observable is the right call to avoid a first-frame flash of the wrong variant, and the reasoning is grounded in the actual `BehaviorSubject` implementation rather than assumed.
- Commit plan splits cleanly along a compiles-at-each-step boundary (data flow first, then UI/behavior).

PLAN_REVIEW_PASS
