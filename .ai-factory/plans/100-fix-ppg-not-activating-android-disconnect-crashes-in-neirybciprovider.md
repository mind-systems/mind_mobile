# Plan: Fix PPG not activating + Android disconnect crashes in `NeiryBciProvider`

## Context
Fixes two `neiry_kit` SDK invariant violations in `lib/Bci/NeiryBciProvider.dart`: classifiers created too late (PPG LED never turns on) and missing teardown steps that crash the native layer on Android disconnect/unexpected drop. Only one file changes.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fixes

- [x] **Task 1: Instantiate all four classifiers before `start()` in `connect()`**
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `connect()` (lines 155–161), reorder so the four `new Classifier(_device!)` lines run **before** `await _device!.start()`, right after `await _device!.connect()`. Final order: `connect()` → `_nfbClassifier = neiry.NfbClassifier(_device!)` → `_cardioClassifier = neiry.CardioClassifier(_device!)` → `_emotionsClassifier = neiry.EmotionsClassifier(_device!)` → `_memsClassifier = neiry.MEMSClassifier(_device!)` → `await _device!.start()`. Creating `CardioClassifier` fires the SDK's internal `StartPPG` hardware mode switch, which must happen before streaming starts. Do NOT change the existing `catch` cleanup block (lines 162–185) — it already disposes any classifiers created before a failure. The comment at line 205 ("All four classifiers are guaranteed non-null here") remains valid.

- [x] **Task 2: Add missing teardown steps to `disconnect()`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `disconnect()` (lines 553–566): add `await _device?.unregisterCallbacks();` as the first statement, **before** `await _cancelDeviceSubscriptions();` (SDK requires unregistering callbacks before any Dart subscription `.cancel()`). Inside the existing `try` block, add `await _device?.stopStream();` **before** `await _device?.disconnect();` (native streaming must stop before disconnect). Leave the rest of the method (`dispose()`, field nulling, explicit `disconnected` emit) unchanged.

- [x] **Task 3: Add missing teardown steps to `_teardownAfterUnexpectedDrop()`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Inside the `unawaited(Future.microtask(...))` block (lines 464–502): add `try { await device?.unregisterCallbacks(); } catch (_) {}` as the **first** statement, before the subscription `.cancel()` calls. Add `try { await device?.stopStream(); } catch (_) {}` **before** the existing `try { await device?.disconnect(); await device?.dispose(); }` block. On an unexpected drop the native side may already be gone, so both new calls must be wrapped in `try/catch` and continue regardless. The captured `device` local is already in scope; leave all subscription cancellations and classifier disposes unchanged.

## Notes
- `Device.unregisterCallbacks()` and `Device.stopStream()` are already public on `neiry_kit`'s `Device` (`neiry_kit/lib/src/api/device.dart`), both `Future<void>`. No `neiry_kit` changes.
- Scope is strictly the two methods named in the milestone. Do not modify `_doDispose()` or `_cancelDeviceSubscriptions()`.
- Spec reference: `.ai-factory/notes/82-neiry-bci-provider-crash-fixes.md`.
