# Code Review: Make `KeepAliveCoordinator` testable — await FGS calls

**Plan:** `.ai-factory/plans/100-make-keepalivecoordinator-testable-await-fgs-calls.md`
**Target:** `lib/Core/Background/KeepAliveCoordinator.dart`
**Scope reviewed:** `git diff HEAD` (one code file changed; the rest are plan/JSON/plan-review artifacts).

## Summary

The diff changes exactly one method body and its return type in `KeepAliveCoordinator`:
- `void _onEvent(...)` → `Future<void> _onEvent(...) async`
- `_foregroundKeepAlive.start()` / `.stop()` calls are now `await`ed inside the switch.

The change is faithful to the plan and behavior-preserving. No bugs, security issues, or correctness problems found.

## Correctness analysis

- **Switch exhaustiveness preserved.** All six sealed `ModuleStateEvent` subtypes (`ModuleSessionStarted`, `ModuleSessionEnded`, `ModuleSessionAbandoned`, `ModuleSessionResumed`, `ModuleSessionPaused`, `ModuleSessionUnpaused`) remain handled; the three no-op `break` cases are untouched. No `default` was added, so any future subtype still triggers a compile-time exhaustiveness error — good.
- **`Stream.listen` accepts the async handler.** `Future<void> Function(ModuleStateEvent)` is assignable to `listen`'s `void Function(T)?` parameter, so the unchanged constructor line (`moduleStateEvents.listen(_onEvent)`) compiles and works without modification.
- **Production semantics unchanged.** The listener does not await the handler's returned `Future`, so event delivery is still effectively fire-and-forget at the stream level — matching the plan's stated intent. The only difference is intra-handler: each event awaits its single FGS call, which has no observable ordering effect since each event triggers at most one call.
- **Error propagation unchanged.** Previously a discarded `start()`/`stop()` future that completed with an error became an unhandled zone error; now a throw after `await` inside the un-awaited handler future likewise surfaces as an unhandled zone error. No new swallowing or new crash path. In normal operation `ForegroundKeepAlive.start()`/`.stop()` switch on a `ServiceRequest*` result and log rather than throw.
- **Platform guard and GC-prevention field intact.** `if (!Platform.isAndroid) return;` and the nullable `_subscription` field (with its `// ignore: unused_field` comment) are preserved. `_subscription` is nullable (not `late`), so the early return on non-Android leaves it `null` safely.
- **Lint impact: none.** The project lint set (`package:flutter_lints`) does not include `discarded_futures`/`avoid_void_async`, so the async callback introduces no new analyzer warning.

## Notes (non-blocking, no action required)

- As correctly observed in the plan-review, this milestone is deliberately scoped to only awaiting the futures. The constructor's `Platform.isAndroid` guard still prevents the Android subscription path from being exercised under a plain host `flutter test`. That is consistent with the milestone scope and not a defect in this change.

REVIEW_PASS
