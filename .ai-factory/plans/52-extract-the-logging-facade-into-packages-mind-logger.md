# Plan: Extract the logging facade into `packages/mind_logger`

## Context
Move the `logPrint` facade out of app code (`lib/Logger.dart`) into a standalone `packages/mind_logger` so module packages can depend on it directly, while `lib/Logger.dart` becomes a thin re-export keeping all existing call sites (111 `logPrint(` invocations across 19 files importing `package:mind/Logger.dart`) untouched. Pure move — behavior byte-identical.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Create the `mind_logger` package

- [x] **Task 1: Create the package manifest**
  Files: `packages/mind_logger/pubspec.yaml`
  Create a standard Flutter package manifest. Mirror `packages/mind_audio/pubspec.yaml` / `packages/meditation_module/pubspec.yaml` (NOT `mind_ui` — it ships no `analysis_options.yaml` and no dev deps, so it is the wrong template for a package that adopts the `flutter_lints` baseline in Task 2):
  - `name: mind_logger`, `description`, `version: 0.0.1`, `publish_to: none`
  - `environment:` block with `sdk: '>=3.7.0 <4.0.0'` and `flutter: '>=3.0.0'` (sibling convention; broader than the app's `^3.11.0`, no resolution conflict)
  - `dependencies`: `flutter` (sdk: flutter) and `observe` via the **exact same git block** as the app `pubspec.yaml` lines 84–87 (`url: https://github.com/mind-systems/observe-dart.git`, `ref: main`). The `ref` MUST match the app pin (`main`) so only one `observe` commit resolves. `mind_logger` is the one package allowed to depend on `observe`.
  - `dev_dependencies` (REQUIRED so Task 2's `flutter_lints` include resolves and `flutter analyze` passes):
    ```yaml
    dev_dependencies:
      flutter_test:
        sdk: flutter
      flutter_lints: ^6.0.0
    ```
  - No `flutter:` section — the package ships no assets.

- [x] **Task 2: Add the package analysis options** (depends on Task 1)
  Files: `packages/mind_logger/analysis_options.yaml`
  Mirror `packages/mind_audio/analysis_options.yaml` verbatim — a single line:
  ```yaml
  include: package:flutter_lints/flutter.yaml
  ```
  This resolves only because Task 1 declares `flutter_lints` in `dev_dependencies`.

- [x] **Task 3: Move the logger body into the package** (depends on Task 1)
  Files: `packages/mind_logger/lib/src/logger.dart`
  Copy the current body of `lib/Logger.dart` **verbatim** — the `_logDestination` resolver (`String.fromEnvironment('LOG_DESTINATION', defaultValue: kDebugMode ? 'both' : 'file')`), the `logToConsole` / `logToObserver` getters, and `logPrint(Object?)` with its console-format timestamp + `observeSink` routing. Keep imports `package:flutter/foundation.dart` and `package:observe/observe.dart`. Do not change formatting, the timestamp format, or the `observeSink` payload — the function must stay byte-identical in behavior.

- [x] **Task 4: Add the barrel export** (depends on Task 3)
  Files: `packages/mind_logger/lib/mind_logger.dart`
  Single line: `export 'src/logger.dart';` (matches the barrel convention of `packages/mind_ui/lib/mind_ui.dart` and `packages/mind_audio/lib/mind_audio.dart`). This re-exports `logPrint` plus the `logToConsole` / `logToObserver` getters.

### Phase 2: Wire the app to the package

- [x] **Task 5: Register the package as a path dependency** (depends on Task 1)
  Files: `pubspec.yaml`
  Under the `# Internal packages` group in the app `dependencies` (lines 34–47), add:
  ```yaml
  mind_logger:
    path: packages/mind_logger
  ```
  Leave the existing app-level `observe` git dependency in place — `lib/Core/App.dart` and `lib/Core/Grpc/GrpcLoggingInterceptor.dart` import `package:observe/observe.dart` directly, so it is still required.

- [x] **Task 6: Convert `lib/Logger.dart` to a re-export** (depends on Task 4, Task 5)
  Files: `lib/Logger.dart`
  Replace the entire file body with a single line:
  ```dart
  export 'package:mind_logger/mind_logger.dart';
  ```
  Do NOT touch any of the 111 `logPrint` call sites or their `import 'package:mind/Logger.dart';` statements — they keep working through the re-export.

### Phase 3: Documentation

- [x] **Task 7: Update the CLAUDE.md Logging section** (depends on Task 6)
  Files: `CLAUDE.md`
  Update the `## Logging` section to reflect the new structure:
  - The facade now lives in `packages/mind_logger`.
  - App code under `lib/` keeps importing `package:mind/Logger.dart` (now a re-export).
  - Module packages import `package:mind_logger/mind_logger.dart` directly.
  - Keep the existing "never raw `print` / `debugPrint` / `dart:developer` / any other logger" rule — note that it is now actually satisfiable inside packages.

## Commit Plan
- **Commit 1** (after tasks 1-7): "Extract logging facade into mind_logger package"

  This is a single atomic, cohesive move: the package, the app wiring, and the docs update must land together so the app stays buildable. Do not split into intermediate commits — `lib/Logger.dart` re-export (Task 6) only resolves once Tasks 1-5 exist.

## Verify (manual, post-implementation)
- `flutter analyze` is clean (requires Task 1's `dev_dependencies` for the `flutter_lints` include to resolve).
- App still builds; `logPrint` call sites in `lib/` compile unchanged via the re-export.
- A throwaway `import 'package:mind_logger/mind_logger.dart'; logPrint('x');` from inside a module package (e.g. `packages/breath_module`) compiles.
