# Plan: Session registry contract — `ModuleSession` + `SessionRegistry` skeleton + red routing tests

## Context
Lay the shared `ModuleSession` value type and a `SessionRegistry` surface (signatures only, no routing bodies) plus RED tests over the silent-failure routing points, so Phase 62–64 tasks can import the contract now and the impl milestone (note 14) greens the tests. One commit that compiles and is red.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Contract types

- [x] **Task 1: Add `ModuleSession` value type**
  Files: `lib/Core/Grpc/ModuleSession.dart`
  Create a small immutable value type `ModuleSession` with fields `{ String id; ActivityType activityType; ModuleStateStatus status; bool isPaused }`. Import `ActivityType` from `lib/Core/Grpc/ActivityType.dart` (already has `root`, added by note 13) and `ModuleStateStatus` from `lib/Core/Grpc/ModuleState.dart:1`. Use a `const` constructor with all fields (`id`, `activityType`, `status` required; `isPaused` defaulting to `false`). Add value equality + `hashCode` over all four fields (so upsert-in-place tests can assert on the stored instance) and a `copyWith`. Pure Dart, no Flutter/Riverpod imports. This is the shared type the registry stores and downstream tasks (RootStateChannel, addressing, bio) consume.

- [x] **Task 2: Add `SessionRegistry` skeleton (signatures only, no routing bodies)** (depends on Task 1)
  Files: `lib/Core/Grpc/SessionRegistry.dart`
  Create a standalone `SessionRegistry` class in `lib/Core/Grpc/` — the routing layer that note 14 will back with a `Map<String, ModuleSession>` keyed by `module_session_id` and own from `ModuleStateChannel`. Declare the full surface with **no routing bodies** so downstream tasks can import against it:
  - `void upsert(ModuleSession session)` — will upsert by `id`; body `throw UnimplementedError()`.
  - `void removeTerminal(String id)` — unconditional remove-by-`id`; body `throw UnimplementedError()`. Note: the terminal-status decision (proto `COMPLETED`/`INTERRUPTED`/`ABANDONED`) lives in the **caller** (`ModuleStateChannel`, note 14) — `removeTerminal` does not branch on `ModuleSession.status`, which is only `{idle, active}` and cannot represent terminal states.
  - `String? get rootId` — the sole entry with `activityType == ActivityType.root`; body `throw UnimplementedError()`.
  - `ModuleSession? childOfType(ActivityType type)` — the sole non-root entry of that type; body `throw UnimplementedError()`.
  - Change streams so adapters/bio can observe: `Stream<String?> get rootIdChanges` and `Stream<void> get changes`; bodies `throw UnimplementedError()`.
  - `void dispose()` — body must be an **empty no-op** (not `throw UnimplementedError()`), so a test `tearDown` calling `dispose()` does not error the suite; RED comes only from the routing accessors.
  Add a file-level doc comment: skeleton per note 22; routing bodies + backing state filled by note 14.
  **Signatures only — do not declare stored state (`_sessions` map, subjects) or `import 'package:rxdart/rxdart.dart';` in this milestone** (note 14 adds them). `flutter analyze` treats warnings as failures, so a premature `_sessions` field or RxDart import would trip `unused_field`/`unused_import` and break the Verify gate. If a stub field/import is genuinely unavoidable, suppress it with a scoped `// ignore:`. The class must **compile** analyzer-clean while every routing accessor is unimplemented.

### Phase 2: Red routing tests

- [x] **Task 3: Write RED routing tests against the real `SessionRegistry`** (depends on Task 2)
  Files: `test/Core/Grpc/session_registry_test.dart`
  Drive the **real** `SessionRegistry` (stateful — not a pass-through stub; a stateless double would let a missed-removal bug pass, per m36). These assert the intended greened behavior and are therefore RED now (bodies throw). Follow the fake/test conventions in `test/Core/Grpc/module_state_channel_test.dart`. Build `ModuleSession` fixtures directly (helper e.g. `sess(id, type, {status = ModuleStateStatus.active, isPaused = false})` — `status` is required in the `const` constructor, so the helper must supply a concrete default for fixtures that omit it). Cover exactly the silent-failure points from note 22:
  - **upsert-by-id:** a second `ModuleSession` with the same `id` (changed `status`/`isPaused`) updates in place — registry does not duplicate; the read-back reflects the latest frame.
  - **removeTerminal (remove-only-child):** with a root + one breath child present, `removeTerminal(childId)` removes only the child; `rootId` still resolves (a child terminal must NOT drop the root).
  - **`rootId` = ROOT-entry:** returns the `ActivityType.root` entry's `id`; `null` when no root present; never returns a child id.
  - **`childOfType` = sole-of-type:** `childOfType(ActivityType.breath)` returns the sole breath child; `null` when none; does not return the root or a meditation child.
  - **route-by-`activity_type`:** upserting a ROOT session then a BREATH session yields two distinct entries — `rootId` resolves the root and `childOfType(breath)` resolves the breath child, each correctly.
  Do NOT test loud surfaces (proto decode / enum mapping — covered by note 13's compile). Confirm the suite compiles and is RED (fails on `UnimplementedError`), not erroring on missing symbols.

## Verify
- `flutter analyze` is clean (new files compile; unimplemented bodies are intentional).
- `flutter test test/Core/Grpc/session_registry_test.dart` runs and is RED (assertions/UnimplementedError), the suite compiling successfully.
- Downstream Phase 62–64 tasks can import `ModuleSession` and the `SessionRegistry` signatures.
