# Plan Review (2): Make `AuthCodeDeeplinkHandler` testable: inject snackbar callback

**Plan:** `31-make-authcodedeeplinkhandler-testable-inject-snackbar-callback.md`
**Files Reviewed:** 5 (plan + handler + test + `mind_l10n` barrel + `mind_ui` SnackBar symbols)
**Risk Level:** 🟡 Medium

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Constructor-injected behavior with a default — no boundary or dependency-direction violation. ✅
- **Rules (`.ai-factory/RULES.md`):** Satisfies "dependencies injected via constructor" by moving the snackbar side-effect behind an injected `onError` callback. No violations. ✅
- **Roadmap (`.ai-factory/ROADMAP.md`):** Task is a roadmap item with a matching OTP-lockout test-plan note. Linkage correct. ✅
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** Not present — no project-specific review overrides. (WARN: optional file missing — informational only.)

## Critical Issues

### 1. Wrong import source for `AppLocalizationsEn` — UNRESOLVED from review 1 (hard compile failure)

This was raised in review 1 and the plan text was **not** updated. The plan still instructs (lines 30 and 49) importing `AppLocalizationsEn` from `package:mind_l10n/mind_l10n.dart`. Verified against the source:

- The barrel re-exports only `l10n/app_localizations.dart`:
  ```dart
  // packages/mind_l10n/lib/mind_l10n.dart
  export 'l10n/app_localizations.dart';
  ```
- `app_localizations.dart` **imports** the En subclass (line 8) — it does not `export` it, and there is no `part` directive:
  ```dart
  import 'app_localizations_en.dart';
  ```

So `AppLocalizationsEn` is **not** reachable through `package:mind_l10n/mind_l10n.dart`. As written, both the handler change (Task 1) and the test (Task 2) fail to resolve the symbol and will not compile.

**Fix:** import the generated subclass directly — it lives in `lib/l10n/` (public, not `lib/src/`, so no `implementation_imports` lint):
```dart
import 'package:mind_l10n/l10n/app_localizations_en.dart';
```
Apply in both `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart` and `test/Core/Handlers/auth_code_deeplink_handler_test.dart`. (No existing usage of `AppLocalizationsEn` exists in `lib/` or `test/`, so there is no in-repo precedent to copy — the path above is the correct one.)

## Minor Issues

### 2. `DeeplinkRouter` does not construct the handler — wording inaccuracy (persists)

Task 1 says "The construction site in `lib/Core/App.dart` (and `DeeplinkRouter`)...". `DeeplinkRouter` (`lib/Core/DeeplinkRouter.dart:14`) **receives** an `AuthCodeDeeplinkHandler` via its constructor — it does not build one. The only real construction site is `lib/Core/App.dart:196`:
```dart
final authCodeHandler = AuthCodeDeeplinkHandler(userNotifier: userNotifier);
```
Because `onError` is optional with a default, that call compiles unchanged and the conclusion (production behaviour preserved) is correct — only the parenthetical is misleading.

## Verification Notes (assumptions that hold)

- **Single construction site, optional param:** `App.dart:196` calls the constructor with named args only; adding an optional `onError` keeps it source-compatible. ✅
- **Exception propagation:** `UserNotifier.completePasswordlessSignIn` rethrows repository errors, so a `FakeUserRepository` throwing `OtpLockedException` / `Exception('boom')` reaches `handle()`'s `on OtpLockedException` and `catch (_)` branches. ✅
- **Headless fallback is sound:** under `flutter_test` there is no widget tree, so `rootScaffoldMessengerKey.currentContext` is `null` and the new code takes the `AppLocalizationsEn()` branch — making `message == AppLocalizationsEn().loginTooManyAttemptsError` deterministic. ✅
- **Symbols exist & signatures match:** `SnackBarEvent.error(String)`, `.message`, `.type`, `SnackBarType.error`, and `SnackBarBuilder.build` are all exported via `package:mind_ui/mind_ui.dart`. `loginTooManyAttemptsError` and `loginCodeInvalidError` exist and return distinct literals. ✅
- **Exactly-once event:** `_showLocalizedSnackBar` calls `_onError` once per error path, so "exactly one captured event" is correct. ✅
- **Test URI host** `dev.mind-awake.life` matches `Environment.initDev().linkDomain`, consistent with the existing five passing tests. ✅
- **Default behaviour preserved:** the `_defaultOnError` static now reports even when `context == null` (instead of the current early `return`) — a genuine improvement, and it still routes through `rootScaffoldMessengerKey.currentState?.showSnackBar`. ✅

## Positive Notes

- Constructor injection with a default preserves production behaviour while enabling headless testing — minimal and rule-compliant.
- Replacing the null-context early `return` with an `AppLocalizationsEn()` fallback is a real behavioural improvement, not just a test seam.
- Test design covers both branches and asserts the two messages are *distinct*, guarding against a copy-paste regression mapping both paths to the same string.
- Existing five tests and the production call-site signature are preserved.

## Verdict

The approach is architecturally sound and the test design is correct, but **Critical Issue #1 from review 1 remains unresolved in the plan text** — the `AppLocalizationsEn` import as specified (`package:mind_l10n/mind_l10n.dart`) is a hard compile failure in both files. The plan must be corrected to `package:mind_l10n/l10n/app_localizations_en.dart` (lines 30 and 49) before implementation. Recommend also fixing the `DeeplinkRouter` wording.
