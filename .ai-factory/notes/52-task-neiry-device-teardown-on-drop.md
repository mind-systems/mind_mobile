# Task Spec — Tear down the neiry `Device` on an unexpected disconnect so auto-reconnect works

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 44 Q1 (note 38 Area D) — highest-impact BCI fix

## Current state
`lib/Bci/NeiryBciProvider.dart`: on a native drop, `_onNeiryConnectionState` only forwards the `disconnected` event — it never cancels the classifier subscriptions or nulls `_device`. Meanwhile `connect()` hard-throws `StateError` when `_device != null`, so `BciDeviceManager._attemptReconnect → connectDevice → provider.connect()` always throws and the stale `Device` + classifiers leak.

## SDK facts (note 44 Q1)
- neiry does NOT auto-reconnect.
- **Classifiers are non-idempotent — creating one twice on the same `Device` causes a fatal SIGABRT** (`neiry_kit/docs/guides/session-guide.md:131`). So the live `NfbClassifier`/`CardioClassifier`/`EmotionsClassifier`/`MEMSClassifier` AND the `Device` MUST be disposed before any reconnect.
- The reference impl (`neiry_kit/example/.../neiry_service.dart`) disposes everything and recreates via the locator.

## Target
In `_onNeiryConnectionState`'s `disconnected`/`unsupportedConnection` cases, when `_device != null` (an unexpected drop, not our own `disconnect()`):
1. Capture the current device + four classifiers into locals.
2. **Synchronously null `_device` and the classifier fields BEFORE** `_connectionStateController.add(BciConnectionState.disconnected)` — so `BciDeviceManager`'s reconnect sees `_device == null` and `connect()` recreates a fresh device.
3. Dispose the locals fire-and-forget (cancel the 11 subscriptions, dispose classifiers, `disconnect()`+`dispose()` the device) in an unawaited/microtask path to avoid re-entrancy inside `_connectionSub`'s own callback.

Reuses the teardown shape of `_cancelDeviceSubscriptions()`.

## Guards
- Order is load-bearing: nullify `_device` strictly **before** emitting `disconnected`, else the manager races a non-null `_device` → `StateError`.
- Do heavy disposal async (microtask), not synchronously inside the connection-state callback.
- Idempotency: guard with `if (_device == null) return;` — a **true no-op** (NOT `{ emit; return; }`). The real-drop path already emitted `disconnected` synchronously (step 2). The guard only fires for a *second* native event in the brief window before the async teardown cancels `_connectionSub` (or after our own `disconnect()` already nulled `_device`); emitting a second `disconnected` there is redundant noise, so just `return`.

## Files
- `lib/Bci/NeiryBciProvider.dart` (one file).

## Verify
On-device drop test (`/verify`): power off the headband while connected → confirm `BciDeviceManager` re-scans and re-pairs without `StateError`, and no SIGABRT.
