# Plan: Create `ActiveRrSource` in `lib/Biometrics/`

## Context
Add a pure-Dart class `ActiveRrSource` that picks one currently-active source from a list of `IRrIntervalSource` instances and forwards its `RrInterval` stream. Implements preferred-with-fallback semantics with a silence watchdog. This is Milestone 1 of the heart-rate tick source feature (spec: `.ai-factory/notes/29-heart-rate-tick-source.md`). No wiring, no UI — purely additive single-file class.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Create `ActiveRrSource.dart`**
  Files: `lib/Biometrics/ActiveRrSource.dart`
  Create a new file `lib/Biometrics/ActiveRrSource.dart` containing the pure-Dart class `ActiveRrSource`. Follow the exact shape from the spec (`.ai-factory/notes/29-heart-rate-tick-source.md`, Milestone 1). Specifics:
  - Imports: `dart:async`, `package:rxdart/rxdart.dart`, `../Logger.dart` (Logger lives at `lib/Logger.dart`, not `lib/Core/Logger.dart` as the spec mistakenly shows — use the relative path `../Logger.dart` to match existing sibling files like `lib/Bci/NeiryBciProvider.dart`), `IRrIntervalSource.dart`, `Models/RrInterval.dart`.
  - Constructor `ActiveRrSource(List<IRrIntervalSource> sources)` stores `_sources = List.unmodifiable(sources)` and subscribes to each source's `rrStream` at construction, indexing by list position. Subscriptions stored in `_subs` (`List<StreamSubscription<RrInterval>>`).
  - Constants: `static const Duration _silenceFloor = Duration(seconds: 2);` and `static const double _silenceMultiplier = 2.0;`.
  - Fields: `_sources`, `_subs`, `_intervalController = StreamController<RrInterval>.broadcast()`, `_hasActiveController = BehaviorSubject<bool>.seeded(false)`, `Map<int, DateTime> _lastSeenAt = {}`, `int? _activeIndex`, `int? _lastIntervalMs`, `Timer? _watchdog`.
  - Public API:
    - `Stream<RrInterval> get stream` — returns `_intervalController.stream`, broadcast, only intervals from the currently-active source.
    - `bool get hasActiveSource` — returns `_hasActiveController.value`.
    - `Stream<bool> get hasActiveSourceStream` — returns `_hasActiveController.stream` (BehaviorSubject delivers current value to late subscribers).
  - Private `_onInterval(int index, RrInterval rr)`:
    - Update `_lastSeenAt[index] = DateTime.now()`.
    - If `rr.isArtifact`, log via `logPrint('ActiveRrSource: artifact from source[$index] (${rr.source.name}), intervalMs=${rr.intervalMs}')` — forward as-is, no filtering (single insertion point for future filter).
    - If `_activeIndex == null || index < _activeIndex!`, set `_activeIndex = index` and log `logPrint('ActiveRrSource: active source = $index (${rr.source.name})')` — handles higher-priority revival (index 0 wins; smaller index steals from larger).
    - If `index != _activeIndex` return (do not forward).
    - Set `_lastIntervalMs = rr.intervalMs`, `_intervalController.add(rr)`, call `_ensureHasActive(true)`, then `_restartWatchdog()`.
  - Private `_restartWatchdog()`:
    - Cancel any prior `_watchdog`.
    - Compute base `_lastIntervalMs ?? 1000`, window = `Duration(milliseconds: (base * _silenceMultiplier).round())`, effective = `window > _silenceFloor ? window : _silenceFloor`.
    - Start new `Timer(effective, _onSilence)`.
  - Private `_onSilence()`:
    - Walk `_sources` indices in priority order skipping the current `_activeIndex`; pick the first index whose `_lastSeenAt[i]` is within `_silenceFloor` from now.
    - If found: log `'ActiveRrSource: failover ${_activeIndex} → $next'`, set `_activeIndex = next`, `_restartWatchdog()`, return.
    - Otherwise: log `'ActiveRrSource: all sources silent'`, set `_activeIndex = null`, `_lastIntervalMs = null`, `_ensureHasActive(false)`.
  - Private `_ensureHasActive(bool value)`: add to `_hasActiveController` only when value differs from current.
  - `Future<void> dispose()`: cancel `_watchdog`; cancel each subscription in `_subs` (await each); close `_intervalController`; close `_hasActiveController`. Do NOT dispose source instances — App owns them.
  - Doc comments (Dart-doc) on the class explaining preferred-with-fallback semantics, contrast with `BioStreamRouter` (merge-everything server policy vs single-source client policy), and that artifacts are forwarded as-is in MVP. Keep wording aligned with the spec's class doc.
  - No Flutter imports, no Riverpod imports. Pure Dart only.

## Verification
- The file compiles with `flutter analyze` clean.
- `lib/Biometrics/ActiveRrSource.dart` contains no `package:flutter` or `package:riverpod` imports.
- Class is purely additive; no other file in the repo is modified by this milestone.

<!-- orchestrator-sessions
planner: 696777b2-949d-434f-9c5a-83e6f6d0281d
elapsed: 466
implementer: c43a7b20-4b8e-40c5-a161-97ce361e89ac
-->
