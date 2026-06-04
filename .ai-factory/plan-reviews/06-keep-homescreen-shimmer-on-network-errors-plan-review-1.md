# Plan Review: Keep HomeScreen shimmer on network errors

**Plan:** `.ai-factory/plans/06-keep-homescreen-shimmer-on-network-errors.md`
**Files in scope:** `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
**Risk Level:** 🟡 Medium — the edit itself is correct, but the plan's stated recovery path does **not** fire for the exact error classes it targets, so the shimmer can become permanent.

---

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** present. The change stays inside the ViewModel (presentation/module boundary); no domain-model leakage, no new streams. **PASS.**
- **Rules (`.ai-factory/RULES.md`):** present. The relevant rule is "Module Services must be stateless / `observeChanges()` returns a derived stream." This plan touches only the ViewModel, not the Service, and adds no state/streams. No rule violation. **PASS.**
- **Roadmap (`.ai-factory/ROADMAP.md`):** present. This is a small `fix`-class UX change following the #05 timeout work. Linkage to a roadmap milestone is not asserted in the plan. **WARN (non-blocking)** — mention the roadmap item this fix belongs to for traceability.
- **skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** absent — no project-specific review overrides to apply.

---

## Verified assumptions (correct)

- ✅ **grpc import claim** — `import 'package:grpc/grpc.dart';` is used **unaliased** in `lib/Core/Grpc/GrpcAuthInterceptor.dart`, `GrpcLoggingInterceptor.dart`, `GrpcClient.dart`, and `lib/User/AuthApi.dart`. The plan's instruction matches existing convention.
- ✅ **`dart:async` already imported** — line 1 of `HomeViewModel.dart`. `TimeoutException` is available without a new import, as the plan states.
- ✅ **Raw error propagation** — `UserApi.fetchSuggestions` / `StatsApi.fetchStats` call `.timeout(const Duration(seconds: 10))` and do **not** wrap errors. `HomeService` re-throws transparently. So `TimeoutException` and `GrpcError` reach the ViewModel catch block with their original types — the `is`-checks in `_isNetworkError` will work.
- ✅ **State shape** — `HomeState` / `copyWith` expose `isSuggestionsLoading`, `isStatsLoading`, `error` exactly as the snippets assume.
- ✅ **Shimmer gating** — `SuggestionsCard` and `StatsCard` render the shimmer purely on `!isGuest && isXxxLoading`, so keeping the flag `true` keeps the shimmer. The mechanism works as intended.
- ✅ **File path** is correct and the catch blocks match the quoted code verbatim.

---

## Critical Issue — recovery does not fire for the targeted error classes

The plan asserts:
> "Recovery happens via the existing `HomeGrpcReconnected → _loadInitialData()` path which retries and resets the loading flags on success."

This assumption is **only partly true**, and it fails precisely for the errors `_isNetworkError` is built to catch.

`HomeService.observeChanges()` derives `HomeGrpcReconnected` from a **pairwise transition** of `connectionStateStream` (non-connected → connected). That stream is driven entirely by `GrpcConnectionManager`, which only flips to `disconnected` on:

1. **Full connectivity loss** — `connectivity_plus` emits `ConnectivityResult.none`, or
2. **Logout** — `GuestState`, or
3. An explicit `scheduleReconnect()` triggered by **transport-level streaming** errors.

A **unary** `getSuggestions` / `getStats` call that throws `TimeoutException` or `GrpcError(unavailable / cancelled)` **while the device still reports connectivity** does NOT change the connection state. `connect()` in `GrpcConnectionManager` doesn't perform a real handshake/health check, and there is no keepalive that would notice a dead unary call. So in the common cases:

- backend is down / restarting / deploying (server returns `UNAVAILABLE`),
- backend is slow and the 10 s `.timeout(...)` fires (`TimeoutException`),
- captive Wi-Fi / DNS failure where the OS still reports a network,

…connectivity stays "present", the connection state stays `connected`, **`HomeGrpcReconnected` never fires, and the shimmer stays forever.** That is arguably worse UX than today's collapse — the user gets a permanent loading animation with no recovery short of toggling airplane mode, re-logging in, or killing the app.

**Recommendation:** the plan needs an explicit recovery trigger for unary failures, not just connectivity transitions. Options, roughly in order of fit:
- On a network error, schedule a bounded retry (e.g. delayed `_loadSuggestions()` / `_loadStats()` with backoff) instead of relying solely on `HomeGrpcReconnected`; or
- Call `connectionManager.scheduleReconnect()` from the failing unary path so the existing reconnect/pairwise machinery actually produces a `HomeGrpcReconnected` event; or
- At minimum, also retry on `HomeAppResumed` (see next issue) so foreground/background gives the user a recovery lever.

Whichever is chosen, the plan should stop claiming the *existing* `HomeGrpcReconnected` path is sufficient — for the targeted errors it is not.

---

## Secondary Issue — stats cannot recover on app resume

`HomeService` maps `resumeStream` to `HomeAppResumed`, and `_onEvent` handles it with `_loadSuggestions()` **only** — `_loadStats()` is not called on resume. This is the one event that fires regardless of connection state. Consequence: after a stuck network error, backgrounding/foregrounding the app can recover the **suggestions** shimmer but the **stats** shimmer remains stuck indefinitely. The plan introduces an asymmetric dead-end. If you adopt "retry on resume" as the recovery lever, add `_loadStats()` to the `HomeAppResumed` branch.

---

## Minor — `StatusCode.cancelled` classification is questionable

`cancelled` is typically **client-initiated** (request superseded, channel/ViewModel disposed), not a transient network fault. Including it in `_isNetworkError`:
- is mostly harmless when it happens because the Notifier was disposed (the state is discarded anyway), but
- if a real cancel occurs that is never retried, it joins the "stuck shimmer" failure mode above.

Recommendation: either drop `cancelled` (keep `unavailable` + `TimeoutException`, which are the genuine transient-network signals), or add a one-line comment justifying why a cancelled unary should keep the shimmer. Low priority.

---

## Observation — the `error` field is vestigial

`state.error` is written in both catch blocks but is **not read by any HomeScreen widget** (`SuggestionsCard` / `StatsCard` only gate on the loading flags). So suppressing `error` on network errors has no visible downside — but it also means there is **no error fallback UI at all**; the shimmer is the only signal the user ever gets. This magnifies the stuck-shimmer risk and is worth keeping in mind when choosing a recovery strategy. Not a blocker for this plan.

---

## Positive Notes

- The `_isNetworkError` helper is a clean, well-scoped predicate and the `return`-early pattern is the minimal correct edit to keep the flag `true`.
- The plan correctly verified import aliasing convention and the pre-existing `dart:async` import — these are exactly the kind of small assumptions that usually break, and they were checked.
- Non-network errors (`PERMISSION_DENIED`, etc.) are correctly left to collapse the areas as before — good separation.
- Task dependency ordering (Task 2 depends on Task 1) is correct.

---

## Verdict

The mechanical edit is correct and matches intent, but the plan ships with a recovery assumption that is wrong for the targeted error classes — producing a permanent shimmer in the most common real-world failure (server down / unary timeout with connectivity intact). Address the recovery path (and the stats-on-resume asymmetry) before implementing.

Not passing as-is.
