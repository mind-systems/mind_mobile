# Plan Review 2: Extract the logging facade into `packages/mind_logger`

**Plan:** `.ai-factory/plans/52-extract-the-logging-facade-into-packages-mind-logger.md`
**Risk Level:** 🟢 Low
**Verdict:** Review-1's single critical gap has been fixed and its minor notes addressed. Every factual claim in the plan was re-verified against the codebase and holds. Ready to implement.

## Resolution of Review-1 findings

- **Critical #1 (missing `dev_dependencies`) — RESOLVED.** Task 1 now declares the full block:
  ```yaml
  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^6.0.0
  ```
  It also explicitly calls out *not* mirroring `mind_ui` (which ships no `analysis_options.yaml` and no dev deps) and instead mirroring `mind_audio` / `meditation_module`. Verified: `mind_audio/pubspec.yaml` and `meditation_module/pubspec.yaml` both declare exactly that block, and `mind_ui` has no `analysis_options.yaml`. Task 2's `include: package:flutter_lints/flutter.yaml` will now resolve and `flutter analyze` will pass.
- **Call-site count — RESOLVED.** Plan now states "111 `logPrint(` invocations across 19 files." Verified exactly: 111 invocations, 19 files importing `package:mind/Logger.dart`.

## Re-verified facts

- **Logger body (Task 3).** `lib/Logger.dart` matches the plan's description byte-for-byte: `String.fromEnvironment('LOG_DESTINATION', defaultValue: kDebugMode ? 'both' : 'file')`, the `logToConsole`/`logToObserver` getters, the timestamp formatting, and the `observeSink` routing. Imports `package:flutter/foundation.dart` + `package:observe/observe.dart`. A verbatim copy into `packages/mind_logger/lib/src/logger.dart` is behavior-preserving.
- **`observe` git block (Task 1, Task 5).** App `pubspec.yaml` lines 84–87 declare `observe` via `url: https://github.com/mind-systems/observe-dart.git`, `ref: main`. Reusing the exact block with matching `ref` means pub resolves a single `observe` commit — no conflict.
- **App keeps direct `observe` use (Task 5).** `package:observe/observe.dart` is imported by `lib/Core/App.dart` and `lib/Core/Grpc/GrpcLoggingInterceptor.dart` (plus `lib/Logger.dart` itself). Leaving the app-level `observe` dependency in place is correct and necessary.
- **Barrel + path-dependency conventions (Tasks 4, 5).** `mind_audio` uses `export 'src/...';` barrels; the app `# Internal packages` group lists sibling path deps. The plan's wiring matches both.
- **Package does not yet exist.** `packages/mind_logger/` is absent — no collision; this is a clean create.
- **CLAUDE.md (Task 7).** The `## Logging` section at line 5–7 is exactly as the plan describes and is a coherent edit target.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** Pass. A leaf utility package consumed by other packages does not cross the domain/module boundary. The plan's note that `mind_logger` is the single package permitted to depend on `observe` keeps the encapsulation intent intact.
- **Rules (`RULES.md`):** Pass. The Module-Service rules (statelessness, constructor DI, no module state in `App.dart`) do not apply to a top-level function facade.
- **Roadmap (`ROADMAP.md`):** WARN (non-blocking). No linked roadmap phase. Acceptable for a pure move; a one-line traceability entry is optional.

## Minor Notes (non-blocking)

- **Internal-packages line range is approximate.** Task 5 cites "lines 34–47" for the `# Internal packages` group; the group actually runs to line 48 (`neiry_kit` path at 47–48). Cosmetic — the insertion point is unambiguous regardless.
- **SDK constraint divergence is intentional.** Package `sdk: '>=3.7.0 <4.0.0'` vs app `^3.11.0` is the established sibling convention; broader package constraint, no resolution conflict.

## Positive Notes

- Single atomic commit is the right call: the `lib/Logger.dart` re-export only compiles once Tasks 1–5 exist, so any intermediate commit would be unbuildable. The Commit Plan correctly forbids splitting.
- The cross-package compile check in the Verify section (throwaway `import 'package:mind_logger/mind_logger.dart';` from `packages/breath_module`) directly validates the stated motivation.
- "Byte-identical behavior" framing with a verbatim-copy instruction is exactly right for a pure move — no behavioral drift risk.

All review-1 findings are resolved and no new issues were found.

PLAN_REVIEW_PASS
