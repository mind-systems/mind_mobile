# Plan Review 2: T4 · scan() leaks QueueClosedException → spurious BciIdle

**Plan:** `93-t4-scan-leaks-queueclosedexception-spurious-bciidle.md`
**Files Reviewed:** 1 plan + 5 source/test/note files (`NeiryBciProvider.dart`, `SerialCommandQueue.dart`, `BciDeviceManager.dart`, `neiry_bci_provider_locator_port_test.dart`, spec note 168)
**Risk Level:** 🟢 Low

## Verdict

The fix design is correct and well-scoped — the seam, the single-type catch, and the no-manager-change guard are all right. **However, the one substantive issue raised in plan-review-1 (Task 2, Case 1 test sequencing) was not incorporated into this revision.** The plan text is byte-for-byte unchanged on that point: Task 2 still appends the blanket instruction *"Follow the existing async-settling style in this file (`await Future<void>.delayed(Duration.zero)` to let the `async*` generator advance through the enqueue await),"* which directly conflicts with what Case 1 needs and risks a vacuous (false-green) test. Resolve this one item before implementing.

## Re-verification of plan claims (all still confirmed)

- `scan()` at `:118`; `await _queue.enqueue(...)` at `:156`; `yield* devicesStream` at `:159`. ✓
- `QueueClosedException` already in scope via `import 'SerialCommandQueue.dart';` (`:18`); used at `:473`. No new import needed. (Plan's wording "import already used at `:473`" is a usage site, not the import — harmless nit carried over from review-1.) ✓
- `QueueClosedException extends StateError` and is thrown **only** by the queue (`SerialCommandQueue.dart:58`, `:70`) on enqueue-after-close — never by `requestDevices`. So a single-type catch cannot mask a genuine scan failure. ✓
- The scan command `() async => _locator.requestDevices(...)` returns the stream; a real `requestDevices` error surfaces either through `yield* devicesStream` (kept outside the try) or, if thrown synchronously, as a non-`QueueClosedException` through the enqueue await — both reach `onError`. ✓
- Consumer impact is real: `BciDeviceManager.startScan` (`onError` `:198` → `BciIdle` `:206`) and `_attemptReconnect` (`onError` `:293` → `BciIdle` `:304`) both turn a scan error into a spurious `BciIdle`. Ending the stream via `onDone` instead is benign — `onDone` only sets `BciIdle` if still `BciScanning` (`:209`, `:307`), which is the correct terminal state after dispose. ✓
- Test group `'NeiryBciProvider — LocatorPort injectable seam'` and `FakeLocatorPort` pattern exist as described; the fake currently has no error-emission helper, so Case 2 will require the minimal `emitError` extension the plan already anticipates. ✓
- Spec note `.ai-factory/notes/168-bci-scan-swallow-queueclosed.md` exists and matches the plan's rationale. ✓

## Context Gates

- **Architecture** (`ARCHITECTURE.md` present): Change is confined to the `NeiryBciProvider` seam — the only sanctioned place to bridge queue/locator. No `BciDeviceManager` or `SerialCommandQueue` edits. Boundary respected. — **OK**
- **Rules** (`RULES.md` present): Project rules concern Module Services / App.dart / constructor injection — none apply to this provider-internal change. — **OK**
- **Roadmap** (`ROADMAP.md` present): Tracked as Phase 56 / T4 per note 168. Linkage present. — **OK**
- **skill-context** (`aif-review/SKILL.md`): not present — no project-specific overrides. — WARN (optional file absent)

## Critical Issues

None.

## Issues / Recommendations

### 1. Task 2 Case 1 — sequencing instruction unchanged from review-1; still risks a vacuous test (WARN — must fix before implement)

This is the same finding as plan-review-1 #1. It was not addressed in this revision. Restating it because the plan still carries the contradiction:

- Case 1 demands dispose happen **while the enqueue slot is still pending** (so the await rejects with `QueueClosedException` and the swallow runs).
- The trailing "follow the async-settling style … `delayed(Duration.zero)`" note, if applied uniformly, leads an implementer to settle **before** `dispose()`. In that ordering the enqueue resolves first, `yield*` subscribes to the fake's stream, and `dispose()` merely closes `_devicesController` → the stream ends via `onDone` with no error. **The test passes without ever exercising the swallow.**

Required deterministic sequence for Case 1 (no settling await before dispose):

```dart
final sub = provider.scan().listen(onData, onError: onErr, onDone: onDone);
provider.dispose();                         // _doDispose() runs _queue.close() synchronously
await Future<void>.delayed(Duration.zero);  // settle AFTER dispose
// assert: onDone fired, onError NOT called (no QueueClosedException)
```

Mechanics confirmed against the code: `dispose()` → `unawaited(_doDispose())`; `_doDispose()` sets `_disposed = true` and calls `_queue.close()` **synchronously** before its first `await` (`NeiryBciProvider.dart:555–559`). The generator's enqueue continuation then runs after the queue is closed, and `enqueue` completes the future with `QueueClosedException` via the synchronous `if (_closed)` branch (`SerialCommandQueue.dart:56`). Deterministic, no real race.

Case 2 needs the **opposite** ordering — settle first so `yield*` is subscribed, *then* `emitError` — so the blanket note cannot be applied to both cases.

**Fix:** edit Task 2 to (a) state explicitly that Case 1 calls `dispose()` immediately after `listen()` with **no** settling await before it, the single settle going after dispose; and (b) scope the "async-settling style" note to Case 2 only.

### 2. Implementation shape — declare `devicesStream` before the try (informational)

`devicesStream` is assigned inside the try and consumed after it, so it must be declared outside. `final` + definite assignment works because the catch always `return`s:

```dart
final Stream<List<BciDeviceInfo>> devicesStream;
try {
  devicesStream = await _queue.enqueue(
    () async => _locator.requestDevices(type: BciScanDeviceType.headband, searchTime: 5),
  );
} on QueueClosedException {
  return;
}
yield* devicesStream;
```

No flaw — flagged so the implementer doesn't reach for a nullable.

### 3. Stale comment in the existing test (informational, out of scope)

Test lines 96–98 reference `await _teardownComplete` (removed by the Phase-55 refactor). The new test should not copy that comment; existing cleanup is optional and not required by this plan.

## Positive Notes

- Single-type catch (`QueueClosedException` only) is exactly right — genuine errors still surface; matches the note's guard and the existing `:473` precedent.
- `yield*` kept outside the try preserves real in-stream error propagation.
- Test plan covers both the swallow path and the negative (real-error-surfaces) path — the negative case is what prevents a regression into a blanket catch.
- Correctly scoped: no queue, manager, or proto changes; silent swallow consistent with "Logging: minimal."

---
The fix is sound and ready; the only blocker is that plan-review-1's finding #1 was not folded into Task 2. Make the Case 1 sequencing explicit (and scope the settling note to Case 2) so the post-dispose test genuinely exercises the swallow rather than passing vacuously. Not passing this round for that reason.
