# Code Review 2: Make `AuthCodeDeeplinkHandler` testable: inject snackbar callback

**Plan:** `31-make-authcodedeeplinkhandler-testable-inject-snackbar-callback.md`
**Files changed (code):** `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart`, `test/Core/Handlers/auth_code_deeplink_handler_test.dart`
**Risk Level:** 🟢 Low

## Summary

Re-review after review-1. The change matches the approved plan and the sole review-1 finding is resolved. I re-read both changed files in full, ran `flutter analyze` on them (**No issues found**), and ran the test file (**all 7 pass** — 5 existing + 2 new).

## Resolution of Prior Review Finding

- **Review-1 Minor #1 (unused `package:flutter/widgets.dart` import):** Fixed. The test now imports only `flutter_test/flutter_test.dart` (line 1), from which `TestWidgetsFlutterBinding.ensureInitialized()` is sourced. `flutter analyze` is clean.

## Verification Notes (confirmed correct)

- **Production behaviour preserved.** The only construction site, `lib/Core/App.dart:196`, passes no `onError`, binding `_defaultOnError`, which still routes through `rootScaffoldMessengerKey.currentState?.showSnackBar(...)`. The optional param with default keeps the call source-compatible.
- **`AppLocalizationsEn` import resolves.** Imported directly via `package:mind_l10n/l10n/app_localizations_en.dart` (public `lib/l10n/` path; the barrel does not re-export it). Default constructor `AppLocalizationsEn([String locale = 'en'])` is instantiable without a context; `loginTooManyAttemptsError` / `loginCodeInvalidError` are plain string getters needing no `intl` init.
- **Null-context fallback is safe.** When `currentContext == null`, the English message is built and forwarded; in production that coincides with `currentState == null`, so `_defaultOnError` no-ops (`?.`). No user-visible change vs. the old early `return`, and the English-only fallback never reaches a real user.
- **Exception routing correct.** `OtpLockedException implements Exception` (`const` ctor) → caught by `on OtpLockedException`; `Exception('boom')` → `catch (_)`. `UserNotifier.completePasswordlessSignIn` rethrows repository errors, so both surface to `handle()`.
- **Symbols/signatures match.** `SnackBarEvent.error(String)` sets `type == SnackBarType.error`; `SnackBarEvent`, `SnackBarType`, `SnackBarBuilder` all exported from `package:mind_ui/mind_ui.dart`. The two l10n messages are distinct literals, so the assertions are meaningful.
- **`_onError` fires exactly once** per error path, supporting `hasLength(1)`.
- **Existing 5 tests unaffected** — injecting `onError: captured.add` does not touch the non-error paths; `captured` is reset per test in `setUp`.

## Verdict

No correctness, security, or runtime-breakage issues. The prior finding is fixed; analyze is clean and all tests pass.

REVIEW_PASS
