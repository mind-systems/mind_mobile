# Plan: Make `AuthCodeDeeplinkHandler` testable: inject snackbar callback

## Context
Decouple `AuthCodeDeeplinkHandler` error reporting from the `rootScaffoldMessengerKey` global by injecting a `void Function(SnackBarEvent) onError` callback, so the lockout vs. generic-error code paths can be asserted in tests without a real widget tree.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Refactor

- [x] **Task 1: Inject `onError` callback into `AuthCodeDeeplinkHandler`**
  Files: `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart`
  Add a `final void Function(SnackBarEvent) _onError;` field and an optional named constructor parameter `void Function(SnackBarEvent)? onError`, defaulting to a `static` method that preserves the current global-key behaviour:
  ```dart
  AuthCodeDeeplinkHandler({
    required UserNotifier userNotifier,
    void Function(SnackBarEvent)? onError,
  })  : _userNotifier = userNotifier,
        _onError = onError ?? _defaultOnError;

  static void _defaultOnError(SnackBarEvent event) {
    rootScaffoldMessengerKey.currentState
        ?.showSnackBar(SnackBarBuilder.build(event));
  }
  ```
  Refactor `_showLocalizedSnackBar` so it builds the `SnackBarEvent.error(...)` and forwards it to `_onError` instead of calling the global key directly. Resolve localization from `rootScaffoldMessengerKey.currentContext` when available, and fall back to a directly-instantiated `AppLocalizationsEn()` when the context is `null`, so the message is still produced headlessly. **Import the En subclass directly** — it is **not** re-exported from the `package:mind_l10n/mind_l10n.dart` barrel (the barrel only exports `app_localizations.dart`, which `import`s but does not `export` the subclass), so add `import 'package:mind_l10n/l10n/app_localizations_en.dart';` (a public path under `lib/l10n/`, not an `implementation_imports` violation):
  ```dart
  void _showLocalizedSnackBar(String Function(AppLocalizations) pick) {
    final context = rootScaffoldMessengerKey.currentContext;
    final l10n = context != null
        ? AppLocalizations.of(context)!
        : AppLocalizationsEn();
    _onError(SnackBarEvent.error(pick(l10n)));
  }
  ```
  Keep both call sites in `handle()` unchanged (`(l10n) => l10n.loginTooManyAttemptsError` for `OtpLockedException`, `(l10n) => l10n.loginCodeInvalidError` for the generic `catch`). The only construction site is `lib/Core/App.dart:196`; it passes no `onError` override, and because the new parameter is optional with a default, that call compiles unchanged and production behaviour is preserved. (`DeeplinkRouter` does not construct the handler — it receives one via its constructor — so no change is needed there.)

### Phase 2: Tests

- [x] **Task 2: Cover both error paths in the deeplink handler test** (depends on Task 1)
  Files: `test/Core/Handlers/auth_code_deeplink_handler_test.dart`
  Extend `FakeUserRepository` with a settable `Exception? exceptionToThrow;` field; have `completePasswordlessSignIn` throw it when non-null before the happy-path return. In `setUp`, construct the handler with an injected capture callback, e.g. `final captured = <SnackBarEvent>[]; handler = AuthCodeDeeplinkHandler(userNotifier: userNotifier, onError: captured.add);` (reset `captured` per test). Add a new `group('error handling', ...)` with two tests, both using the valid URI `https://dev.mind-awake.life/deeplink-auth?code=123456`:
  - **OTP lockout:** set `fakeRepo.exceptionToThrow = const OtpLockedException();` — assert `handle()` returns `true`, exactly one captured event, its `type == SnackBarType.error`, and `message == AppLocalizationsEn().loginTooManyAttemptsError`.
  - **Generic error:** set `fakeRepo.exceptionToThrow = Exception('boom');` — assert `handle()` returns `true`, exactly one captured event, and `message == AppLocalizationsEn().loginCodeInvalidError` (distinct from the lockout message).
  Add the needed imports (`OtpLockedException`, `SnackBarEvent`/`SnackBarType` from `package:mind_ui/mind_ui.dart`, and `AppLocalizationsEn` via `import 'package:mind_l10n/l10n/app_localizations_en.dart';` — it is **not** exported from the `mind_l10n.dart` barrel, so importing the barrel will not resolve the symbol). Confirm the existing five tests still pass.
