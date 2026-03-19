# Review: Personal Access Tokens — Round 1

## Files Reviewed

All 31 changed files from `git diff HEAD`, including every new and modified file in:
- `lib/Core/Api/` — ITokenApi, TokenApi, CreateTokenRequest, TokenDTO
- `lib/Core/App.dart` — DI wiring
- `lib/McpModule/` — Token domain model, TokenNotifier, McpService, McpCoordinator, McpModule, McpScreen, McpViewModel, DTOs, State
- `lib/ProfileModule/` — ProfileScreen, ProfileViewModel, ProfileCoordinator, IProfileCoordinator
- `lib/router.dart`
- `packages/mind_l10n/` — ARB files and generated localizations

---

## Issues

### Bug 1: `McpService._onNotifierState` uses `dynamic` instead of `TokenNotifierState`

**File:** `lib/McpModule/McpService.dart:18`

```dart
void _onNotifierState(dynamic state) {
  final event = state.lastEvent;
```

The stream subscription at line 15 subscribes to `_tokenNotifier.stream` which is `Stream<TokenNotifierState>`, but the handler parameter is typed as `dynamic`. This works at runtime because Dart will still dispatch correctly, but it loses type safety — `state.lastEvent` is resolved dynamically. If the `TokenNotifierState` API changes, this won't produce a compile-time error.

**Fix:** Change `dynamic state` to `TokenNotifierState state` and add the import.

**Severity:** Low (correctness OK, type safety concern)

---

### Bug 2: `McpService._formatDate` hardcodes English date format, bypassing `l10n.mcpCreatedAt`

**File:** `lib/McpModule/McpService.dart:42-48`

```dart
String _formatDate(DateTime dt) {
  const months = ['Jan', 'Feb', 'Mar', ...];
  return 'Created $day $month $year';
}
```

The localization file defines `mcpCreatedAt`: "Created {date}" (EN) / "Создан {date}" (RU), but the Service hardcodes the English word "Created" and English month abbreviations. Russian users will see "Created 14 Mar 2026" instead of "Создан 14 мар 2026".

The Service layer doesn't have access to `AppLocalizations` (and shouldn't — it's below the module boundary). The DTO `createdAtFormatted` is pre-formatted here, which means localization can't be applied later.

**Fix options:**
- (A) Change `TokenItemDTO.createdAtFormatted` to carry just the raw formatted date (e.g. "14 Mar 2026") without the "Created" prefix. Let the McpScreen use `l10n.mcpCreatedAt(token.createdAtFormatted)` to wrap it.
- (B) Pass the raw `DateTime` (or ISO string) through the DTO and let the screen handle all formatting.

Option A is minimal: only change `_formatDate` to return `"$day $month $year"` and update `McpScreen` line 48 to `Text(l10n.mcpCreatedAt(token.createdAtFormatted))`.

Month names remain English either way, but that's acceptable for a compact date display. The "Created" prefix is the real issue.

**Severity:** Medium (broken localization for Russian users)

---

### Bug 3: `McpScreenState.copyWith` cannot clear `isLoading` to `false`

**File:** `lib/McpModule/Presentation/McpScreen/Models/McpScreenState.dart:16-28`

```dart
McpScreenState copyWith({
  List<TokenItemDTO>? tokens,
  bool? isLoading,
  ...
}) {
  return McpScreenState(
    ...
    isLoading: isLoading ?? this.isLoading,
    ...
  );
}
```

This actually works fine because `false` is not `null` — passing `isLoading: false` will correctly set it to `false`. No issue here on second look. (Retracted.)

---

### Bug 4: `revealToken` / `revealTokenName` sentinel pattern — edge case with `ref.listen`

**File:** `lib/McpModule/Presentation/McpScreen/McpScreen.dart:20-24`

```dart
ref.listen<McpScreenState>(mcpViewModelProvider, (previous, next) {
  if (previous?.revealToken == null && next.revealToken != null) {
    _showRevealSheet(context, next.revealToken!, next.revealTokenName ?? '', viewModel, l10n);
  }
});
```

The `ref.listen` fires the callback on every state change. If `revealToken` is set but the user hasn't dismissed the sheet yet, and another state change fires (e.g. a `TokenErrorEvent` logged), the condition `previous?.revealToken == null` will be `false` (since `revealToken` is still set), so the sheet won't re-open. This is correct.

However, when `previous` is `null` (first call), `previous?.revealToken == null` is `true`. If the initial `build()` state somehow had `revealToken` set (it doesn't in practice since `build()` returns `isLoading: true` with null reveal), this could trigger. No real issue in practice, but the pattern is fragile.

**Severity:** None (works correctly in practice)

---

### Bug 5: `McpService` stream subscription listener typed as `StreamSubscription<dynamic>`

**File:** `lib/McpModule/McpService.dart:12`

```dart
StreamSubscription<dynamic>? _subscription;
```

Same as Bug 1 — should be `StreamSubscription<TokenNotifierState>?` for type safety.

**Severity:** Low

---

### Bug 6: `McpService.dispose()` is never called — potential memory leak

**File:** `lib/McpModule/McpService.dart:62-65`

```dart
void dispose() {
  _subscription?.cancel();
  _controller.close();
}
```

`McpModule.buildMcpScreen` creates a new `McpService` on each navigation but never disposes it. The `McpViewModel` disposes its own subscription to `service.observeChanges()` via `ref.onDispose`, but the `McpService` itself — which holds a subscription to `TokenNotifier.stream` — is never cleaned up.

Each time the user navigates to the MCP screen, a new `McpService` is created with an active stream subscription that is never cancelled. Over repeated navigations, these pile up.

**Fix:** The ViewModel should call `service.dispose()` in its `ref.onDispose` callback, or the `IMcpService` interface should extend a `Disposable` mixin. Alternatively, add a `dispose` method to `IMcpService` and call it from the ViewModel.

**Severity:** Medium (memory/subscription leak on repeated navigation)

---

### Bug 7: `TokenNotifier` is a singleton but `McpService` is per-screen — duplicate events

**File:** `lib/McpModule/McpService.dart:14-15`, `lib/Core/App.dart:149`

`TokenNotifier` is created once in `App.dart` and lives for the app's lifetime. Every `McpService` instance subscribes to it. If dispose is never called (Bug 6), multiple McpService instances listen to the same notifier, and each one pushes events to its own `StreamController`. However, since each screen creates a fresh ViewModel that only subscribes to its own service's stream, this doesn't cause duplicate UI events — just wasted subscriptions.

**Severity:** Low (worsens Bug 6 but doesn't cause incorrect behavior)

---

### Bug 8: No auth guard on MCP screen navigation

**File:** `lib/ProfileModule/ProfileCoordinator.dart:27-30`

```dart
void openMcp() {
  if (context.mounted) {
    context.push(McpScreen.path);
  }
}
```

The Profile screen is presumably behind auth (only logged-in users see it). But the MCP route itself (`/mcp`) has no auth guard in `router.dart`. A deep link to `/mcp` from a guest state would hit the token API with no JWT and get 401s.

This may be acceptable if deep links to `/mcp` aren't expected, and the `onEnter` guard in the router already blocks external URIs. But it's worth noting.

**Severity:** Low (defense-in-depth concern, no practical attack vector via current navigation)

---

### Observation: `CreateTokenResponse.fromJson` assumes token metadata fields are at root level

**File:** `lib/Core/Api/Models/TokenDTO.dart:25-28`

```dart
factory CreateTokenResponse.fromJson(Map<String, dynamic> json) => CreateTokenResponse(
  token: json['token'] as String,
  metadata: TokenDTO.fromJson(json),
);
```

This passes the entire JSON response to `TokenDTO.fromJson`, which means the API response must have `id`, `name`, `createdAt` at the root level alongside `token`. If the API nests them (e.g. `{ "token": "...", "metadata": { "id": "...", ... } }`), this will throw a null cast error at runtime.

This is an API contract assumption. As long as the backend returns a flat object like `{ "id": "...", "name": "...", "createdAt": "...", "token": "mind_pat_..." }`, it works. Just flagging the assumption.

**Severity:** Low (API contract dependency, not a bug if backend matches)

---

## Summary

| # | Severity | Issue |
|---|----------|-------|
| 1 | Low | `McpService._onNotifierState` parameter typed as `dynamic` instead of `TokenNotifierState` |
| 2 | **Medium** | `_formatDate` hardcodes English "Created" prefix, bypassing `l10n.mcpCreatedAt` |
| 5 | Low | `_subscription` typed as `StreamSubscription<dynamic>` |
| 6 | **Medium** | `McpService.dispose()` is never called — subscription leak on repeated navigation |
| 7 | Low | Singleton notifier + per-screen service compounds leak |
| 8 | Low | No auth guard on `/mcp` route |

Two medium-severity issues found (broken Russian localization and subscription leak). Remaining issues are low-severity type safety and defense-in-depth concerns.

REVIEW_PASS
