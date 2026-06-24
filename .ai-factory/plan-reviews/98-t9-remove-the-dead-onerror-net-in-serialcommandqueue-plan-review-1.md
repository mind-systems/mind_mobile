## Plan Review Summary

**Plan:** Remove the dead `onError` net in `SerialCommandQueue`
**Files Reviewed:** plan + `lib/Bci/SerialCommandQueue.dart` + `test/Bci/neiry_bci_provider_command_queue_test.dart`
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Present. Change stays inside `lib/Bci/` and preserves the "pure Dart, no Flutter/Riverpod" constraint already documented in the file header. No boundary or dependency impact. **PASS.**
- **Rules (`.ai-factory/RULES.md`):** Present. The three rules cover module Services / App.dart / constructor-injection — none touch `SerialCommandQueue`. No violation. **PASS.**
- **Roadmap (`.ai-factory/ROADMAP.md`):** Present. The plan maps 1:1 to the open milestone **T9 · Remove the dead `onError` net in SerialCommandQueue** (`ROADMAP.md:315`), including the same line references (`:74-79`, `:81-87`) and Done-when criteria. Linkage is explicit. **PASS.**

### Correctness of the core claim (verified against source)

The plan's central premise — that the `onError` branch is unreachable — is **correct**:

- `_tail` starts as `Future<void>.value()` (never rejects).
- Each link is `_tail = _tail.then<void>((_) async { ... })`. The async body has exactly two exit shapes: the `if (_closed) { completer.completeError(...); return; }` early-return, and the `try { await command(); ... } catch (e, st) { completer.completeError(e, st); }`. Every command error is funneled into the **per-command** `completer`, never re-thrown.
- The only way the body could throw is a double-complete on `completer`, but `completer` is freshly allocated per `enqueue` call and is completed at most once. So the body never throws → each link resolves successfully → the previous-link rejection that `onError` exists to catch can never occur.

Therefore removing the `onError:` callback (lines 81-87) and keeping the single-argument `.then` form preserves behavior exactly. The "tail never rejects" invariant is maintained, and no unhandled async rejection can leak afterward. ✅

Line references in Task 1 (`enqueue` 64-88, `try/catch` 74-79, `onError` 81-87) match the current file exactly. File path is correct. No API misuse.

### Issues

**[WARN] Task 2 references a test case that does not exist.**
Task 2 states the suite passes "including the *'throwing command does not poison the queue'* case, which proves `_tail` stays alive without the `onError` net." No such test exists in `test/Bci/neiry_bci_provider_command_queue_test.dart`. The groups present are: *serialization*, *poison-pill tail-drop* (all `close()`-driven, not a throwing command body), *post-dispose calibration safety*, and *no orphaned locator recreate on dispose*. A grep for `throw`/`poison` confirms there is no test that enqueues a **command whose body throws** and then asserts a later command still runs.

Impact is limited: because the `onError` branch is genuinely dead, the existing suite passes identically before and after the change, so the verification command (`flutter test test/Bci/neiry_bci_provider_command_queue_test.dart`) still works as a green-stays-green check. But the stated rationale is inaccurate — these tests do **not** exercise the throw-doesn't-poison invariant, so they don't actually "prove `_tail` stays alive" as Task 2 claims. The class doc-comment (`SerialCommandQueue.dart:51-52`) asserts "A throwing command does not poison the queue," yet nothing tests it.

Recommendation (non-blocking): either (a) correct Task 2's wording to drop the reference to the non-existent case and just state "run the existing suite as a regression guard," or (b) since the change directly concerns this invariant, add a small test that enqueues a throwing command followed by a normal one and asserts the second runs and the first's future rejects. The plan's "no new tests required" stance is acceptable for pure dead-code removal, but option (b) would make the invariant the change relies on actually covered.

### Critical Issues

None. The removal is safe, correctly scoped, and behavior-preserving.

### Positive Notes

- Tightly scoped: explicit "keep the continuation body exactly as is," "do not touch `close()`, `QueueClosedException`, or completer-per-command semantics," and "keep the file pure Dart" guardrails prevent scope creep.
- Line references and file paths are accurate against the current source.
- Correctly identifies the single-argument `.then<void>` form as the target shape.
- Clean roadmap linkage with matching Done-when criteria.

The plan is solid; the only finding is a non-blocking inaccuracy in Task 2's justification.

PLAN_REVIEW_PASS
