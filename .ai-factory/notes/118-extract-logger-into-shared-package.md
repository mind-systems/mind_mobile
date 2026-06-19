# Extract the logging facade into a shared package

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- The `logPrint` facade lives in `lib/Logger.dart` (app code). It routes to console and, when `logToObserver`, to `observeSink(...)` → Loki. So anything through `logPrint` reaches Loki.
- Standalone module packages (`breath_module`, `bci_module`, `mind_audio`, `mind_ui`, …) cannot import `package:mind/Logger.dart` — a package must not depend on the app (module boundary). So the CLAUDE.md rule "all logs through `logPrint`" is **physically unenforceable inside packages**; they fall back to `debugPrint`, which never reaches Loki. Confirmed today: `BreathSessionStateMachine` (`[SM]` ×2) and `mind_audio` `AudioOneShot` (×1) log via `debugPrint` → console-only.
- Fix the cause, not each call site: move the facade into a standalone `packages/mind_logger` package that both `lib/` and every module package can depend on. `lib/Logger.dart` becomes a thin re-export so the 57 existing `lib/` call sites and the `import 'package:mind/Logger.dart'` stay untouched — **no log rewriting**.

## Details

### New package — `packages/mind_logger/`

- Standard Flutter package (`pubspec.yaml`, `lib/mind_logger.dart` barrel, `lib/src/logger.dart`).
- Move the body of `lib/Logger.dart` here verbatim: the `LOG_DESTINATION` resolver (`String.fromEnvironment`, `kDebugMode` default), `logToConsole`/`logToObserver`, and `logPrint(Object?)` with its console-format + `observeSink` routing.
- Depends on `flutter` (foundation, for `debugPrint`/`kDebugMode`) and `observe` (same git ref as the app's pubspec — `main`). This is the one package allowed to depend on `observe`; modules depend on `mind_logger`, not on `observe`.

### Re-export — `lib/Logger.dart`

- Replace its body with `export 'package:mind_logger/mind_logger.dart';`. Add `mind_logger` (path dep) to the app `pubspec.yaml`. The 57 `logPrint` call sites and `import 'package:mind/Logger.dart'` are unchanged.

### CLAUDE.md

- Update the Logging section: the facade now lives in `mind_logger`; `lib/` keeps importing `package:mind/Logger.dart` (re-export), module packages import `package:mind_logger/mind_logger.dart`. The "never raw `print`/`debugPrint`/`dart:developer`" rule stays — and is now actually satisfiable in packages.

### Guards

- Do NOT rewrite existing `logPrint` call sites — the re-export keeps them working.
- Keep `logPrint` behavior byte-identical (console format, `observeSink` payload, destination resolver) — pure move.
- Wiring packages to use it + migrating the 3 stray `debugPrint`s is the **next** task (note 119); this task only extracts + re-exports, so it ships and makes `logPrint` importable from packages with zero consumer change.
- `observe` ref must match the app's current pin (`main`) to avoid a second resolved commit.

### Verify

`flutter analyze` clean; app logs still reach Loki exactly as before (`lib/` unchanged via re-export); a throwaway `import 'package:mind_logger/mind_logger.dart'; logPrint('x');` from inside `breath_module` compiles and lands in Loki.

## Open Questions

- None blocking. Package name `mind_logger` assumed; adjust if a naming convention dictates otherwise.
