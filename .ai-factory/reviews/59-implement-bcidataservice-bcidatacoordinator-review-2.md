# Code Review #2: Implement `BciDataService` + `BciDataCoordinator`

**Plan:** `.ai-factory/plans/59-implement-bcidataservice-bcidatacoordinator.md`
**Prior review:** `.ai-factory/reviews/59-implement-bcidataservice-bcidatacoordinator-review-1.md`

## Scope
Verified that the two blocking items from review #1 (C1 stray Kotlin daemon file, M1 stale metrics on reconnect) have been resolved, and confirmed no regressions were introduced by the fixes.

## Changes since review #1

### C1 — Stray Kotlin compiler session file → RESOLVED
- `android/.kotlin/sessions/kotlin-compiler-3931374903587441396.salive` is no longer staged (confirmed via `git status`).
- `android/.gitignore` now includes `.kotlin/` (between `.cxx/` and the keystore section), so future Kotlin daemon sessions won't slip in.

### M1 — Stale metrics across reconnect → RESOLVED
The `BciStateChanged(:final state)` branch now uses an explicit inner `switch (state)`:
- `disconnected` / `bluetoothPermissionDenied` → clears `isConnected`, `heartRate`, `nfb`, `emotions`, `batteryPercent`, `channels` (set to a const empty list).
- `scanning` / `connecting` → only flips `isConnected: false` (keeps other fields).
- `impedance` / `calibrating` / `ready` → only flips `isConnected: true`.

Branches use Dart 3 fall-through shared-body syntax (`case A: case B: <return>`), which is valid. The inner switch is exhaustive over the 7-value enum; each branch ends in `return`, so the outer switch's `BciStateChanged` arm has no fall-through risk.

## Re-verification of the rest of the file

Read `lib/BciModule/BciDataService.dart` (112 lines) in full:
- Imports are tight and correct: `rxdart`, the package barrel, plus the three domain files needed for the sealed event class, connection enum, and `BciSignalLevel`.
- Outer switch over `BciNotifierEvent` remains exhaustive (9 variants matched, no `default:`).
- DTO construction mappings unchanged — still correct against `BciNfbData` / `BciEmotionsData` / `BciCardioData` field shapes.
- `_mapLevel` retained as a local helper (no coupling to `BciPairingService`).
- `events` getter is still a pure derived stream over `bciNotifier.stream` — no `StreamController`, no `StreamSubscription` owned by the service.

`lib/BciModule/BciDataCoordinator.dart` is unchanged from review #1 and remains correct.

## Remaining (non-blocking) notes
- **L1 (cold-start BehaviorSubject replay)** — still pre-existing; plan explicitly defers to a follow-up milestone. Not introduced by this change.
- **L2 (`heartRate.round()` on `NaN`/`Infinity`)** — optional hardening only; device should never emit non-finite with `metricsAvailable: true`. Not a blocker.

## Verdict
Both blocking items from review #1 are addressed correctly and without collateral damage. The change is ready to merge.

REVIEW_PASS
