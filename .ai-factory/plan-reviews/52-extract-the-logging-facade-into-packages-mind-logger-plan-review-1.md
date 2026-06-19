# Plan Review: Extract the logging facade into `packages/mind_logger`

**Plan:** `.ai-factory/plans/52-extract-the-logging-facade-into-packages-mind-logger.md`
**Risk Level:** 🟡 Medium
**Verdict:** One concrete gap that would break the plan's own `flutter analyze` verify step. Fix it and the plan is solid.

## What the plan gets right

- **Logger body is captured accurately.** Task 3's description of `lib/Logger.dart` matches the actual file byte-for-byte: the `String.fromEnvironment('LOG_DESTINATION', defaultValue: kDebugMode ? 'both' : 'file')` resolver, `logToConsole`/`logToObserver` getters, the timestamp format, and the `observeSink` routing. Imports `package:flutter/foundation.dart` + `package:observe/observe.dart` are correct.
- **`observe` git block is correctly described.** The app `pubspec.yaml` (lines 84–87) declares `observe` via git with `url: https://github.com/mind-systems/observe-dart.git` and `ref: main`. The plan's instruction to reuse the exact same block with matching `ref` is right — both git deps share one package name, so pub resolves a single `observe` commit. No version conflict.
- **App code keeps its direct `observe` use.** `lib/Core/App.dart` and `lib/Core/Grpc/GrpcLoggingInterceptor.dart` import `package:observe/observe.dart` directly, so Task 5's instruction to leave the app-level `observe` dependency in place is correct and necessary.
- **Re-export approach is sound.** `export 'package:mind_logger/mind_logger.dart';` re-exports `logPrint` plus the `logToConsole`/`logToObserver` getters, so every `import 'package:mind/Logger.dart';` call site keeps compiling untouched.
- **Barrel + path-dependency wiring** matches sibling conventions (`mind_audio.dart`, `mind_ui.dart` barrels; `# Internal packages` group in app `pubspec.yaml`, lines 34–47).

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** WARN-clean. A leaf utility package depended on by other packages does not violate the domain/module boundary. The plan's note that "`mind_logger` is the one package allowed to depend on `observe`" is consistent with the encapsulation goal. No issue.
- **Rules (`RULES.md`):** Pass. The rules concern Module Services (statelessness, constructor DI, no module state in App.dart). `logPrint` is a top-level function facade, not a Service — none of the rules apply.
- **Roadmap (`ROADMAP.md`):** WARN. This refactor has no linked roadmap phase. Acceptable for a pure move (not `feat`/`fix`/`perf`), but worth a one-line roadmap entry for traceability.

## Critical Issues

### 1. Task 1 omits `dev_dependencies`, so Task 2's `analysis_options.yaml` include will not resolve — `flutter analyze` fails

Task 2 says to mirror `packages/mind_audio/analysis_options.yaml`, whose entire content is:

```yaml
include: package:flutter_lints/flutter.yaml
```

For that include to resolve, `flutter_lints` must be a declared dependency. Every package in this repo that ships such an `analysis_options.yaml` (`mind_audio`, `meditation_module`) also declares it:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

But Task 1's pubspec spec lists **only** `dependencies: flutter + observe` and no `dev_dependencies` block (it mirrors `mind_ui`, which has no `analysis_options.yaml` and no dev deps — an inconsistent template to copy from for this purpose). The result: `analysis_options.yaml` includes a package that isn't in the dependency graph, and the plan's own verify step ("`flutter analyze` is clean") will instead error with an unresolved-include / missing-package diagnostic.

**Fix:** Add to Task 1's `pubspec.yaml` spec:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

(Mirror `mind_audio`/`meditation_module` for the full template, not `mind_ui`, since Task 2 adopts the `mind_audio` analysis baseline.) Alternatively, if dev deps are intentionally omitted, drop Task 2 / use an empty `analysis_options.yaml` — but matching siblings is the better call.

## Minor Notes

- **Call-site count is off (cosmetic).** The plan repeatedly cites "57 existing call sites." Actual: **111** `logPrint(` invocations across **19** files importing `package:mind/Logger.dart`. The guarantee that matters ("don't touch any call sites; they work via the re-export") is correct regardless of the number — just update the figure so it doesn't read as a verified fact when it isn't.
- **SDK constraint divergence is fine.** The package uses `sdk: '>=3.7.0 <4.0.0'` (sibling convention) while the app uses `^3.11.0`. Broader package constraint, no resolution conflict — consistent with all other packages. No action needed.
- **No `flutter:` section needed.** Unlike `mind_audio`, `mind_logger` ships no assets, so omitting a `flutter:` block is correct.

## Positive Notes

- Single atomic commit is the right call — the `lib/Logger.dart` re-export only compiles once Tasks 1–5 land, so splitting would leave an unbuildable intermediate state. The Commit Plan correctly forbids that.
- The "byte-identical behavior" framing and verbatim-copy instruction for Task 3 are exactly right for a pure move; no behavioral drift risk.
- The cross-package compile check in the Verify section (throwaway import from `packages/breath_module`) directly validates the stated motivation — good acceptance criterion.

Address Critical Issue #1 (add `dev_dependencies` to Task 1) and the plan is ready to implement.
