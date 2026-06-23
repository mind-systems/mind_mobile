# Plan: Recreate the SDK DeviceLocator on every disconnect (NeiryBciProvider)

## Context
The vendored Capsule SDK caches `clCDevice` per serial inside `clCDeviceLocator` and never evicts it on release, so reconnecting through the same locator hands back the identical stale native device. Recreating the `DeviceLocator` on every non-terminal teardown path guarantees a genuinely fresh `clCDevice`/session on reconnect.

`DeviceLocator()` is a process-wide singleton factory; `dispose()` sets the singleton to null so the next `DeviceLocator()` constructs a fresh native session, and `dispose()` throws `StateError` if already disposed (every `dispose()` call is therefore wrapped in try/catch).

### Concurrency hazard this plan must resolve (review H1)
The three synchronous teardown paths (`connect()` failure, `disconnect()`) are fully awaited before any re-scan can occur, so a plain inline reset is safe there. The **unexpected-drop** path is different: `_teardownAfterUnexpectedDrop()` nulls fields synchronously and schedules the heavy disposal as a **fire-and-forget microtask**, then `BciDeviceManager` receives `BciLinkStatus.down` and immediately calls `_attemptReconnect()` → `_provider.scan()`. The teardown microtask reaches the locator reset only after ~16 awaits, while `scan()` reaches `_locator.requestDevices()` after only 1–3 permission awaits. They run **concurrently on the same `_locator` field**: the reconnect scan can start on the old locator, then the microtask calls `_locator.dispose()` on that same instance — which cancels the active scan's binary message handler without closing its `StreamController`. The scan stream then never emits/completes/errors, and `BciDeviceManager` hangs in `BciScanning` forever (silent, intermittent, timing-dependent).

The fix is a provider-owned **teardown-completion gate** (`_teardownComplete`) that `scan()` and `connect()` await before reading `_locator`, serializing the reconnect scan behind the locator reset. This keeps all changes inside `NeiryBciProvider` (the only file permitted to import `neiry_kit`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

All changes are confined to `lib/Bci/NeiryBciProvider.dart`. Spec: `.ai-factory/notes/145-bci-locator-recreate-on-disconnect.md`.

### Phase 1: Locator session reset

- [x] **Task 1: Make `_locator` mutable; add the dispose guard, teardown gate, and reset helper**
  Files: `lib/Bci/NeiryBciProvider.dart`
  - Change the field at ~L35 from `final _locator = neiry.DeviceLocator();` to a mutable, explicitly-typed field: `neiry.DeviceLocator _locator = neiry.DeviceLocator();`.
  - Add `bool _disposed = false;` — the terminal-dispose guard used by Tasks 3 and 4. (Confirmed no existing `_disposed` member on this class.)
  - Add `Future<void>? _teardownComplete;` — the unexpected-drop completion gate. Null until the first unexpected drop; reassigned on each drop; a completed future thereafter (awaiting it is a no-op).
  - Add a private async helper `_resetLocatorSession()`:
    ```dart
    /// Disposes the current locator and replaces it with a fresh one so the
    /// next connect() goes through a brand-new native session. The SDK caches
    /// clCDevice per serial inside the locator and never evicts on release, so
    /// reusing the same locator returns a stale device on reconnect.
    /// No-op once the provider has been terminally disposed.
    Future<void> _resetLocatorSession() async {
      if (_disposed) return;
      try {
        await _locator.dispose();
      } catch (_) {
        // StateError on double-dispose — locator already torn down.
      }
      if (_disposed) return;
      _locator = neiry.DeviceLocator();
    }
    ```
  - The second `_disposed` check after the `await` is intentional: it prevents a microtask scheduled by `_teardownAfterUnexpectedDrop()` from recreating a locator after the provider was terminally disposed mid-await (which would leak a never-disposed native session).

- [x] **Task 2: Reset the locator in the synchronous teardown paths** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Insert `await _resetLocatorSession();` after the device is disposed and `_device` is nulled, in each of:
  1. **`connect()` failure cleanup** (~L162–185): after `_device = null;` and before `rethrow;`. The catch block is already `async`, so awaiting here is fine — a failed connect must leave a clean locator.
  2. **`disconnect()`** (~L589): immediately after `_device = null;` and before the `_connectionStateController.add(BciLinkStatus.down);` emit.
  These two paths are fully awaited by their callers before any re-scan, so an inline reset is race-free here.

- [x] **Task 3: Reset the locator in the unexpected-drop microtask via the completion gate** (depends on Task 1) — resolves review H1
  Files: `lib/Bci/NeiryBciProvider.dart`
  - In `_teardownAfterUnexpectedDrop()` (~L464–511), replace `unawaited(Future.microtask(() async { ... }))` with an assignment to the gate field, and append the locator reset as the **final** step of the microtask (after Step 4, the device `disconnect()`/`dispose()`):
    ```dart
    _teardownComplete = Future.microtask(() async {
      // ...existing Steps 1–4 unchanged (stopStream → cancel subs → dispose
      // classifiers → device disconnect/dispose)...
      await _resetLocatorSession();
    });
    ```
    Storing the future in a field satisfies the `unawaited_futures` lint without `unawaited(...)`. The microtask still runs fire-and-forget from the synchronous method's perspective. Each unexpected drop reassigns a fresh future; clean-disconnect paths never reassign it (a stale completed future awaits instantly).
  - Add the gate await at the very top of **`scan()`** (~L103), before the permission checks and before `_locator` is read:
    ```dart
    try { await _teardownComplete; } catch (_) {}
    ```
    This serializes the reconnect scan behind the locator reset, so `requestDevices()` always runs against the fresh locator. (`_teardownComplete` is null on first scan → `await null` completes immediately; the microtask swallows its own errors so the future never rejects, but the try/catch is defensive.)
  - Add the same gate await at the top of **`connect()`** (~L147), before reading `_locator` (i.e. before the `_device != null` guard / `_locator.createDevice`). Idempotent once the gate has completed; ensures a reconnect's `createDevice` also runs on the fresh locator regardless of call ordering.

- [x] **Task 4: Dispose (do not recreate) the locator in the terminal path** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `_doDispose()` (~L603–627):
  - Set `_disposed = true;` at the very start of the method, before any `await`. This makes any in-flight `_resetLocatorSession()` from an overlapping `_teardownAfterUnexpectedDrop()` microtask bail out instead of recreating a locator on a dying provider.
  - After the existing device disconnect/dispose block (~L611–616) and before/alongside the `StreamController.close()` calls, dispose the locator **without recreating it** (the provider is being destroyed):
    ```dart
    try {
      await _locator.dispose();
    } catch (_) {
      // StateError if already disposed by a teardown path that ran first.
    }
    ```
  - Do NOT call `_resetLocatorSession()` here — it would recreate a locator that is never disposed. This is the only path that disposes without recreating.

## Verification (on-device, manual — per note 145)

- **Pointer identity (task 145 success signal):** with temporary native/Dart logging of the device pointer at create+release, the reconnect device pointer must now **differ** from the pre-disconnect pointer across both reconnect routes (clean `disconnect()` → user reconnect, and unexpected-drop → `_attemptReconnect()`).
- **H1 — unexpected-drop reconnect does not hang:** trigger an unexpected drop (power off / out of range) on SM A705FN; confirm `_attemptReconnect()` proceeds to discovery + reconnect and `BciDeviceManager` does **not** get stuck in `BciScanning`. Repeat several times to shake out the timing-dependent race.
- **M1 — first scan on a freshly-recreated locator behaves:** `requestDevices()` does not await the locator's `_nativeReady`, so the first reconnect scan runs against a just-constructed locator whose native `create` may still be in flight. Verify the first reconnect scan discovers the device (does not come up empty/error). If it proves flaky in practice, record it in note 145 as a follow-up (e.g. a short readiness delay or a kit-side `_nativeReady` await in `requestDevices`) — out of scope for this single-file change.
- **Functional (requires kit bump, note 148 / commit `836699b`, already merged):** calibrate → disconnect → reconnect → calibrate again succeeds with no SIGABRT and no code-255, for both reconnect routes.
