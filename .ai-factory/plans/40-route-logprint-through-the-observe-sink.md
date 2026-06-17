# Plan: Route `logPrint` through the observe sink

## Context
Make `lib/Logger.dart`'s `logPrint(Object?)` forward each record to the `observe` SDK (Loki) when `logToObserver`, while preserving the byte-identical console output when `logToConsole`. All 57 existing call sites stay unchanged.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Route logPrint to the observe sink

- [x] **Task 1: Forward logPrint to observeSink**
  Files: `lib/Logger.dart`
  Change only the body of `logPrint(Object?)` — keep the signature. The note-109 resolver getters (`logToConsole`, `logToObserver`) and `_logDestination` are already declared in this file; reuse them, do not redeclare.
  - Add import `package:observe/observe.dart` (provides `observeSink`) next to the existing `package:flutter/foundation.dart` import.
  - Wrap the existing time-prefixed console output in a `logToConsole` guard, keeping it byte-for-byte identical: `if (logToConsole) debugPrint('[$time] $object');`. The `time` string computation stays exactly as-is. (If `logToConsole` is false, the `now`/`time` computation can be skipped — but keep the existing format string unchanged.)
  - When `logToObserver`, also call `observeSink(object?.toString() ?? '')`. Send the **raw message without** the `[$time]` prefix (Loki carries its own timestamp). Use the `info` default level — do not pass a `level:` argument and do not add a `Level` parameter to `logPrint`.
  - Do **not** wrap `observeSink` in try/catch — it is guaranteed never to throw and tolerates being called before SDK init.
  Resulting shape:
  ```dart
  void logPrint(Object? object) {
    if (logToConsole) {
      final now = DateTime.now();
      final time = '...'; // unchanged HH:mm:ss.SS format
      debugPrint('[$time] $object');
    }
    if (logToObserver) observeSink(object?.toString() ?? '');
  }
  ```

## Notes
- Dependency note 109 is already implemented: `_logDestination`, `logToConsole`, and `logToObserver` already exist in `lib/Logger.dart`. No resolver work is needed in this milestone.
- `observe` is already a direct dependency in `pubspec.yaml` / `pubspec.lock` (git ref `v0.1.0`) — no `flutter pub add` required.
- Single-task milestone → single commit, no commit plan needed. Suggested commit message: "Route logPrint through the observe sink".
