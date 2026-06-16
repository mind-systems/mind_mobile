# Plan Review: NfbCalibrationRepository.record() — expose API sync future for testability

**Plan:** `.ai-factory/plans/32-nfbcalibrationrepository-record-expose-api-sync-future-for-testability.md`
**Target file:** `lib/Bci/NfbCalibrationRepository.dart`
**Risk Level:** 🟢 Low

## Verdict
The plan is correct, minimal, and faithfully implements ROADMAP.md line 105. All technical assumptions were verified against the actual codebase. No blocking issues found.

## Context Gates

- **Architecture:** PASS. `NfbCalibrationRepository` currently has zero Flutter imports (only `dart:async`, `dart:convert`, `shared_preferences`, the gRPC API, and `Logger`). The plan's insistence on `package:meta/meta.dart` over `package:flutter/foundation.dart` correctly preserves the project rule "Domain layer is pure Dart — no Flutter imports in Notifier or Repository classes." Sound architectural reasoning.
- **Rules:** PASS. `.ai-factory/RULES.md` contains nothing that conflicts with this change. The opt-in default (`awaitApiSync = false`) keeps production behavior identical, consistent with the project's testability-injection pattern used by sibling refactors (ActiveRrSource, BiometricBatcher, GrpcConnectionManager, AuthCodeDeeplinkHandler — ROADMAP lines 97–103).
- **Roadmap:** PASS. Directly fulfills the open milestone at `ROADMAP.md:105`, including the `flutter pub add meta` prerequisite. Strong linkage.

## Verified Assumptions (all correct)

1. **`meta` is transitive, not direct.** Confirmed in `pubspec.lock`: `meta` is `dependency: transitive`, version `1.17.0`. `flutter_lints: ^6.0.0` is active via `analysis_options.yaml`, so `depend_on_referenced_packages` would flag the new import. The `flutter pub add meta` step is necessary and correctly placed.
2. **Existing `unawaited(...)` line is reproduced verbatim** for the default branch (lines 62–64). Matches the plan text exactly.
3. **Call sites are not broken.** The only production caller is `lib/Bci/BciDeviceManager.dart:85`, which calls `record(_connectedSerial!, data)` with positional args inside its own `unawaited(...).catchError(...)`. Adding an optional named parameter with a default leaves this caller working unchanged.
4. **`record()` already returns `Future<void>`** and the local persist is already `await`ed, so the `awaitApiSync` branch slots in cleanly with no signature-shape surprises.

## Notes (non-blocking)

- **WARN — `@visibleForTesting` on a parameter is decorative, not enforced.** In meta `1.17.0`, `_VisibleForTesting` carries no `@Target` annotation (the source has an explicit `// TODO` to add `TargetKind.parameter` enforcement). Consequences: (a) there is **no** `invalid_annotation_target` error — the annotation compiles cleanly, so the plan is safe; (b) the analyzer does **not** actually restrict the parameter to test code — `invalid_use_of_visible_for_testing_member` applies to member accesses, not parameters. So the annotation documents intent but enforces nothing. This matches the test plan note 92 recommendation and is fine as-is; just don't expect the analyzer to police non-test usage.
- **WARN — "Testing: no" vs. the change's purpose.** The entire value of this refactor is realized only when the tests from `.ai-factory/notes/92-test-plan-nfb-calibration-repository.md` (the `record()` server-sync cases) are written. The plan correctly scopes itself to the repository change alone, consistent with the roadmap item, but the testability benefit is inert until a follow-up adds those tests. Flag for the orchestrator so the test-writing step isn't lost.

## Positive Notes

- Single-file, single-concern, single-commit scoping is appropriate and matches the global commit conventions.
- Explicit guardrails ("do not modify `refreshFromServer`, `history`, or `latestValid`", "do not change any call sites") reduce implementation drift.
- Reusing one `catchError` handler across both branches avoids duplicated log-string divergence — a thoughtful detail.

PLAN_REVIEW_PASS
