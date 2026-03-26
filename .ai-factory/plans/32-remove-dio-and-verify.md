# Plan: Remove Dio and verify

## Context
Dio was fully deleted in the previous milestone (31-delete-dio-infrastructure). This milestone runs the formal removal command and verifies that zero `package:dio` references remain anywhere in the project.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Remove and verify

- [x] **Task 1: Run `flutter pub remove dio` and verify clean removal**
  Files: `pubspec.yaml`, `pubspec.lock`
  Run `/usr/local/bin/flutter pub remove dio` from the project root. If Dio is already absent from `pubspec.yaml` the command will report that — this is the expected outcome since milestone 31 already removed all Dio code and the dependency. After the command completes, verify with `grep -r "package:dio" lib/ packages/` that no remaining imports exist. The grep should return zero matches. Also check `pubspec.lock` to confirm no `dio` transitive dependency lingers. If any stray import is found, delete it.
