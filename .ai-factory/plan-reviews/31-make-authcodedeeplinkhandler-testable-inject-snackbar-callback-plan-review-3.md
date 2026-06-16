# Plan Review 3: Make `AuthCodeDeeplinkHandler` testable — inject snackbar callback

**Plan:** `31-make-authcodedeeplinkhandler-testable-inject-snackbar-callback.md`
**Files Reviewed:** 5 (plan + 4 codebase files)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** No boundary violations. The change adds constructor-injected dependency to an infrastructure handler — consistent with the layered design. WARN: none.
- **Rules (`.ai-factory/RULES.md`):** Compliant. "All dependencies must be injected via constructor" — the plan injects `onError` via the constructor with a default, exactly matching this rule. The handler is not a Module Service, so the stateless-service rule does not apply. WARN: none.
- **Roadmap:** Test-hardening / refactor task; no milestone-linkage concern. WARN: none.
- **skill-context (`aif-review/SKILL.md`):** Not present — no project-specific review overrides to apply.

## Resolution of Prior Review Findings

Both issues from review-2 are now fixed in the plan text:

1. **Import path (was Critical #1):** Lines 30 and 49 now correctly specify `import 'package:mind_l10n/l10n/app_localizations_en.dart';` and explicitly explain that `AppLocalizationsEn` is **not** re-exported from the `mind_l10n.dart` barrel. ✅ Verified: `packages/mind_l10n/lib/mind_l10n.dart` exports only `l10n/app_localizations.dart`, which `import`s (not `export`s) `app_localizations_en.dart`. The path is under `lib/l10n/` (public, not `lib/src/`), so no `implementation_imports` lint fires.
2. **`DeeplinkRouter` wording (was Minor #2):** Line 40 now correctly states "`DeeplinkRouter` does not construct the handler — it receives one via its constructor — so no change is needed there." ✅

## Verification Notes (assumptions that hold)

- **Single construction site:** `lib/Core/App.dart:196` calls `AuthCodeDeeplinkHandler(userNotifier: userNotifier)` with named args only. Adding an optional `onError` with a default keeps this source-compatible and preserves production behaviour. ✅
- **Symbols and signatures match:** `SnackBarEvent.error(String)` (returns `type == SnackBarType.error`), `.message`, `.type`, `SnackBarType.error`, and `SnackBarBuilder.build` are all exported via `package:mind_ui/mind_ui.dart`. ✅
- **Localization strings exist and are distinct:** `loginCodeInvalidError => 'Code is invalid or expired'` and `loginTooManyAttemptsError` are plain string getters in `AppLocalizationsEn` — no `intl` locale initialization required to read them, so headless `AppLocalizationsEn()` instantiation is safe. ✅
- **`const OtpLockedException()` is valid:** the class declares a `const` constructor. ✅
- **Headless fallback is sound:** under `flutter_test` there is no widget tree, so `rootScaffoldMessengerKey.currentContext` is `null` and the new code deterministically takes the `AppLocalizationsEn()` branch — making message assertions exact. ✅
- **Exception propagation:** `UserNotifier.completePasswordlessSignIn` rethrows repository errors, so a `FakeUserRepository` throwing reaches `handle()`'s `on OtpLockedException` / `catch (_)` branches. The fake's `completePasswordlessSignIn(String code, {String? language})` signature matches `UserRepository`, so the added `exceptionToThrow` throw integrates cleanly. ✅
- **`_defaultOnError` tear-off:** the `static void _defaultOnError(SnackBarEvent)` matches the `void Function(SnackBarEvent)` field type; `onError ?? _defaultOnError` is valid. ✅
- **Existing 5 tests preserved:** injecting `onError: captured.add` in `setUp` does not affect the `group('handle', ...)` cases, which exercise non-error paths. ✅

## Minor Note (non-blocking)

The Task 2 snippet shows `final captured = <SnackBarEvent>[];` inline in `setUp`. For the two new tests to assert against it, the implementer must hoist `captured` to a `late List<SnackBarEvent>` at `main()` scope and reassign it in `setUp` (the plan's "reset captured per test" implies this). The `captured.add` tear-off binds the current list instance, so reassigning per test is correct. This is a routine implementation detail, not a defect in the plan.

## Positive Notes

- Constructor injection with a default cleanly preserves production behaviour while enabling headless testing — minimal and rule-compliant.
- Replacing the current null-context early `return` with an `AppLocalizationsEn()` fallback is a genuine behavioural improvement (errors now surface even when no context is available), not just a test seam.
- The test design asserts the two messages are *distinct*, guarding against a copy-paste regression that maps both error paths to the same string.
- All previously-flagged compile-blockers have been corrected with accurate, verified justifications.

## Verdict

The plan is architecturally sound, the import paths are now correct and verified against the actual barrel exports, all referenced symbols and signatures exist, and both prior-review findings are resolved. No blocking issues remain.

PLAN_REVIEW_PASS
