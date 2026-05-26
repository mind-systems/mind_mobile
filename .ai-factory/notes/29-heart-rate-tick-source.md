# Heart-Rate Tick Source — ActiveRrSource, HeartRateTickService, SwitchableTickService, UI

**Date:** 2026-05-24
**Used by:** ROADMAP Phase 22 milestones 1–7
**Depends on:** Phase 21 milestones 1–9 (capability mixins, `IRrIntervalSource`, `NeiryBciProvider.rrStream`) and Phase 20 M2 (`SessionBottomBar.leadingActions` slot + mute button)

Drive the breathing-session tick from RR-intervals supplied by a BCI (or any future cardio device) instead of the wall clock. Toggleable from the session screen — heart icon in `SessionBottomBar.leadingActions`, right of mute. When all RR sources go silent, fall back to the clock automatically and clear the heart-icon highlight.

The RR consumer for the tick is **client-side and single-active-source** with preferred-with-fallback semantics. This is the opposite of the **server-bound** RR consumer (`BioStreamRouter`) which merges every source and lets server analytics decide. Two policies, two separate consumers, same underlying `IRrIntervalSource` instances.

---

## Architecture

```
IRrIntervalSource instances (NeiryBciProvider today, others tomorrow)
        │
        ├──▶ BioStreamRouter.registerRrIntervalSource(...)        (server pipeline — Phase 21)
        │
        └──▶ ActiveRrSource (this note)                            (client pipeline — preferred + fallback)
                       │
                       │   Stream<RrInterval>  ── active source only
                       ▼
              HeartRateTickService  implements ITickService
                       │
                       │   TickData(intervalMs), source = TickSource.heartbeat
                       ▼
              SwitchableTickService  implements ITickService    ◀── ClockTickService (existing)
                       │
                       │   tickStream / source / sourceChanges
                       ▼
                BreathViewModel    ── publishes state.tickSource
                       │
                       ▼
              SessionBottomBar  ── heart button (red when active)
```

Two layers, sharp boundary:

- **Layer A — `ActiveRrSource`** (`lib/Biometrics/`): pure domain. Knows about `IRrIntervalSource`, nothing about ticks or breath. Owns the preferred-with-fallback policy and the silence watchdog. Reusable by any future module that needs the current best RR stream.
- **Layer B — `HeartRateTickService` + `SwitchableTickService`** (`lib/BreathModule/`): breath-specific adapter. Wraps Layer A into the existing `ITickService` interface that the breath state machine already consumes.

The two layers exist because "which RR source do I listen to right now" is a domain concern; "how do I turn RR ticks into state-machine ticks" is a breath concern. Any future heart-driven UX (pulse visualizer, client-side HRV, anything) plugs straight into Layer A.

---

## Milestone 1 — `ActiveRrSource`

Single file `lib/Biometrics/ActiveRrSource.dart`. Pure Dart, no Flutter.

```dart
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:mind/Core/Logger.dart';
import 'IRrIntervalSource.dart';
import 'Models/RrInterval.dart';

/// Picks the **single currently-active** RR source from a static list and
/// forwards its intervals downstream. Implements preferred-with-fallback:
/// emissions go through the first source that is alive; if it falls silent
/// past the watchdog window, switches to the next alive source; if none are
/// alive, [hasActiveSource] flips to false and the stream goes quiet until a
/// source revives.
///
/// **Not** for the server pipeline — that one uses [BioStreamRouter] which
/// merges all sources unconditionally (every sample carries a `source` tag
/// and aggregation is server-side). This class is for client consumers that
/// need a single coherent RR cadence (tick source, pulse animations).
///
/// Artifacts (`RrInterval.isArtifact == true`) are forwarded as-is in MVP —
/// logged but not filtered. Animation runs after a beat using the just-passed
/// interval as a prediction of the next; in calm sitting state ≥3× swings
/// are rare and forwarding raw data is acceptable while we observe real
/// behavior. The filter slot is intentionally easy to add later (one branch
/// in `_onInterval`).
class ActiveRrSource {
  ActiveRrSource(List<IRrIntervalSource> sources)
      : _sources = List.unmodifiable(sources) {
    for (var i = 0; i < _sources.length; i++) {
      final index = i;
      _subs.add(_sources[i].rrStream.listen((rr) => _onInterval(index, rr)));
    }
  }

  static const Duration _silenceFloor = Duration(seconds: 2);
  static const double _silenceMultiplier = 2.0;

  final List<IRrIntervalSource> _sources;
  final List<StreamSubscription<RrInterval>> _subs = [];

  final _intervalController = StreamController<RrInterval>.broadcast();
  final _hasActiveController = BehaviorSubject<bool>.seeded(false);

  /// The last interval timestamp received from each source (by index). Used
  /// by the watchdog to compute silence per source.
  final Map<int, DateTime> _lastSeenAt = {};
  int? _activeIndex;
  int? _lastIntervalMs;
  Timer? _watchdog;

  /// Intervals from the currently-active source. Broadcast — multiple
  /// consumers (tick service, future pulse widget) can subscribe.
  Stream<RrInterval> get stream => _intervalController.stream;

  /// `true` when at least one source has emitted within the silence window.
  /// Recomputed by the watchdog and on every received interval.
  bool get hasActiveSource => _hasActiveController.value;

  /// Emits on every transition of [hasActiveSource]. `BehaviorSubject` —
  /// late subscribers receive the current value immediately.
  Stream<bool> get hasActiveSourceStream => _hasActiveController.stream;

  void _onInterval(int index, RrInterval rr) {
    _lastSeenAt[index] = DateTime.now();
    if (rr.isArtifact) {
      logPrint('ActiveRrSource: artifact from source[$index] (${rr.source.name}), intervalMs=${rr.intervalMs}');
    }
    if (_activeIndex == null || index < _activeIndex!) {
      // Either no active source yet, or a higher-priority source revived.
      _activeIndex = index;
      logPrint('ActiveRrSource: active source = $index (${rr.source.name})');
    }
    if (index != _activeIndex) return; // only forward active-source intervals
    _lastIntervalMs = rr.intervalMs;
    _intervalController.add(rr);
    _ensureHasActive(true);
    _restartWatchdog();
  }

  void _restartWatchdog() {
    _watchdog?.cancel();
    final base = _lastIntervalMs ?? 1000;
    final window = Duration(milliseconds: (base * _silenceMultiplier).round());
    final effective = window > _silenceFloor ? window : _silenceFloor;
    _watchdog = Timer(effective, _onSilence);
  }

  void _onSilence() {
    // Active source went silent — try the next-priority source that has
    // emitted recently. Walk the full list in priority order.
    final now = DateTime.now();
    int? next;
    for (var i = 0; i < _sources.length; i++) {
      if (i == _activeIndex) continue;
      final lastSeen = _lastSeenAt[i];
      if (lastSeen == null) continue;
      if (now.difference(lastSeen) <= _silenceFloor) {
        next = i;
        break;
      }
    }
    if (next != null) {
      logPrint('ActiveRrSource: failover ${_activeIndex} → $next');
      _activeIndex = next;
      _restartWatchdog();
      return;
    }
    logPrint('ActiveRrSource: all sources silent');
    _activeIndex = null;
    _lastIntervalMs = null;
    _ensureHasActive(false);
  }

  void _ensureHasActive(bool value) {
    if (_hasActiveController.value != value) {
      _hasActiveController.add(value);
    }
  }

  Future<void> dispose() async {
    _watchdog?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _intervalController.close();
    await _hasActiveController.close();
  }
}
```

Behavior contract:

- **Preferred index = list order.** Index 0 wins. A higher-priority source that revives mid-session steals back the active slot on its next interval. (Today the list has one entry — `NeiryBciProvider`; the policy is correct for ≥1 source.)
- **Silence window** = `max(2000ms, lastIntervalMs × 2)`. Two beats of silence at the current cadence is the threshold for declaring the active source dead.
- **`hasActiveSource` semantics:** `true` from the first valid interval until the watchdog declares all sources silent. Late subscribers get the current value via `BehaviorSubject`.
- **No filtering of artifacts** in MVP — logged and forwarded. The single `if (rr.isArtifact)` branch is the future filter insertion point.
- **No backpressure / no buffering** — broadcast controller, late ticks drop on the floor like any RxDart broadcast.
- **List is immutable post-construction** — sources are registered once at `App.initialize()`; no dynamic add/remove API. Symmetric with `BioStreamRouter`'s register-before-subscribe model.

---

## Milestone 2 — Wire `activeRrSource` in `App.initialize()`

`lib/Core/App.dart` — after the Phase 21 `bioStreamRouter` block:

```dart
// existing:
final bioStreamRouter = BioStreamRouter();
bioStreamRouter.registerHeartRateSource(bciProvider);
bioStreamRouter.registerRrIntervalSource(bciProvider);
bioStreamRouter.registerEegBandsSource(bciProvider);
bioStreamRouter.registerEmotionsSource(bciProvider);

// new:
final activeRrSource = ActiveRrSource([bciProvider]);
```

Both register the same `NeiryBciProvider` instance. The two consumers have opposite policies — that's the whole point.

Add `final ActiveRrSource activeRrSource` to the `App` class fields; pass through to `App.shared`. Dispose order in `App.dispose()` (if it exists, or whenever the rest of the BCI block tears down): `await activeRrSource.dispose()` before `bciProvider.dispose()`.

No UI imports `lib/Biometrics/ActiveRrSource.dart` directly. The breath module reaches it via `App.shared.activeRrSource` inside `BreathModule.buildSession()`.

---

## Milestone 3 — `HeartRateTickService`

Single file `lib/BreathModule/HeartRateTickService.dart`. Sibling of `ClockTickService.dart`.

```dart
import 'dart:async';
import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;
import 'package:mind/Biometrics/ActiveRrSource.dart';

class HeartRateTickService implements ITickService {
  HeartRateTickService({required ActiveRrSource activeRrSource})
      : _activeRrSource = activeRrSource {
    _sub = _activeRrSource.stream.listen((rr) {
      _tickController.add(TickData(rr.intervalMs));
    });
  }

  final ActiveRrSource _activeRrSource;
  final StreamController<TickData> _tickController = StreamController<TickData>.broadcast();
  StreamSubscription? _sub;

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => TickSource.heartbeat;

  /// Proxy for callers that need to gate UI on source availability.
  bool get hasActiveSource => _activeRrSource.hasActiveSource;

  /// Transitions of [hasActiveSource]. Consumed by [SwitchableTickService] for
  /// auto-fallback.
  Stream<bool> get hasActiveSourceStream => _activeRrSource.hasActiveSourceStream;

  @override
  void dispose() {
    _sub?.cancel();
    _tickController.close();
    // We do NOT dispose _activeRrSource — it is owned by App and shared with
    // future consumers.
  }
}
```

Notes:

- Each RR interval becomes exactly one `TickData(intervalMs)`. No smoothing, no rate limiting.
- `dispose()` releases the subscription and closes our broadcast controller only. `ActiveRrSource` lives in `App.shared` and outlives any single session.
- No artifact handling here — that's `ActiveRrSource`'s call. This adapter is dumb on purpose.

---

## Milestone 4 — `SwitchableTickService`

Single file `lib/BreathModule/SwitchableTickService.dart`. Owns both `ClockTickService` and `HeartRateTickService` and exposes a single `ITickService` facade.

```dart
import 'dart:async';
import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;
import 'ClockTickService.dart';
import 'HeartRateTickService.dart';

class SwitchableTickService implements ITickService {
  SwitchableTickService({
    required ClockTickService clock,
    required HeartRateTickService heart,
  })  : _clock = clock,
        _heart = heart {
    _activeSource = TickSource.timer;
    _activeSub = _clock.tickStream.listen(_tickController.add);
    // Auto-fallback: if we're on heart and it loses all sources, snap back to clock.
    _healthSub = _heart.hasActiveSourceStream.listen((hasActive) {
      if (!hasActive && _activeSource == TickSource.heartbeat) {
        _switchInternal(TickSource.timer);
      }
    });
  }

  final ClockTickService _clock;
  final HeartRateTickService _heart;

  final StreamController<TickData> _tickController = StreamController<TickData>.broadcast();
  final StreamController<TickSource> _sourceChangesController = StreamController<TickSource>.broadcast();

  late TickSource _activeSource;
  StreamSubscription<TickData>? _activeSub;
  StreamSubscription<bool>? _healthSub;

  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => _activeSource;

  /// Emits on every change of the active source (manual via [trySwitchTo] or
  /// automatic via watchdog fallback). [BreathViewModel] subscribes to this
  /// and writes the new value into [BreathSessionState.tickSource].
  Stream<TickSource> get sourceChanges => _sourceChangesController.stream;

  /// Returns `true` if the switch was performed. Heartbeat is rejected when
  /// no RR source is currently active — caller (VM) is expected to show the
  /// "connect a heart sensor" alert on `false`.
  bool trySwitchTo(TickSource target) {
    if (target == _activeSource) return true;
    if (target == TickSource.heartbeat && !_heart.hasActiveSource) {
      return false;
    }
    _switchInternal(target);
    return true;
  }

  void _switchInternal(TickSource target) {
    _activeSub?.cancel();
    _activeSource = target;
    final src = target == TickSource.timer ? _clock : _heart;
    _activeSub = src.tickStream.listen(_tickController.add);
    _sourceChangesController.add(target);
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    _healthSub?.cancel();
    _tickController.close();
    _sourceChangesController.close();
    _clock.dispose();
    _heart.dispose();
  }
}
```

Behavior contract:

- **Owns both children.** `dispose()` propagates to Clock and Heart. The VM only sees the facade.
- **Default active source** = `TickSource.timer`. Sessions start on clock; user explicitly opts into heart.
- **`trySwitchTo(heartbeat)`** returns `false` when `hasActiveSource == false`. VM uses the boolean to gate the alert.
- **Auto-fallback** is wired here, not in the VM: when Heart's `hasActiveSourceStream` drops to `false` and we're currently on heart, switch back to timer and emit on `sourceChanges`. VM picks up the change via its subscription to `sourceChanges` and updates `state.tickSource`. No special re-arm path — if a heart source revives, the heart icon becomes active again (because `hasActiveSource` is true) and the user can re-toggle manually.
- **Single broadcast `tickStream`** — consumers (state machine, sound coordinator) never resubscribe across switches; they always see one continuous stream of ticks.

---

## Milestone 5 — Wire `SwitchableTickService` in `BreathModule.buildSession()`

`lib/BreathModule/BreathModule.dart`, in `buildSession()`. Today:

```dart
final tickService = ClockTickService()..simulateTick();
```

Becomes:

```dart
final clock = ClockTickService()..simulateTick();
final heart = HeartRateTickService(activeRrSource: App.shared.activeRrSource);
final tickService = SwitchableTickService(clock: clock, heart: heart);
```

Then pass `tickService` (the Switchable) into `BreathViewModel` as before. `clock.simulateTick()` always runs so that switching back from heart to clock doesn't introduce a first-tick lag (the timer is already ticking; the facade just re-attaches its subscription).

No change to `BreathViewModel` signature in this milestone. The VM continues to receive an `ITickService`. Behavior is identical to current state — sessions still tick from the clock. The Switchable is a no-op facade until milestone 6 adds the API to switch it.

---

## Milestone 6 — `BreathViewModel.toggleHeartTickSource()` + auto-fallback wiring + UI event

`packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`.

Changes:

1. Extend `BreathSessionError` (or introduce a new `BreathSessionUiEvent` enum) with a `noCardioSource` variant. Easiest: rename the existing `BreathSessionError` enum into a broader `BreathSessionUiEvent` and add `noCardioSource` alongside `starFailed`. (Rename the screen callback `onErrorEvent` → `onUiEvent` accordingly; touch all current callsites: the screen.)

2. Add a field `StreamSubscription<TickSource>? _sourceChangesSub`. In `build()`, do not subscribe yet — VM does it in `initState()` after the engine setup.

3. In `initState()`, after `_setupEngine(dto)` completes (or in `_setupEngine` itself, doesn't matter — the tick service is stable for the lifetime of the VM, so once is enough), subscribe:
   ```dart
   _sourceChangesSub = (tickService as SwitchableTickService).sourceChanges.listen((src) {
     state = state.copyWith(tickSource: src);
   });
   ```
   Cancel in `ref.onDispose`.

4. Add public method:
   ```dart
   void toggleHeartTickSource() {
     final switchable = tickService as SwitchableTickService;
     final target = state.tickSource == TickSource.heartbeat
         ? TickSource.timer
         : TickSource.heartbeat;
     final ok = switchable.trySwitchTo(target);
     if (!ok) {
       onUiEvent?.call(BreathSessionUiEvent.noCardioSource);
     }
     // `state.tickSource` is updated by the sourceChanges subscriber, not here.
   }
   ```

   The `tickService as SwitchableTickService` cast is intentional and local — the public interface stays `ITickService`, only the breath module knows that under the hood it's always a Switchable. (If we ever ship a session with a non-switchable tick — e.g. tests — calls to `toggleHeartTickSource()` would throw; that's fine, the button isn't shown in tests.)

5. **Why state.tickSource is written from the subscriber, not from `toggleHeartTickSource` directly:** auto-fallback also changes the active source, and we want a single sync point. Subscribing to `sourceChanges` covers both manual toggles and watchdog fallbacks with one code path.

---

## Milestone 7 — Heart button in `SessionBottomBar.leadingActions` + alert + docs

Two consumers of the new VM API: the button and the alert handler. Both live in `BreathSessionScreen`.

### Button placement

After Phase 20 M2 ships, `SessionBottomBar` has `leadingActions: const []` slot, and mute occupies index 0. The heart button is appended at index 1 (right of mute). The implementation in `_BreathSessionScreenState.build()`:

```dart
leadingActions: [
  // existing mute ValueListenableBuilder from Phase 20 M2
  ValueListenableBuilder<bool>(
    valueListenable: _soundCoordinator.isMuted,
    builder: (_, muted, __) => IconButton(
      icon: Icon(muted ? Icons.volume_off_outlined : Icons.volume_up),
      color: muted ? Colors.white.withValues(alpha: 0.3) : cs.tertiary,
      onPressed: _soundCoordinator.toggleMute,
    ),
  ),
  // new heart button
  Consumer(builder: (_, ref, __) {
    final tickSource = ref.watch(breathViewModelProvider.select((s) => s.tickSource));
    final isActive = tickSource == TickSource.heartbeat;
    return IconButton(
      icon: const Icon(Icons.favorite),
      color: isActive ? Colors.red : Colors.white.withValues(alpha: 0.3),
      onPressed: () => viewModel.toggleHeartTickSource(),
    );
  }),
],
```

Visual rules:

- **Active (heartbeat source):** filled red heart (`Colors.red`). One state, not animated — the icon being red is the affordance.
- **Inactive (clock source):** filled white 30% alpha — same dim-but-tappable style mute uses when off.
- **No `disabled` state.** The button is always tappable. If the user taps with no RR source available, `trySwitchTo` returns `false`, VM emits `noCardioSource`, screen shows the alert. We deliberately don't grey it out because (a) users would otherwise wonder why it's broken, and (b) the alert is the right place to tell them "connect a heart sensor".

### Alert handler

Extend the existing `viewModel.onErrorEvent` (renamed `onUiEvent`) handler in `initState()`:

```dart
viewModel.onUiEvent = (event) {
  switch (event) {
    case BreathSessionUiEvent.starFailed:
      ref.read(globalSnackBarNotifierProvider.notifier).show(
        SnackBarEvent.error(AppLocalizations.of(context)!.error),
      );
    case BreathSessionUiEvent.noCardioSource:
      AppAlert.show(
        context,
        title: AppLocalizations.of(context)!.heartTickNoSourceTitle,
        description: AppLocalizations.of(context)!.heartTickNoSourceDescription,
      );
  }
};
```

Add two l10n keys (en + ru ARB files):
- `heartTickNoSourceTitle` — EN: "Connect a heart sensor" / RU: "Подключите датчик сердца"
- `heartTickNoSourceDescription` — EN: "Pair a BCI device to drive the breathing rhythm from your heartbeat." / RU: "Чтобы дышать в ритм с сердцем, подключите BCI-устройство."

`AppAlert.show` already provides the OK button; no extra wiring.

### Documentation deltas

- **`docs/breath/session/tick-sources.md`** — replace "Единственная реализованная реализация — `ClockTickService`" section with a description of both implementations and the `SwitchableTickService` façade. Add a section "Переключение источника" describing manual toggle from the bottom bar, auto-fallback when all RR sources go silent, and the source-of-truth role of `SwitchableTickService.sourceChanges` for `state.tickSource`. Link to `docs/biometrics/active-rr-source.md` (new, see below) for the upstream policy.

- **`docs/biometrics/active-rr-source.md`** — new file. Describes:
  - The two-policy split for RR consumption (`BioStreamRouter` merges everything for the server; `ActiveRrSource` picks one for client cadence).
  - Preferred-with-fallback semantics, the silence window formula, what happens when all sources go quiet.
  - That artifacts are currently passed through with logging, with the future filter slot.
  - Note that the only consumer today is `HeartRateTickService` but the contract supports any heart-driven client UX.

- **`docs/biometrics/capability-sources.md`** — append a short paragraph noting that some capabilities are consumed by both server (merge) and client (single-source) policies, and link to `active-rr-source.md` as the canonical example.

- **`CLAUDE.md`** — add `docs/biometrics/active-rr-source.md` to the Documentation index list.

---

## Things deliberately not done in this phase

- **Filtering of `isArtifact: true` intervals.** Logged but forwarded. The `if (rr.isArtifact)` branch in `ActiveRrSource._onInterval` is the insertion point for future smoothing / clamping if real-world data warrants it.
- **Smoothing of normal-but-noisy intervals.** Even non-artifact RR varies ±10–20% beat-to-beat (respiratory sinus arrhythmia). The animation already absorbs this — no smoothing needed.
- **Auto-switch from clock to heart** when an RR source becomes available mid-session. User-initiated only; the heart icon being tappable is the affordance.
- **Persisting the user's source preference** across sessions. Always starts on clock — single, unsurprising default.
- **`ActiveHeartRateSource`** for the cardio-stream counterpart. No consumer today; add only when a "show pulse" UI needs it.
- **L10n for log messages.** All `logPrint` strings stay English — they are for developers only.
