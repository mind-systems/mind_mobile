# Plan Review: Make `AuthCodeDeeplinkHandler` testable: inject snackbar callback

**Plan:** `31-make-authcodedeeplinkhandler-testable-inject-snackbar-callback.md`
**Files Reviewed:** 4 (plan + handler + test + supporting symbols)
**Risk Level:** 🟡 Medium

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Present. The refactor introduces constructor-injected behavior with a default — no boundary or dependency-direction violation. ✅
- **Rules (`.ai-factory/RULES.md`):** Present. The plan directly satisfies *"All dependencies must be injected via constructor"* by moving the snackbar side-effect behind an injected `onError` callback. No violations. ✅
- **Roadmap (`.ai-factory/ROADMAP.md`):** Present. The task is an explicit roadmap item (line 103) with the matching test-plan note `97-test-plan-otp-lockout.md`. Linkage is correct. ✅
- **Skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** Not present — no project-specific review overrides to apply. (WARN: optional file missing — informational only.)

## Critical Issues

### 1. Wrong import source for `AppLocalizationsEn` (will not compile)

Both Task 1 and Task 2 instruct importing `AppLocalizationsEn` from `package:mind_l10n/mind_l10n.dart`. That barrel only re-exports `l10n/app_localizations.dart`:

```dart
// packages/mind_l10n/lib/mind_l10n.dart
export 'l10n/app_localizations.dart';
```

and `app_localizations.dart` **imports** (does not `export`) the En subclass:

```dart
// packages/mind_l10n/lib/l10n/app_localizations.dart:8
import 'app_localizations_en.dart';
```

There is no `export 'app_localizations_en.dart'` anywhere in the package. Therefore `AppLocalizationsEn` is **not** reachable through `package:mind_l10n/mind_l10n.dart`, and both the handler change and the test will fail to resolve the symbol.

**Fix:** import the generated file directly (it lives in `lib/l10n/`, not `lib/src/`, so this is a public — not an `implementation_imports` — path):

```dart
import 'package:mind_l10n/l10n/app_localizations_en.dart';
```

Apply in both `lib/Core/Handlers/AuthCodeDeeplinkHandler.dart` and `test/Core/Handlers/auth_code_deeplink_handler_test.dart`.

## Minor Issues

### 2. `DeeplinkRouter` does not construct the handler

Task 1 says *"The construction site in `lib/Core/App.dart` (and `DeeplinkRouter`) passes no `onError` override."* `DeeplinkRouter` (`lib/Core/DeeplinkRouter.dart:14`) **receives** an `AuthCodeDeeplinkHandler` via its constructor — it does not construct one. The only real construction site is `lib/Core/App.dart:196`. Because the new `onError` parameter is optional with a default, that call site compiles unchanged, so the conclusion (production behaviour preserved) is correct — but the parenthetical is inaccurate and could mislead the implementer into searching for a second construction site that doesn't exist.

## Verification Notes (assumptions that hold)

- **Exception propagation works.** `UserNotifier.completePasswordlessSignIn` (line 56–57) `rethrow`s any error from the repository, so a `FakeUserRepository` throwing `OtpLockedException` / `Exception` will surface to `handle()`'s `on OtpLockedException` / `catch (_)` branches as the plan assumes. ✅
- **Headless fallback is sound.** In `flutter_test` there is no widget tree, so `rootScaffoldMessengerKey.currentContext` is `null` and the new code takes the `AppLocalizationsEn()` branch — exactly what makes the assertion `message == AppLocalizationsEn().loginTooManyAttemptsError` deterministic. ✅
- **Symbols exist:** `SnackBarEvent.error(...)`, `SnackBarType.error`, `SnackBarEvent.message`/`.type`, and `SnackBarBuilder.build` are all exported from `package:mind_ui/mind_ui.dart`; `loginTooManyAttemptsError` and `loginCodeInvalidError` exist on `AppLocalizationsEn` and return distinct literals. ✅
- **`onError` runs exactly once per error path** (single `_onError` call in `_showLocalizedSnackBar`), so the "exactly one captured event" assertion is correct. ✅
- The valid test URI host `dev.mind-awake.life` matches `Environment.initDev()`'s `linkDomain`, consistent with the existing passing tests. ✅

## Positive Notes

- Constructor injection with a default preserves production behaviour while enabling headless testing — clean, minimal, and rule-compliant.
- Replacing the early `return` on null context with an `AppLocalizationsEn()` fallback is a genuine behavioural improvement (errors are now always reported), not just a test hook.
- Test plan covers both branches and explicitly asserts the two messages are *distinct*, guarding against a copy-paste regression that maps both paths to the same string.
- The plan correctly preserves the existing five tests and the existing call-site signature.

## Verdict

The approach is architecturally sound and the test design is correct, but Issue #1 is a hard compile failure as written. Fix the `AppLocalizationsEn` import path (and ideally correct the `DeeplinkRouter` wording) before implementing.
