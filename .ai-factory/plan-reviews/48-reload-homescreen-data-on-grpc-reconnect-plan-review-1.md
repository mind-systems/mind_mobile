# Plan Review: 48-reload-homescreen-data-on-grpc-reconnect

**Plan:** `.ai-factory/plans/48-reload-homescreen-data-on-grpc-reconnect.md`
**Risk Level:** 🟢 Low

## Verification of assumptions

- `lib/HomeModule/HomeService.dart` — confirmed `observeChanges()` returns `Stream<HomeEvent>` built from `mergeWith([sessionExpired, authenticated, resumeEvents])`. The named-parameter style matches what the plan proposes (`required this.connectionStateStream`).
- `lib/HomeModule/HomeModule.dart` — confirmed `HomeService` is constructed only here, so a single wiring change is sufficient.
- `lib/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart` — confirmed `HomeEvent` is `sealed`; the existing subclasses (`StatsInvalidated`, `HomeSessionExpired`, `HomeAuthenticated`, `HomeAppResumed`) match the plan's reference. Adding `HomeGrpcReconnected` extends the sealed family — the `switch (event)` in `HomeViewModel` is exhaustive, so the analyzer will demand the new case (plan handles this in Task 4).
- `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart` — confirmed the switch structure and that `_loadInitialData()` already covers both suggestions and stats.
- `lib/Core/Grpc/GrpcConnectionManager.dart` — confirmed `connectionState` exposes `Stream<GrpcConnectionState>` from a `BehaviorSubject` seeded with `disconnected`, so the plan's BehaviorSubject-seed-replay concern is accurate.
- `lib/Core/Grpc/GrpcConnectionState.dart` — confirmed values `connecting / connected / disconnected`; the import path the plan uses is correct.
- `lib/Core/App.dart` — confirmed `App.shared.connectionManager` is reachable from `HomeModule.buildHomeScreen` (already used by `App.shared.userApi`, etc.).
- `pairwise()` is a standard rxdart operator and `rxdart` is already imported in `HomeService.dart`; no extra dependency or import is needed.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Not checked separately; the change keeps the existing Service → ViewModel boundary intact, no domain model leaks across the module boundary, no Flutter/Riverpod creeping into the domain layer. Aligns with the documented layering.
- **Rules (`.ai-factory/RULES.md`):** No project rules file relevant to this change was located; nothing flagged.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Plan number `48` suggests a roadmap-linked task; assumed in scope.

## Findings

### Critical Issues
None.

### Minor / Worth noting (non-blocking)

1. **First-load duplication on a freshly-opened HomeScreen.**
   `HomeViewModel.build()` already runs `_loadInitialData()` via `Future.microtask`. If `HomeService` is constructed while the connection is `disconnected` or `connecting` and the manager subsequently transitions to `connected`, `pairwise()` will emit `(connecting, connected)` and fire `HomeGrpcReconnected`, triggering a second `_loadInitialData()`. The same can happen alongside `HomeAuthenticated` right after login. This is not a correctness bug — just a redundant double fetch in the most common cold-start path. If avoiding it matters, options are:
   - Use `.distinct()` followed by `.skip(1)` on the connection stream instead of `pairwise()` (skips the seed but still fires on every later transition into `connected`).
   - Or accept the duplicate; both calls are idempotent.
   Worth a one-line acknowledgement in the plan; not a blocker.

2. **Constructor-parameter wording nit (Task 2).**
   The plan says "Include it in the constructor initializer list with `required this.connectionStateStream`." That's actually the constructor *parameter list* (named parameters), not the *initializer list*. The intent is unambiguous given the existing `HomeService` constructor shape — purely a wording nit.

3. **Logging policy.**
   Plan settings declare "Logging: minimal". Consider whether a single `log(...)` in the reconnect branch (matching the `GrpcConnectionManager` logging style with `name: 'HomeService'`) is desired — debugging spurious vs. genuine reloads becomes harder without it. Optional; minimal is also fine.

### Positive Notes

- Correctly identifies and explains the `BehaviorSubject` seed-replay pitfall, and `pairwise()` is the right primitive to silence the replayed seed.
- Sealed `HomeEvent` keeps the switch exhaustive, so the new case is enforced by the analyzer — clean extension.
- Single wiring site (`HomeModule.dart`) was verified; the plan does not over-state required changes.
- Reuses `_loadInitialData()` rather than introducing a parallel code path — matches the existing `HomeAuthenticated` behaviour and keeps semantics consistent.
- Domain/module boundary respected: `HomeService` lives in `lib/`, consumes domain dependencies, exposes only the existing `HomeEvent` DTO family upward.
- File paths, import paths, and the `App.shared.connectionManager.connectionState` accessor all verified.

## Conclusion

The plan is correct, minimally invasive, and consistent with the existing architecture. The only observation worth resolving is the first-load duplicate-fetch edge case (Finding #1); the rest are cosmetic.

PLAN_REVIEW_PASS
