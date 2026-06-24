# Plan: C1 · Actor / serial command queue refactor (green→green)

## Context
Replace the smeared `_teardownComplete`-based serialization in `NeiryBciProvider` with one serial command queue (actor) that all locator/device ops flow through, making the H1/L1/L2 races unrepresentable by construction — while keeping the B1 + B2 characterization suites green with **no assertion edits**.

## Settings
- Testing: yes (one new unit test for the queue; existing characterization suites must stay green unchanged)
- Logging: minimal (preserve existing `logPrint` calls; add none beyond what exists)
- Docs: no

## Background (read before coding)

**Spec:** `.ai-factory/notes/157-bci-actor-serial-command-queue.md` (the three binding constraints).
**Contracts that must stay green, no assertion edits:**
- `test/Bci/neiry_bci_provider_locator_device_races_test.dart` (B1 — H1 + L2 + adversarial + partial-L1)
- `test/Bci/neiry_bci_provider_full_teardown_test.dart` (B2 — full teardown chain ordering + L1 recreate-after-throw)

**Line-number note:** the spec/roadmap cite line numbers (`:513`, `:617`, `:561-562`, `:658`, `:675`) from an older, larger copy of the file. The current `lib/Bci/NeiryBciProvider.dart` is 547 lines. Use the symbol/structure references below, not the spec's numbers:
- `_teardownComplete` field — current `:47`
- `await _teardownComplete` drains — scan `:118`, connect `:160`, disconnect `:475`
- teardown microtask assigned to `_teardownComplete` — `:404`, its `finally { _resetLocatorSession() }` — `:437-439`
- `_teardownAfterUnexpectedDrop()` — `:375`; `_onConnectionStatus` drop branch — `:250-262`
- `_resetLocatorSession()` (dispose old + recreate, guarded by `_disposed`) — `:357-366`
- `_doDispose()` (terminal, no recreate) — `:516`

**Sole external consumer:** `lib/Bci/BciDeviceManager.dart` calls `_provider.scan()` (`:179`, `:277`), `_provider.connect(serial)` (`:220`), `_provider.disconnect()` (`:269`). No other file references these or `_teardownComplete`. Public method signatures must not change.

### The three binding constraints (not open questions — do not re-raise)
1. **One-directional.** A command running in the queue's single slot must never `await` another command enqueued in that same queue (self-deadlock). Teardown runs its native steps **inline** as the command body; auto-reconnect `scan()` is **enqueued after** teardown. Dependency is strictly `reconnect-scan → teardown`, never the reverse.
2. **Terminal poison-pill `dispose`.** `dispose` (a) closes the queue to new enqueues, (b) drops the queued tail so unstarted `scan`/`connect` never spawn native resources, (c) performs the final teardown, (d) **never recreates** the locator.
3. **Atomic teardown command.** The canonical SDK order is one unit, never split or reordered: `stopStream → cancel fan-in subs → dispose classifiers → device.disconnect → device.dispose → locator.dispose → recreate (unless terminal)`. Keep each step's existing inner try/catch **and** the outer `try { ... } finally { _resetLocatorSession() }` — B2's "throwing connection-sub cancel … recreate still reached" test requires the `finally` to reach recreate even when an un-try/caught `cancel()` throws (the StateError then surfaces as an unhandled async error, which that test also asserts). "Remove the try/finally recreate" in the spec means removing the **detached `Future.microtask` assigned to `_teardownComplete`**, not the internal `finally`.

### Latitude
- The suites assert orphan invariants (`liveCount ≤ 1`, no replace-without-dispose) on racing paths, **not** tight reset counts — so a drop-teardown followed by a `disconnect()` performing a second paired dispose+recreate is allowed churn, not a bug.
- **Anti-goal — out of scope:** do NOT fold domain latches (`ModuleStateChannel`, `Breath/MeditationModuleStateChannel`, `BiometricStreamClient`) or the `channel.events` bus into this queue. Single-resource actor around the BCI locator/device only.
- **Calibration methods stay outside the queue** — `startCalibration` / `startQuickCalibration` / `importCalibration` use the static `neiry.NfbCalibrator`, not the locator/device. Leave them untouched (except `_calibrationSub` cancellation already inside `_doDispose`).

## Tasks

### Phase 1: Serial command queue primitive

- [x] **Task 1: Add the serial command queue class**
  Files: `lib/Bci/SerialCommandQueue.dart`
  Create a standalone, directly-testable serial executor (mirrors the focused single-file style of `lib/Bci/Ports/`). Public API:
  - `Future<T> enqueue<T>(Future<T> Function() command)` — chains `command` onto an internal `Future<void> _tail`; runs one command to completion before the next. Returns a `Future<T>` (backed by a `Completer<T>`) that carries the command's result/error to the **caller**, while `_tail` itself **never rejects** (the inner continuation catches and routes errors to the completer) so a throwing command does not poison subsequent commands.
  - If the queue is closed at enqueue time, immediately complete the returned future with `StateError`.
  - Each `_tail` continuation re-checks `isClosed` **before** running its command and, if closed, completes the caller's future with `StateError` and returns **without running the command** — this is the poison-pill tail-drop (constraint 2).
  - `Future<void> get idle => _tail;` — resolves when all currently-chained work has settled.
  - `void close()` — sets `_closed`; `bool get isClosed`.
  Pure Dart, no Flutter/Riverpod imports (domain layer rule). Document constraint 1 (a command must never `enqueue`+`await` on the same queue) in a class doc comment.

### Phase 2: Route locator/device ops through the queue

- [x] **Task 2: Hold the queue in the provider and wire dispose as the poison pill** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  - Add `final SerialCommandQueue _queue = SerialCommandQueue();` field; import the new file.
  - Remove the `Future<void>? _teardownComplete;` field (`:47`).
  - Rewrite `_doDispose()` (`:516`): set `_disposed = true`; call `_queue.close()` (reject new enqueues, drop unstarted tail); `await _queue.idle` (let the in-flight command finish so the final teardown does not interleave); then run the existing final teardown inline **unchanged** (stopStream-if-started → `_cancelDeviceSubscriptions` → cancel `_calibrationSub` → device disconnect/dispose → `_locator.dispose()` → close all controllers). Keep the existing try/catch swallows. It must **not** call `_resetLocatorSession()` (no recreate on the terminal path). `dispose()` stays `void` with `unawaited(_doDispose())`.

- [x] **Task 3: Convert the unexpected-drop teardown into an enqueued atomic command** (depends on Task 2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `_teardownAfterUnexpectedDrop()` (`:375`): keep the **synchronous** capture of `device`/`classifierSet`/all subs into locals and the synchronous nulling of the fields (the double-drop idempotency guard in `_onConnectionStatus` depends on `_device` being null before the next event). Replace the `_teardownComplete = Future.microtask(() async { … })` assignment (`:404-440`) with a **fire-and-forget** `_queue.enqueue(() async { … })` whose body is the **identical** canonical sequence currently inside the microtask, including the outer `try { stopStream → cancel 10 subs → dispose classifiers → device disconnect/dispose } finally { await _resetLocatorSession(); }`. Do not await the returned future (preserves the old fire-and-forget semantics; on the throwing-cancel path the unobserved rejected future surfaces as an unhandled async error, as B2 asserts). `_onConnectionStatus` (`:250-262`) is otherwise unchanged.

- [x] **Task 4: Route `connect()` and `disconnect()` through the queue** (depends on Task 2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  - `connect(serial)` (`:158`): delete the `try { await _teardownComplete; } catch (_) {}` drain (`:160`). Move the entire body (the `_device != null` StateError guard, `createDevice` → `connect` → build classifiers → `start`, the failure-cleanup `catch` block that disposes classifierSet/device and calls `_resetLocatorSession()` then rethrows, and the final `_subscribeDeviceStreams()`) into `return _queue.enqueue(() async { … });`. Keep the guard and cleanup logic byte-for-byte inside the command so it runs serialized and the partial-L1 test still sees dispose+recreate on failure.
  - `disconnect()` (`:473`): delete the drain (`:475`). Wrap the existing body (stopStream-if-started → `_cancelDeviceSubscriptions` → device disconnect/dispose → `_device = null` → `_resetLocatorSession()` → emit `BciLinkStatus.down`) into `await _queue.enqueue(() async { … });`. Behavior unchanged; ordering now owned by the queue.

- [x] **Task 5: Route `scan()` through the queue** (depends on Task 2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `scan()` (`:116`, `async*`): delete the `try { await _teardownComplete; } catch (_) {}` drain (`:118`). Keep the iOS/Android permission checks where they are (they do not touch the locator). Replace the final `yield* _locator.requestDevices(...)` (`:153`) with:
  ```
  final devicesStream = await _queue.enqueue(
    () async => _locator.requestDevices(type: BciScanDeviceType.headband, searchTime: 5),
  );
  yield* devicesStream;
  ```
  This makes `requestDevices()` land on whatever `_locator` exists **after** any in-flight teardown command completes (the fresh post-recreate locator) — the H1 contract. Do not call `requestDevices` outside the command.

### Phase 3: Verify and lock in

- [x] **Task 6: Add a focused unit test for the queue** (depends on Task 1, Task 2)
  Files: `test/Bci/neiry_bci_provider_command_queue_test.dart`
  Cover the spec's Verify #3 without touching existing suites:
  - **Serialization:** enqueue command A (records `'A-start'`, awaits a gate `Completer`, records `'A-end'`) then command B (records `'B-start'`); assert B has not started while A is gated, and after releasing the gate the order is `['A-start','A-end','B-start']` (no interleave).
  - **Poison-pill tail-drop:** enqueue a gated command, `close()` the queue, enqueue a second command; release the first; assert the second command body **never ran** and its future completed with `StateError`; assert enqueue after close also errors.
  - **Provider-level no-recreate-on-dispose:** using the existing fake locator/registry pattern (copy the minimal `RecordingLocatorRegistry`/fake-device helpers, or import a small shared fake), drive a connect, gate a drop-teardown so its `_resetLocatorSession` recreate is pending, call `provider.dispose()`, and assert the disposed path does **not** create a fresh locator beyond what already existed (no orphaned recreate). Keep this test self-contained; do not modify B1/B2.

- [x] **Task 7: Run the full BCI suite and confirm green→green** (depends on Tasks 3–6)
  Files: (none — verification)
  Run `/usr/local/bin/flutter test test/Bci/` and confirm all of `neiry_bci_provider_locator_device_races_test.dart`, `neiry_bci_provider_full_teardown_test.dart`, the three port suites, and the new queue test pass with **zero assertion edits** to the characterization suites. If a characterization assertion would need changing to pass, the refactor changed observable behavior and is wrong — fix the production code, not the test. Confirm `_teardownComplete` and all three drains are gone (grep) and no detached `Future.microtask` recreate remains.

## Commit Plan
- **Commit 1** (after tasks 1–2): "Add serial command queue and route provider dispose through it as poison pill"
- **Commit 2** (after tasks 3–5): "Route locator/device ops through the serial command queue and remove the teardown gate"
- **Commit 3** (after tasks 6–7): "Add command-queue unit test and confirm characterization suites stay green"
