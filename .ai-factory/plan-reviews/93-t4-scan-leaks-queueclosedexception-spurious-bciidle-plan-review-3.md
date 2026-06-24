# Plan Review 3 — T4 · scan() leaks QueueClosedException → spurious BciIdle

**Plan:** `.ai-factory/plans/93-t4-scan-leaks-queueclosedexception-spurious-bciidle.md`
**Risk Level:** 🟢 Low

## Verdict

The plan is solid, fully grounded in the actual code, and ready to implement. All file paths, line numbers, API names, and behavioral assumptions were verified against the source. The test design is correctly reasoned — including the non-obvious determinism argument for Case 1.

## Verification performed

**Line/anchor accuracy (`lib/Bci/NeiryBciProvider.dart`) — all correct:**
- `scan()` at `:118` ✓
- `final devicesStream = await _queue.enqueue(...)` at `:156` ✓
- `yield* devicesStream` at `:159` ✓
- `QueueClosedException` usage (not import) at the `catchError` site `:473` ✓
- `import 'SerialCommandQueue.dart';` at `:18` ✓ — `QueueClosedException` is exported from that file (`SerialCommandQueue.dart:9`), so it is genuinely in scope and **no new import is needed**, as the plan states.

**Stale-comment callout — correct:** the existing test references `await _teardownComplete` at lines 96–98, which no longer matches the code. The plan correctly instructs not to copy it.

**Type semantics — correct:** `QueueClosedException extends StateError` (`SerialCommandQueue.dart:9`). `on QueueClosedException` therefore catches only the queue-drop case, not a generic `StateError` a real `requestDevices` might throw. The "swallow only" guard holds.

**`yield*` placement — correct:** keeping `yield* devicesStream` outside the `try` means errors emitted by the inner stream during scanning bypass the catch and reach the listener's `onError`. This is exactly what Case 2 asserts.

**Definite-assignment pattern — valid Dart:** `final Stream<...> devicesStream;` declared without initializer, assigned in `try`, used after, with a catch that always `return`s. Dart flow analysis treats the `on QueueClosedException { return; }` branch as not completing normally, so the only normal path to `yield*` is through the successful assignment. Compiles cleanly.

## Determinism of Case 1 — independently confirmed

I traced both possible `async*` subscription-scheduling behaviors against `SerialCommandQueue` and the `_doDispose` synchronous prefix:

- `dispose()` → `_doDispose()` runs its synchronous prefix before the first `await`, so `_queue.close()` (sets `_closed = true`) executes during the `dispose()` call, before the trailing `await Future.delayed(Duration.zero)`.
- **If the generator body runs synchronously on `.listen()`:** the enqueue registers a `_tail.then` continuation while `_closed == false`; that continuation runs as a microtask *after* `close()`, hits the re-check at `SerialCommandQueue.dart:68`, and rejects with `QueueClosedException`.
- **If the body is scheduled as a microtask:** the body runs *after* `close()`, so `enqueue` hits the early `if (_closed)` branch at `:56` and rejects immediately with `QueueClosedException`.

Either way the swallow is exercised and `onDone` fires with `errored == false`. The host test runs with `Platform.isIOS == false` and `Platform.isAndroid == false`, so no permission `await` precedes the enqueue — the enqueue is the first suspension point, which is what makes the ordering tight. The plan's warning against inserting a settling `await` before `dispose()` (which would let the enqueue resolve first and produce a false green) is accurate and worth keeping verbatim.

`_doDispose`'s `await _queue.idle` still resolves: the scan slot's continuation completes its completer with an error but returns normally, so `_tail` never rejects and `idle` settles.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** `WARN`/none — the fix stays entirely at the `NeiryBciProvider` seam (the documented `neiry_kit` boundary class) and touches neither `BciDeviceManager` nor `SerialCommandQueue`, honoring the one-directional queue constraint. No boundary violation.
- **Rules (`.ai-factory/RULES.md`):** none. The silent `return` on swallow (no log) is consistent with the existing precedent at `:473`, where only non-`QueueClosedException` errors are logged; "Logging: minimal" in the plan matches. Tests use the project's established `FakeLocatorPort` pattern.
- **Roadmap (`.ai-factory/ROADMAP.md:310`):** aligned. The plan implements T4 exactly as specified (swallow only `QueueClosedException`, end stream cleanly, genuine errors propagate, test added) and matches the spec note `.ai-factory/notes/168-bci-scan-swallow-queueclosed.md`.

## Minor observations (non-blocking)

- **`emitError` helper scope:** Case 2 adds `emitError(Object)` to `FakeLocatorPort` via `_devicesController.addError(...)`. `_devicesController` is a single-subscription controller and `addError` does not close it, so the existing `emitDevices` tests are unaffected and the post-error `sub.cancel()` is clean. No change to existing tests' behavior — consistent with the plan's "minimally extend" instruction.
- **Optional:** the implementer may add a one-line `// swallow post-dispose QueueClosedException; see note 168` comment at the catch to keep the seam self-documenting, mirroring the rationale block at `:462–476`. Not required.

## Positive Notes

- Spec note, ROADMAP milestone, and plan are in full agreement — no drift.
- The plan pre-empts the single most likely test mistake (settling before `dispose()`) and explains *why* it would be a false green.
- Opposite-sequencing requirement between Case 1 (dispose-before-settle) and Case 2 (settle-before-error) is called out explicitly, preventing a copy-paste error.

PLAN_REVIEW_PASS
