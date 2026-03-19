# Plan: Personal Access Tokens

## Context
Add a new MCP screen accessible from the Profile screen where users can list, create (with one-time reveal), and revoke personal access tokens used by Claude Desktop to access their exercises.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: API layer — token CRUD endpoints

- [x] **Task 1: Add token API interface and request/response DTOs**
  Files: `lib/Core/Api/ITokenApi.dart` (new), `lib/Core/Api/Models/CreateTokenRequest.dart` (new), `lib/Core/Api/Models/TokenDTO.dart` (new)
  Create `ITokenApi` abstract class with three methods:
  - `Future<List<TokenDTO>> fetchTokens()` — list all tokens for the current user
  - `Future<CreateTokenResponse> createToken(CreateTokenRequest request)` — create a new token, returns the full token value
  - `Future<void> revokeToken(String tokenId)` — revoke a token by ID

  `CreateTokenRequest`: single `name` field + `toJson()` returning `{'name': name}`.
  `TokenDTO`: `id`, `name`, `createdAt` (String, ISO-8601). Parsed via `fromJson` factory.
  `CreateTokenResponse`: `token` (the one-time plaintext value) + `TokenDTO` metadata. Parsed via `fromJson` factory.
  Follow the existing DTO pattern from `UpdateUserRequest` and `UserStatsDTO`.

- [x] **Task 2: Add concrete TokenApi implementation**
  Files: `lib/Core/Api/TokenApi.dart` (new)
  Implement `ITokenApi` using `HttpClient` — same pattern as `UserApi`:
  - `GET /tokens` → `fetchTokens()` — parse response list into `List<TokenDTO>`
  - `POST /tokens` with `CreateTokenRequest.toJson()` → `createToken()` — parse response into `CreateTokenResponse`
  - `DELETE /tokens/{id}` → `revokeToken()`

- [x] **Task 3: Wire TokenApi into App.dart**
  Files: `lib/Core/App.dart`
  Add `final ITokenApi tokenApi;` field to `App`. Create `TokenApi(httpClient)` in `initialize()` (single-line, after `userApi`). Pass it into the `App._()` constructor. Follow the existing single-line initializer style rule.

### Phase 2: Domain layer — notifier and repository

- [x] **Task 4: Create TokenNotifier with typed events**
  Files: `lib/McpModule/Core/TokenNotifier.dart` (new), `lib/McpModule/Core/Models/TokenNotifierEvent.dart` (new), `lib/McpModule/Core/Models/Token.dart` (new)
  Domain model `Token`: `id`, `name`, `createdAt` (DateTime). Pure Dart, no Flutter imports.
  Sealed event class `TokenNotifierEvent` with subtypes:
  - `TokensLoaded` — carries `List<Token>`
  - `TokenCreated` — carries `Token` + `plainToken` (String, the one-time value)
  - `TokenRevoked` — carries `String id`
  - `TokenError` — carries `String message`

  `TokenNotifier` holds a `BehaviorSubject<TokenNotifierState>` (state = `List<Token>` + `lastEvent`).
  Methods: `loadTokens()`, `createToken(String name)`, `revokeToken(String id)`.
  Each method calls `ITokenApi` (passed via constructor), updates the in-memory list, emits the appropriate event. Wrap API calls in try/catch and emit `TokenError` on failure.

- [x] **Task 5: Wire TokenNotifier into App.dart**
  Files: `lib/Core/App.dart`
  Add `final TokenNotifier tokenNotifier;` field. Create it in `initialize()` after `tokenApi`: `final tokenNotifier = TokenNotifier(api: tokenApi)`. Single-line, pass to `App._()` constructor.

### Phase 3: Presentation layer — MCP screen

- [x] **Task 6: Create MCP screen service interface and DTOs**
  Files: `lib/McpModule/Presentation/McpScreen/IMcpService.dart` (new), `lib/McpModule/Presentation/McpScreen/Models/McpScreenDTOs.dart` (new), `lib/McpModule/Presentation/McpScreen/Models/McpScreenState.dart` (new)
  Service interface `IMcpService`:
  - `Stream<McpScreenEvent> observeChanges()`
  - `Future<void> loadTokens()`
  - `Future<void> createToken(String name)`
  - `Future<void> revokeToken(String id)`

  Sealed `McpScreenEvent`:
  - `TokensLoadedEvent` — carries `List<TokenItemDTO>`
  - `TokenCreatedEvent` — carries `TokenItemDTO` + `plainToken` (String)
  - `TokenRevokedEvent` — carries `String id`
  - `TokenErrorEvent` — carries `String message`

  `TokenItemDTO`: `id`, `name`, `createdAtFormatted` (String, pre-formatted like "Created 14 Mar 2026").
  `McpScreenState`: `List<TokenItemDTO> tokens`, `bool isLoading`, `String? revealToken` (non-null only during one-time reveal), `String? revealTokenName`.

- [x] **Task 7: Create concrete McpService**
  Files: `lib/McpModule/McpService.dart` (new)
  Implements `IMcpService`. Receives `TokenNotifier` via constructor. Subscribes to `tokenNotifier.stream`, pattern-matches `lastEvent`, converts `Token` domain models to `TokenItemDTO` (format `createdAt` as "Created DD MMM YYYY"), emits `McpScreenEvent` via a `StreamController.broadcast()`. Delegates `loadTokens`/`createToken`/`revokeToken` to the notifier.

- [x] **Task 8: Create McpScreen coordinator interface and concrete implementation**
  Files: `lib/McpModule/Presentation/McpScreen/IMcpCoordinator.dart` (new), `lib/McpModule/McpCoordinator.dart` (new)
  Interface `IMcpCoordinator`:
  - `void dismiss()` — pop back to Profile
  - `Future<String?> showCreateTokenSheet()` — open bottom sheet for token name input, return the name or null if cancelled
  - `Future<bool> showRevokeConfirmation()` — show AppAlert confirmation dialog

  Concrete `McpCoordinator` implements the interface using `context`:
  - `dismiss()` → `context.pop()`
  - `showCreateTokenSheet()` → show a `ModalBottomSheet` with a `TextField` for token name and a "Create" button. Return the entered name or null.
  - `showRevokeConfirmation()` → use `AppAlert.showWithInput` (same pattern as logout confirmation on Profile screen), return `result.confirmed`

- [x] **Task 9: Create McpViewModel**
  Files: `lib/McpModule/Presentation/McpScreen/McpViewModel.dart` (new)
  Riverpod `Notifier<McpScreenState>`. Receives `IMcpService` + `IMcpCoordinator` via constructor.
  In `build()`: subscribe to `service.observeChanges()`, call `service.loadTokens()`, return loading state.
  Event handler (`_onEvent`):
  - `TokensLoadedEvent` → update `state.tokens`, set `isLoading: false`
  - `TokenCreatedEvent` → prepend new token to list, set `revealToken` + `revealTokenName` for one-time display
  - `TokenRevokedEvent` → remove token from list by id
  - `TokenErrorEvent` → could show snackbar via coordinator (stretch — for now just log)

  Public methods:
  - `onCreateTap()` → call `coordinator.showCreateTokenSheet()`, if name returned → `service.createToken(name)`
  - `onRevokeTap(String id)` → call `coordinator.showRevokeConfirmation()`, if confirmed → `service.revokeToken(id)`
  - `onRevealDismissed()` → set `state = state.copyWith(revealToken: null, revealTokenName: null)`
  - `onCopyToken()` → copy `state.revealToken` to clipboard

  Declare `mcpViewModelProvider` with `throw UnimplementedError` stub (standard pattern).

- [x] **Task 10: Create McpScreen widget**
  Files: `lib/McpModule/Presentation/McpScreen/McpScreen.dart` (new)
  `ConsumerWidget` with `static const path = '/mcp'` and `static const name = 'mcp'`.
  Layout (Scaffold + SafeArea + ListView) following the Profile screen's visual style:
  - **Header text** — "Personal access tokens allow Claude Desktop to access your exercises." styled with `bodyMedium` at 60% opacity, padded like `SettingsSectionHeader`.
  - **Token list** — a `SettingsSection` containing one row per token. Each row shows token name (left), creation date subtitle, and a delete icon button (trailing). Use `SettingsCell` with a trailing `IconButton(Icons.delete_outline)`. Tap the icon → `viewModel.onRevokeTap(id)`.
  - **Create button** — below the list section, a centered `TextButton` or `OutlinedButton` labeled "+ Create token", calls `viewModel.onCreateTap()`.
  - **Empty state** — when `tokens` is empty and not loading, show only the header text and the create button.
  - **Loading state** — show a centered `CircularProgressIndicator` while `isLoading` is true.
  - **Reveal modal** — when `state.revealToken != null`, show a dialog/bottom sheet with: title "Copy your token", warning "This is shown only once. Give it to your AI.", the full token value in a selectable text field, a "Copy" button (`viewModel.onCopyToken()`), and a "Done" button (`viewModel.onRevealDismissed()`). Use `showModalBottomSheet` triggered reactively (via `ref.listen` on the provider for the `revealToken` field changing from null to non-null).

- [x] **Task 11: Create McpModule assembly and wire into router**
  Files: `lib/McpModule/McpModule.dart` (new), `lib/router.dart`
  `McpModule.buildMcpScreen(BuildContext context)` — same pattern as `ProfileModule.buildProfileScreen`:
  - Pull `App.shared.tokenNotifier`
  - Create `McpService(tokenNotifier: ...)`
  - Create `McpCoordinator(context)`
  - Return `ProviderScope` overriding `mcpViewModelProvider` with `McpViewModel(service: service, coordinator: coordinator)`
  - Wrap `McpScreen()`

  Add new route to `router.dart`:
  ```dart
  GoRoute(
    path: McpScreen.path,
    name: McpScreen.name,
    builder: (context, state) => McpModule.buildMcpScreen(context),
  ),
  ```

### Phase 4: Profile screen — MCP entry point

- [x] **Task 12: Add MCP navigation cell to Profile screen**
  Files: `lib/ProfileModule/Presentation/ProfileScreen/ProfileScreen.dart`, `lib/ProfileModule/Presentation/ProfileScreen/IProfileCoordinator.dart`, `lib/ProfileModule/ProfileCoordinator.dart`, `lib/ProfileModule/Presentation/ProfileScreen/ProfileViewModel.dart`
  Add `void openMcp()` to `IProfileCoordinator`. Implement in `ProfileCoordinator`: `context.push(McpScreen.path)`.
  Add `void onMcpTap()` to `ProfileViewModel` that calls `coordinator.openMcp()`.
  In `ProfileScreen`, add a new section between the "Appearance" section and the "Session" (logout) section:
  ```dart
  SettingsSectionHeader(title: 'Integrations'),
  SettingsSection(
    children: [
      SettingsNavigationCell(
        title: 'MCP',
        value: '',
        onTap: viewModel.onMcpTap,
      ),
    ],
  ),
  ```

### Phase 5: Localization

- [x] **Task 13: Add localization strings for MCP screen**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add keys to both ARB files:
  - `mcpTitle`: "MCP" / "MCP"
  - `mcpIntegrations`: "Integrations" / "Интеграции"
  - `mcpDescription`: "Personal access tokens allow Claude Desktop to access your exercises." / Russian equivalent
  - `mcpCreateToken`: "Create token" / "Создать токен"
  - `mcpRevealTitle`: "Copy your token" / "Скопируйте токен"
  - `mcpRevealWarning`: "This is shown only once. Give it to your AI." / Russian equivalent
  - `mcpCopy`: "Copy" / "Копировать"
  - `mcpDone`: "Done" / "Готово"
  - `mcpRevokeConfirmTitle`: "Revoke token" / "Отозвать токен"
  - `mcpRevokeConfirmDescription`: "This token will stop working immediately." / Russian equivalent
  - `mcpTokenName`: "Name" / "Название"
  - `mcpNewToken`: "New token" / "Новый токен"
  - `mcpCreatedAt`: "Created {date}" (with placeholder) / "Создан {date}"

  After editing ARB files, run `flutter gen-l10n` (or `flutter pub run build_runner build`) to regenerate `AppLocalizations`. Then update all hardcoded strings in McpScreen, McpCoordinator, and ProfileScreen to use `l10n.mcpXxx` keys.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add token API layer with interface, implementation, and DI wiring"
- **Commit 2** (after tasks 4-5): "Add TokenNotifier domain layer with typed events"
- **Commit 3** (after tasks 6-11): "Add MCP screen with token list, create flow, and one-time reveal"
- **Commit 4** (after tasks 12-13): "Add MCP entry point to Profile screen and localization strings"
