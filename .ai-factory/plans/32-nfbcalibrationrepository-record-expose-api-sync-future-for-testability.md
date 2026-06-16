# Plan: NfbCalibrationRepository.record() — expose API sync future for testability

## Context
Make the background API sync in `NfbCalibrationRepository.record()` awaitable from tests via an optional `@visibleForTesting` flag, so server-sync assertions don't rely on artificial delays. Default production behavior stays fire-and-forget and unchanged.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Repository change

- [x] **Task 1: Add `awaitApiSync` parameter to `record()`**
  Files: `lib/Bci/NfbCalibrationRepository.dart`
  First, declare `meta` as a direct dependency — it is currently only transitive and `depend_on_referenced_packages` lint (via `flutter_lints`) requires it to be declared explicitly:
  ```bash
  flutter pub add meta
  ```
  Then add an optional named parameter `@visibleForTesting bool awaitApiSync = false` to `record(String serial, NfbCalibrationData data)`. Add `import 'package:meta/meta.dart';` — do NOT use `package:flutter/foundation.dart` (Repository must stay pure Dart). Keep the local persist (`await _prefs.setString(...)`) always awaited and unchanged. Branch the API sync:
  - When `awaitApiSync == false` (default, production): keep the existing `unawaited(_api.record(serial, data).catchError((Object e) => logPrint('NfbCalibrationRepository: sync failed: $e')))` call exactly as-is.
  - When `awaitApiSync == true` (tests only): `await _api.record(serial, data).catchError((Object e) => logPrint('NfbCalibrationRepository: sync failed: $e'));`
  Reuse the same `catchError` handler in both branches to avoid duplicated error-logging strings; extract it into a local `void Function(Object)` if it reads cleaner. Do not change any call sites — all existing callers continue to work with the default `false`.

## Notes
- Single-file, single-concern change → one commit. No commit plan needed.
- Do not modify `refreshFromServer`, `history`, or `latestValid`.
- Production callers must remain untouched; the new parameter is opt-in for tests per `.ai-factory/notes/92-test-plan-nfb-calibration-repository.md`.
