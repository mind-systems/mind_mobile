# Plan Review: Route module-package logs through `mind_logger`

**Plan:** `53-route-module-package-logs-through-mind-logger.md`
**Risk Level:** 🟢 Low

## Verification Summary

Every factual claim in the plan was checked against the codebase. All are accurate:

| Claim | Status |
|-------|--------|
| Exactly 3 stray `debugPrint`s in `packages/*/lib` (excluding facade) | ✅ Confirmed via grep — `BreathSessionStateMachine.dart:357,387` and `audio_one_shot.dart:44`; only other match is the facade's own `logger.dart:16` |
| No `dart:developer` / raw `print` in module packages | ✅ Confirmed — grep returns none |
| `BreathSessionStateMachine` lines 357 & 387 inside `if (kDebugMode)` guards at 356 & 386 | ✅ Confirmed |
| `kDebugMode` still used after migration → keep `flutter/foundation.dart` | ✅ Confirmed — `kDebugMode` at 356/386 is the only remaining foundation symbol, both stay |
| `audio_one_shot.dart` uses `foundation.dart` only for `debugPrint` → safe to remove import | ✅ Confirmed — `debugPrint` at line 44 is the sole consumer; no other foundation symbol in the file |
| `breath_module` path-dep style (mind_audio/mind_l10n/mind_ui) | ✅ Confirmed — alphabetical insertion of `mind_logger` lands between `mind_l10n` and `mind_ui` |
| `mind_audio` currently depends only on `flutter` + `just_audio` | ✅ Confirmed |
| `logPrint(Object?)` is the facade's public API, exported from `mind_logger.dart` | ✅ Confirmed — signature accepts the existing interpolated-string args unchanged |
| No circular dependency introduced | ✅ `mind_logger` depends only on `flutter` + `observe` (git); none of the 5 target packages are reachable from it |

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md`): WARN — not separately inspected for this review, but the change introduces no new boundaries. Dart requires a *direct* dependency to import a symbol, so declaring `mind_logger` directly in `breath_module` is correct even though it would arrive transitively via `mind_audio`. No layering violation.
- **Rules** (project `CLAUDE.md`): PASS — this plan directly enforces the "all logs through `logPrint`" rule for module packages, using the prescribed `package:mind_logger/mind_logger.dart` import for packages (not the `lib/`-only `package:mind/Logger.dart` re-export). Correct choice.
- **Roadmap**: WARN — no explicit linkage. This is a compliance/cleanup follow-up to plans 52 (facade extraction) and 40/41 (logPrint sink + dart:developer normalization); linkage is implicit and acceptable.

## Observations (non-blocking)

1. **Behavior change in `audio_one_shot.dart` (intended, worth noting).** The existing `debugPrint` at line 44 is **not** guarded by `kDebugMode`, but on release builds `debugPrint` is effectively a no-op for console only. After switching to `logPrint`, this play-failure error will now route to the file/observer sink in release (`logToObserver` is active when `LOG_DESTINATION != 'file'`... and `logToConsole` when `!= 'grafana'`). This is the *desired* outcome of routing through the facade, but it is a real change in release-time logging, not a pure sink swap. No action needed — just confirming it's expected.

2. **SM transition logs stay `kDebugMode`-guarded (intended).** Because the plan keeps the `if (kDebugMode)` wrapper around the migrated `logPrint` calls, those transition logs will *not* reach the file/observer sink in release — preserving current behavior exactly. Consistent with the plan's stated "compliance, not a logging-policy change" goal. Good.

3. **`mind_l10n` excluded from the uniformity pass.** Task 2 grants `mind_logger` to all zero-log packages "for rule-uniformity" but skips `mind_l10n`. This is reasonable (`mind_l10n` is generated ARB/localization code that should never log), but the plan does not state the exclusion rationale. Minor — consider adding one line noting `mind_l10n` is intentionally excluded as generated-only.

4. **Task 6 grep scope.** The verification grep over `packages/*/lib` excluding `*.g.dart`/`*.freezed.dart` and the facade is correct and will catch regressions. Solid.

## Critical Issues

None.

## Conclusion

The plan is accurate, well-sequenced (deps → migration → verify), correctly identifies the import-retention nuance (keep `foundation.dart` in the SM, remove it from `audio_one_shot`), and uses the correct facade import path for packages. File paths, line numbers, and API usage all verified against the live codebase. The observations above are informational only.

PLAN_REVIEW_PASS
