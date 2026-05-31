# Task Spec — Align `BciPairingViewModel` to subscribe in `build()`

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 44 E2 (note 39 Area E)

## Current state
`packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart` subscribes to `service.events` in a separate `initState()` that the screen must call explicitly (it also fires `startScan()`), unlike the canonical pattern used by `BciDataViewModel` and `BreathSessionListViewModel` (subscribe in `build()` + cancel in `ref.onDispose`).

## Naming note (verified)
`IBciPairingService` declares `Stream<BciPairingServiceEvent> observeChanges();` — a **method**, and the VM already calls `service.observeChanges()`. (The `events` getter belongs to the *data* service `IBciDataService`, a different interface — don't confuse the two.) So `observeChanges()` below is correct.

## Target
- Move the `service.observeChanges().listen(_onServiceEvent)` subscription and the `service.startScan()` call into `build()` (after seeding initial state, via the existing `ref.onDispose` cancel-and-null).
- Delete the public `initState()` method and its caller in `BciPairingScreen.initState` (the post-frame `ref.read(...notifier).initState()`).
- The `if (_eventsSubscription != null) return` guard becomes unnecessary once `build()` owns the single subscription — drop it.

## Guards
- Don't forget the call-site removal in `BciPairingScreen` — leaving the `initState()` call after deleting the method is a compile error.

## Files
- `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
- `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`
