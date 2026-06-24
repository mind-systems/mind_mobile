# Plan Review: T4 · scan() leaks QueueClosedException → spurious BciIdle

**Plan:** `93-t4-scan-leaks-queueclosedexception-spurious-bciidle.md`
**Files Reviewed:** 1 plan + 4 source/test/note files
**Risk Level:** 🟢 Low

## Verdict

The plan's core approach is **correct and well-targeted**. The fix lives exactly where it should (the provider seam), all line/file references check out, no new import is needed, and the guards match the architecture. There is **one substantive issue** in the test phase (Task 2, Case 1) that, if implemented as the surrounding prose hints, would produce a vacuous test that passes without exercising the fix. Resolve that before implementing.

## Verification of plan claims (all confirmed)

- `scan()` is at `:118`; the `await _queue.enqueue(...)` is at `:156`; `yield* devicesStream` at `:159`. ✓
- `QueueClosedException` is already in scope via `import 'SerialCommandQueue.dart';` (line 18) and used at `:473`. **No new import needed.** ✓ (Minor wording nit: the plan calls `:473` an "import" — it is a *usage* site; the import is at `:18`. Intent is clear.)
- `QueueClosedException extends StateError` and is thrown **only** by the queue on enqueue-after-close — so catching it cannot mask a genuine `requestDevices` failure. ✓
- The scan command `() async => _locator.requestDevices(...)` returns the stream synchronously; a genuine `requestDevices` error surfaces via `yield* devicesStream` (outside the try) or, if it throws synchronously, via the enqueue await as a non-`QueueClosedException` — both correctly propagate to `onError`. The single-type catch is sound. ✓
- Swallowing silently with no log is consistent with the existing `:473` pattern and the plan's "Logging: minimal" setting. ✓

## Critical Issues

None.

## Issues / Recommendations

### 1. Task 2 Case 1 — sequencing ambiguity risks a vacuous test (WARN, should fix)

The plan correctly states dispose must happen "**while the scan slot is still pending in the queue**," but then says "Follow the existing async-settling style (`await Future<void>.delayed(Duration.zero)` to let the `async*` generator advance through the enqueue await)." These two instructions conflict for Case 1.

To actually hit the `QueueClosedException` path, the sequence must be:

```dart
final sub = provider.scan().listen(..., onError: onErr, onDone: onDone);
provider.dispose();                       // close() runs SYNCHRONOUSLY — no await before this
await Future<void>.delayed(Duration.zero); // settle AFTER dispose
// assert onDone fired, onError NOT called
```

`scan()` registers the enqueue synchronously during `.listen()` (suspends at the `await`). `dispose()` → `_doDispose()` runs its synchronous prefix (`_queue.close()`) before any microtask drains, so the pending slot's continuation sees `_closed == true` and rejects with `QueueClosedException`. This is **deterministic** — no real race.

But if the implementer inserts `await Future.delayed(Duration.zero)` *before* `dispose()` (mirroring the existing two tests), the enqueue resolves first, the generator reaches `yield*`, and dispose merely closes `_devicesController` → the stream still ends via `onDone` with no error. The test would **pass without ever exercising the swallow** — a false green.

**Recommendation:** make Task 2 explicit that for Case 1, `dispose()` must be called immediately after `listen()` with **no settling await in between**, and the single `await Future.delayed(Duration.zero)` goes *after* dispose. Note that Case 1 and Case 2 require opposite sequencing (Case 2 *does* need to settle first so `yield*` subscribes before `emitError`), so the blanket "follow the async-settling style" note should not be applied uniformly.

### 2. Implementation detail — variable declaration around the try (informational)

`devicesStream` (type `Stream<List<BciDeviceInfo>>`) is assigned inside the try and used after it, so it must be declared before the try (or the `yield*` placed such that the catch's `return` skips it). The natural shape:

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

`final` + definite assignment works because the catch always `return`s. No flaw — just flagging so the implementer doesn't reach for a nullable.

### 3. Stale comment in the existing test file (informational, out of scope)

Lines 96–98 of the test reference `await _teardownComplete`, which the Phase-55 refactor removed. The new test should not copy that stale comment. Optional cleanup; not required by this plan.

## Context Gates

- **Architecture** (`ARCHITECTURE.md` present): The fix respects the port/seam boundary — `NeiryBciProvider` is the only place allowed to bridge the queue/locator, and the change touches neither `BciDeviceManager` nor `SerialCommandQueue`. Aligned. — **OK**
- **Rules** (`RULES.md` present): The three project rules concern Module Services, App.dart, and constructor injection — none apply to this provider-internal change. — **OK**
- **Roadmap** (`ROADMAP.md` present): Work is tracked as Phase 56 / T4 (per the spec note). Linkage present. — **OK**
- **skill-context** (`aif-review/SKILL.md`): not present — no project-specific review overrides to apply. — WARN (optional file absent)

## Positive Notes

- Single-type catch (`QueueClosedException` only) is exactly right — genuine errors still surface, matching the note's guard.
- The `yield*` correctly kept outside the try preserves real in-stream error propagation.
- Test plan covers both the swallow path and the negative (real-error-surfaces) path — the negative case is what prevents the fix from regressing into a blanket catch.
- Correctly scoped: no queue, manager, or proto changes; consistent with the no-log precedent at `:473`.

---
The plan is fundamentally sound; address finding #1 (test sequencing) so the post-dispose test genuinely exercises the swallow rather than passing vacuously.
