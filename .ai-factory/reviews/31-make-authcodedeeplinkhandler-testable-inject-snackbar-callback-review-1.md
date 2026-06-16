# Code Review: Make `AuthCodeDeeplinkHandler` testable: inject snackbar callback

**Plan:** `31-make-authcodedeeplinkhandler-testable-inject-snackbar-callback.md`
**Files changed (code):** `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart`, `test/Core/Handlers/auth_code_deeplink_handler_test.dart`
**Risk Level:** 🟢 Low

## Summary

The change matches the approved plan. `AuthCodeDeeplinkHandler` now takes an optional `onError` callback (defaulting to a static that routes through `rootScaffoldMessengerKey`), and `_showLocalizedSnackBar` falls back to a directly-instantiated `AppLocalizationsEn()` when no widget context exists. Tests cover both error branches. I ran the test file (**all 7 pass** — 5 existing + 2 new) and `flutter analyze` on both files.

## Findings

### 1. Minor — Unused import in the test (`unused_import` lint)

`test/Core/Handlers/auth_code_deeplink_handler_test.dart:1`
```dart
import 'package:flutter/widgets.dart';
```
This import is not used. `TestWidgetsFlutterBinding.ensureInitialized()` (the only widgets-binding symbol referenced) is exported from `package:flutter_test/flutter_test.dart`, which is already imported on line 2. `flutter analyze` reports:
```
warning • Unused import: 'package:flutter/widgets.dart' • test/.../auth_code_deeplink_handler_test.dart:1:8 • unused_import
```
**Fix:** delete line 1. It is the only analyzer issue introduced by this change.

## Verification Notes (confirmed correct)

- **Production behaviour preserved.** The only construction site, `lib/Core/App.dart:196`, passes no `onError`, so it binds `_defaultOnError`, which still routes through `rootScaffoldMessengerKey.currentState?.showSnackBar(...)`. The `onError` param is optional with a default — call site compiles unchanged.
- **`AppLocalizationsEn` import resolves.** Imported directly via `package:mind_l10n/l10n/app_localizations_en.dart` (the barrel does not re-export it). The file is under `lib/l10n/` (public), so no `implementation_imports` lint. Confirmed `AppLocalizationsEn` has a `const`-free default constructor `AppLocalizationsEn([String locale = 'en'])`, instantiable without a context, and reading `loginTooManyAttemptsError` / `loginCodeInvalidError` are plain string getters (no `intl` locale init required).
- **Null-context fallback is safe and test-only in practice.** When `currentContext == null` the handler builds the English message and forwards it; in production that path coincides with `currentState == null`, so `_defaultOnError` no-ops (`?.`) — no user-visible change vs. the previous early `return`. The English-only fallback never reaches a real user (no messenger mounted), so locale correctness is unaffected.
- **Exception routing is correct.** `OtpLockedException implements Exception` with a `const` constructor, so `fakeRepo.exceptionToThrow = const OtpLockedException()` is valid and is caught by `on OtpLockedException`; the generic `Exception('boom')` falls through to `catch (_)`. `UserNotifier.completePasswordlessSignIn` rethrows repository errors (line 56–57), so both reach `handle()`.
- **Symbols/signatures match.** `SnackBarEvent.error(String)` sets `type == SnackBarType.error`; `SnackBarEvent`, `SnackBarType`, `SnackBarBuilder` are all exported from `package:mind_ui/mind_ui.dart`. The two l10n messages are distinct literals, so the lockout-vs-generic assertions are meaningful.
- **`_onError` fires exactly once** per error path, supporting the `hasLength(1)` assertions.
- **`TestWidgetsFlutterBinding.ensureInitialized()`** correctly added to `setUpAll` so binding-dependent code is safe in the headless run.
- **Existing 5 tests unaffected** — injecting `onError: captured.add` does not touch the non-error `group('handle', ...)` paths; `captured` is reset per test in `setUp`.

## Verdict

No correctness, security, or runtime-breakage issues. One trivial lint warning (unused `flutter/widgets.dart` import in the test) should be removed before commit.
