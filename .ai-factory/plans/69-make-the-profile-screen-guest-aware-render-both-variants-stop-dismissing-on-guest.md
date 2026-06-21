# Plan: Make the Profile screen guest-aware (render both variants; stop dismissing on guest)

## Context
The Profile screen currently assumes an authenticated user and pops itself when the user becomes a guest. This milestone makes it render two variants driven by a single binary `isAuthenticated` flag in `ProfileState` — guest gets a login action cell plus appearance/version, authenticated stays unchanged — and flips in place instead of dismissing.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain → module data flow

- [x] **Task 1: Add `logIn` ARB key and regenerate localizations**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add `"logIn"` next to the existing `"logOut"` entry (line 23 in both files): EN `"Log in"`, RU `"Войти"`. Then regenerate `AppLocalizations` by running `/usr/local/bin/flutter gen-l10n` from `packages/mind_l10n` (or `flutter pub get` if that is how the package triggers codegen — match how the other generated keys like `logOut` are produced). Confirm `l10n.logIn` resolves.

- [x] **Task 2: Replace `ProfileSessionExpired` with `ProfileGuest` DTO**
  Files: `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileDTOs.dart`
  Rename the `ProfileSessionExpired` event class to `ProfileGuest` (still `extends ProfileEvent`, no fields). Keep `ProfileLoaded` and `UserDTO` unchanged. The semantics shift from "session expired → dismiss" to "now a guest → show guest variant".

- [x] **Task 3: Add `isAuthenticated` to `ProfileState`** (depends on Task 2)
  Files: `lib/ProfileModule/Presentation/ProfileScreen/Models/ProfileState.dart`
  Add `final bool isAuthenticated;` with default `false` in the constructor, and thread it through `copyWith` (`bool? isAuthenticated`, `isAuthenticated ?? this.isAuthenticated`). Keep `ProfileState.initial()` working.

- [x] **Task 4: Add `isAuthenticated` getter and continuous `observeProfile` to the service** (depends on Task 2)
  Files: `lib/ProfileModule/Presentation/ProfileScreen/IProfileService.dart`, `lib/ProfileModule/ProfileService.dart`
  In `IProfileService`, add `bool get isAuthenticated;`. In `ProfileService`:
  - Implement `bool get isAuthenticated => userNotifier.currentState is AuthenticatedState;`.
  - Rewrite `observeProfile()` to emit continuously **both ways** from `userNotifier.stream`: map `GuestState` → `ProfileGuest()`, and any non-guest (`AuthenticatedState`) → `ProfileLoaded(user: UserDTO(name: s.user.name))`. Drop the `.take(1)` + `mergeWith` expiry-only logic — a single `.map(...)` over the stream that branches on the state type. The `BehaviorSubject`-backed stream replays the current status on subscribe.

### Phase 2: ViewModel + coordinator behavior

- [x] **Task 5: Update coordinator — add `login()`, drop `dismiss()`** (depends on Task 1)
  Files: `lib/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart`, `lib/ProfileModule/ProfileCoordinator.dart`
  In `IProfileCoordinator`, remove `void dismiss();` and add `void login();`. In `ProfileCoordinator`:
  - Remove the `dismiss()` implementation (its only caller is removed in Task 6).
  - Add `login()` → `if (context.mounted) context.push(OnboardingScreen.path);` (import `lib/User/Presentation/Login/OnboardingScreen.dart`). No post-navigation callback — Profile re-renders via the observable when Onboarding pops. Do not touch Onboarding/`LoginScreen` pop behavior.

- [x] **Task 6: Seed and flip `isAuthenticated` in the ViewModel** (depends on Task 3, Task 4, Task 5)
  Files: `lib/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart`
  - In `build()`, seed the returned `ProfileState` with `isAuthenticated: service.isAuthenticated` (synchronous seed avoids a first-frame flash of the wrong variant), alongside existing `theme`/`language`.
  - In `_onEvent`: `ProfileLoaded e` → `state = state.copyWith(isAuthenticated: true, userName: e.user.name)`; `ProfileGuest _` → `state = state.copyWith(isAuthenticated: false)` (do **not** call `coordinator.dismiss()`).
  - Add `void onLoginTap() => coordinator.login();`.
  - Keep `onLogoutTap`, `onMcpTap`, name/theme/language handlers unchanged.

- [x] **Task 7: Branch the screen on `state.isAuthenticated`** (depends on Task 6)
  Files: `lib/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart`
  Build the `ListView` children conditionally on `state.isAuthenticated`:
  - **Account section:** authenticated → existing `SettingsEditableCell` (name). Guest → a single action `SettingsCell` (`title: Text(l10n.logIn)`, `onTap: viewModel.onLoginTap`), mirroring the existing logout `SettingsCell` shape.
  - **Appearance section + version footer:** always shown (both variants).
  - **MCP section** and **Session/logout section:** authenticated-only — omit entirely for guests.
  Keep the `themeDisplay`/`languageDisplay` switches and the appearance cells exactly as they are. Construct the children list (e.g. build a `List<Widget>` and add sections conditionally) so omitted sections produce no empty headers.

## Commit Plan
- **Commit 1** (after tasks 1-4): "Add guest-aware profile state and continuous auth observation"
- **Commit 2** (after tasks 5-7): "Render guest profile variant and flip in place instead of dismissing"
