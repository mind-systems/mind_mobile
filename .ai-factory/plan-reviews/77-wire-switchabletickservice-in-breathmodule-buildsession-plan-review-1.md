# Plan Review: Wire `SwitchableTickService` in `BreathModule.buildSession()`

## Code Review Summary

**Plan:** `.ai-factory/plans/77-wire-switchabletickservice-in-breathmodule-buildsession.md`
**Files Targeted:** 1 (`lib/BreathModule/BreathModule.dart`)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — no boundary violations. The change happens at the app's assembly point (`BreathModule.buildSession()`), which is the documented place to wire concrete services and inject `App.shared` dependencies into the module package.
- **RULES.md** — no violations:
  - "Module Services must be stateless" — does not apply. `SwitchableTickService`/`HeartRateTickService` are infrastructure adapters that implement `ITickService` (the same shape as the pre-existing `ClockTickService`), not concrete `IXxxService` implementations of a package's service interface.
  - "Never add module-specific state to App.dart" — the plan reuses an already-existing `App.shared.activeRrSource` field (added in milestone 2, line 90 of `App.dart`). Nothing new is added to `App.dart`.
  - "All dependencies must be injected via constructor" — both new services are constructed locally inside `buildSession()` and passed via constructor, consistent with the existing `tickService` pattern.
- **ROADMAP.md** — plan matches the roadmap entry at line 171 ("Wire `SwitchableTickService` in `BreathModule.buildSession()`") almost word-for-word. ✅

### Codebase Verification

| Claim in plan | Verified |
|---|---|
| `lib/BreathModule/SwitchableTickService.dart` exists | ✅ Confirmed |
| `lib/BreathModule/HeartRateTickService.dart` exists | ✅ Confirmed |
| `HeartRateTickService` constructor signature is `{required ActiveRrSource activeRrSource}` | ✅ Matches |
| `SwitchableTickService` constructor signature is `{required ClockTickService clock, required HeartRateTickService heart}` | ✅ Matches |
| `SwitchableTickService implements ITickService` | ✅ Confirmed (line 8) |
| `SwitchableTickService` defaults to `TickSource.timer` and forwards clock ticks initially | ✅ Confirmed (lines 14–15) |
| `App.shared.activeRrSource` exists | ✅ Confirmed (`lib/Core/App.dart:90`) |
| `BreathViewModel` accepts `ITickService` and calls `tickService.dispose()` on dispose | ✅ Confirmed (BreathSessionViewModel line 22, 72) — `SwitchableTickService.dispose()` correctly propagates dispose to both clock and heart |

### Critical Issues

None.

### Minor Observations (non-blocking)

1. **Import ordering note is slightly imprecise.** The plan says "keep alphabetical/grouping convention already used in the file." The existing imports in `BreathModule.dart` are roughly grouped by directory but **not strictly alphabetical** — e.g. `BreathSessionCoordinator.dart` (line 6) is out of order vs `BreathSessionListCoordinator.dart` (line 5). The implementing agent will likely insert the new imports near `ClockTickService.dart` (line 9), which is fine. No functional impact.

2. **`HeartRateTickService` subscribes to `ActiveRrSource.stream` for the lifetime of every session, even when dormant.** This is by design (it is also how `SwitchableTickService` watches `hasActiveSourceStream` to detect auto-fallback), but worth noting: each `buildSession()` call attaches one additional listener to `ActiveRrSource.stream` and one to `hasActiveSourceStream`. Both are correctly torn down when the VM disposes the tick service — verified that `HeartRateTickService.dispose()` cancels its own subscription and does **not** dispose the shared `ActiveRrSource`. No leak.

3. **`buildSession()` constructs `tickService` outside of `overrideWith`.** Same pattern the file already uses, so no regression — but worth flagging that if Riverpod ever re-invokes the `breathViewModelProvider` initializer (e.g. via `ref.invalidate`) the same `tickService` instance would be reused. This is not introduced by this plan; it is a pre-existing characteristic.

4. **Behavioral identity claim is correct.** Because `SwitchableTickService` initializes with `_activeSource = TickSource.timer` and immediately subscribes to `clock.tickStream`, and because `clock.simulateTick()` is still called before the facade is constructed, the user-visible behavior is identical to the current `main` branch — the assertion in the plan's "Verification" section holds.

5. **No migrations or proto changes** — correct; this milestone is a pure wiring change.

### Positive Notes

- Plan is narrowly scoped, minimal, and surgically accurate (single file, 1 line removed → 3 lines added, 2 new imports).
- The rationale for keeping `clock.simulateTick()` always running ("zero first-tick lag on switch-back") is well-thought-out and matches the SwitchableTickService design — re-subscribing to an already-running broadcast stream gets the next tick immediately.
- Plan correctly notes that no signature change to `BreathViewModel` is needed because `SwitchableTickService implements ITickService`.
- Plan correctly defers the toggle UI / `sourceChanges` subscription / `noCardioSource` event to milestone 6 (matches the roadmap split).
- Confirmed in the codebase that all referenced files and fields exist exactly as claimed.

PLAN_REVIEW_PASS
