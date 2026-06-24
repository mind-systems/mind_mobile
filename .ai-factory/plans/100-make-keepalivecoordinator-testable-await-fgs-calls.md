# Plan: Make `KeepAliveCoordinator` testable: await FGS calls

## Context
Make `ForegroundKeepAlive.start()`/`.stop()` awaited inside `KeepAliveCoordinator`'s event handler so their `Future<void>`s no longer outlive test assertions, giving deterministic teardown in unit tests. Production semantics are unchanged — the stream listener itself is still not awaited.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Refactor event handler

- [x] **Task 1: Make `_onEvent` async and await the FGS calls**
  Files: `lib/Core/Background/KeepAliveCoordinator.dart`
  Change the `_onEvent` handler so the `ForegroundKeepAlive` calls are awaited, turning each fire-and-forget `Future<void>` into a tracked async operation. Concretely:
  - Change the signature from `void _onEvent(ModuleStateEvent event)` to `Future<void> _onEvent(ModuleStateEvent event) async`.
  - In the switch, `await` the FGS calls:
    - `case ModuleSessionStarted():` → `await _foregroundKeepAlive.start();`
    - `case ModuleSessionEnded():` → `await _foregroundKeepAlive.stop();`
    - `case ModuleSessionAbandoned():` → `await _foregroundKeepAlive.stop();`
    - `ModuleSessionResumed`, `ModuleSessionPaused`, `ModuleSessionUnpaused` cases stay as `break;` (no-op).
  - Leave the constructor subscription line unchanged: `_subscription = moduleStateEvents.listen(_onEvent);`. `Stream.listen` accepts an `async` handler returning `Future<void>` without change; the listener itself is intentionally not awaited, preserving production behavior.
  - Keep the existing `if (!Platform.isAndroid) return;` guard, the `_foregroundKeepAlive` field, and the `_subscription` field (with its GC-prevention `ignore: unused_field` comment) exactly as they are.
  No public API change — only the handler body and its return type change.
