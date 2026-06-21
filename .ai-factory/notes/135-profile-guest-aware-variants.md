# Make the Profile screen guest-aware (render both variants; stop dismissing on guest)

**Date:** 2026-06-21
**Source:** conversation context

## Key Findings

- Today the Profile screen assumes an authenticated user. `ProfileViewModel._onEvent` turns a `GuestState` into `ProfileSessionExpired` → `coordinator.dismiss()` (pops the screen). The cell set (account name, appearance, MCP, logout) is unconditional.
- Target: the Profile screen renders **two variants** driven by auth status. **Guest** — instead of the editable name cell, a **login action cell** (same kind of action `SettingsCell` as logout); **no** logout section, **no** MCP section; appearance (theme/language) and app version stay. **Authenticated** — exactly as today.
- **Who owns the cell set:** the ViewModel, via a single binary `isAuthenticated` flag in `ProfileState`, derived directly from the domain `AuthState`. No state machine (two states, no transitions beyond the binary derived from `AuthState`); no declarative cell-descriptor list (unused elsewhere in the app — would be an inconsistent abstraction). The screen composes the cells per variant; the VM decides *which* variant.
- This task makes the guest variant exist and stops the dismiss-on-guest behavior. Until the next task removes the entry gate (note 136), a guest reaches this variant only by logging out or having the session expire **while on the profile** — and that path now **flips to the guest variant in place** instead of popping back home. That behavior change is the independently observable value of this task.

## Details

### Affected files

- `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileState.dart` — add `final bool isAuthenticated` (default `false`) + `copyWith`.
- `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart` — replace `ProfileSessionExpired` with `ProfileGuest` (semantics shift from "expired → dismiss" to "now a guest → show guest variant"). Keep `ProfileLoaded`.
- `lib/ProfileModule/Presentation/ProfileScreen/IProfileService.dart` + `ProfileService.dart` — add synchronous `bool get isAuthenticated` (`userNotifier.currentState is AuthenticatedState`). Rewrite `observeProfile()` to emit **continuously both ways**: `ProfileLoaded(name)` while authenticated, `ProfileGuest()` while guest (drop the `take(1)` / merge that only fired expiry once).
- `lib/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart` — seed `ProfileState(isAuthenticated: service.isAuthenticated, theme: …, language: …)` in `build()` (synchronous seed avoids a flash of the wrong variant). `_onEvent`: `ProfileLoaded` → `isAuthenticated: true` + `userName`; `ProfileGuest` → `isAuthenticated: false` (do **not** dismiss). Add `onLoginTap()` → `coordinator.login()`.
- `lib/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart` + `ProfileCoordinator.dart` — add `login()` → `context.push(OnboardingScreen.path)` (no post-navigation; the profile re-renders when Onboarding pops). Remove `dismiss()` — its only caller was the expiry path; confirm no other callers, then drop from interface + impl.
- `lib/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart` — branch on `state.isAuthenticated`. Guest: Account section holds a single login action `SettingsCell` (`Text(l10n.logIn)`, `onTap: viewModel.onLoginTap`) in place of the `SettingsEditableCell` name; omit the MCP section and the Session/logout section; keep Appearance + version footer. Authenticated: unchanged from today.
- `packages/mind_l10n/lib/l10n/app_en.arb` + `app_ru.arb` — add `logIn` (EN "Log in" / RU "Войти"); regenerate `AppLocalizations`.

### Guards

- Do **not** change Onboarding/`LoginScreen` pop behavior (`AuthResult` / double-pop) — `login()` just pushes; the existing pop returns to the profile.
- Appearance (theme/language) and app version remain visible for guests; name, MCP, and logout are authenticated-only. `updateLanguage` already no-ops the server call for guests.
- Seed `isAuthenticated` synchronously in `build()` — the `BehaviorSubject`-backed `observeProfile` also emits the current status on subscribe, but the seed prevents a first-frame flash.
- After logout or session expiry while on the profile: stay on the profile and flip to the guest variant (no `dismiss`/pop).

### Verification

1. Authenticated user opens Profile → unchanged from today.
2. Logout from Profile → flips to the guest variant in place (login cell, appearance, version; no name/MCP/logout); no pop to Home.
3. From the guest variant, tap the login cell → Onboarding → complete login → returns to Profile, now the authenticated variant.
4. Cancel Onboarding → back on the guest profile, unchanged.
5. `flutter analyze` clean; no leftover `dismiss()` / unused members.

## Open Questions

- None blocking. App-settings (theme/language) for guests already works locally.
