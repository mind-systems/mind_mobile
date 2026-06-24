# Plan Review: KeepAliveCoordinator FGS lifecycle tests

**Plan:** `100-keepalivecoordinator-fgs-lifecycle-tests.md`
**Files Reviewed:** 5 (plan + KeepAliveCoordinator, ForegroundKeepAlive, ModuleStateEvent, MeditationKeepAliveCoordinator, App.dart)
**Risk Level:** 🟡 Medium — strong, source-grounded plan with one concrete compile error in the proposed SUT seam.

---

## Verification of Plan Claims

All factual anchors check out against the codebase:

| Claim | Status |
|---|---|
| `_onEvent` awaits `start()`/`stop()` (KeepAliveCoordinator.dart:29/31/33) | ✅ Confirmed |
| Constructor guard `if (!Platform.isAndroid) return;` at line 18 | ✅ Confirmed |
| Production call site App.dart:230 (defaulted param keeps it unchanged) | ✅ Confirmed |
| `MeditationKeepAliveCoordinator.dispose()` at line 33 | ✅ Confirmed (also disposes the player, but cancels the sub as claimed) |
| `ModuleStateEvent` subtype names/signatures | ✅ Exact match (ModuleStateEvent.dart) |
| `ForegroundKeepAlive({required String Function() currentLanguageCode})` ctor | ✅ Fake's `super(currentLanguageCode: () => 'en')` matches |
| `start()`/`stop()` touch FlutterForegroundTask + permission_handler | ✅ Confirmed — fake must override both (it does) |
| Note 180's `debugDefaultTargetPlatformOverride` suggestion is wrong for `dart:io Platform.isAndroid` | ✅ **Correct pushback.** Note 180:35 does recommend it; the plan rightly rejects it — `debugDefaultTargetPlatformOverride` drives `flutter/foundation`'s `defaultTargetPlatform`, not `dart:io`'s `Platform.operatingSystem`. |

The event-routing assertions (Phases 2–4) all trace correctly through the `switch` in `_onEvent`. The microtask-drain guidance is sound: the fake's `start()`/`stop()` complete synchronously up to a trivial future, and broadcast-stream delivery is itself a microtask, so a single `await Future.microtask(() {})` after each `.add` is sufficient and deterministic.

---

## Critical Issues

### 1. The proposed seam snippet does not compile — instance-method default value

The Gap A code (plan lines 32–43) declares the default as an **instance** method:

```dart
KeepAliveCoordinator({
  ...
  bool Function() isAndroid = _platformIsAndroid,   // <-- default value
}) ...

bool _platformIsAndroid() => Platform.isAndroid;     // <-- instance method
```

Default parameter values must be compile-time constants. An instance-method tear-off is **not** constant, so this fails analysis:

```
error - The default value of an optional parameter must be constant. - non_constant_default_value
```

(Verified with `dart analyze` on a reduced repro.)

**Fix:** make the helper `static` (a static-method tear-off *is* a constant):

```dart
bool Function() isAndroid = _platformIsAndroid,
...
static bool _platformIsAndroid() => Platform.isAndroid;
```

Verified this variant analyzes clean. The implementer must apply `static` (or move the helper to a top-level function); copying the plan's snippet verbatim will not compile and blocks every Android-path task (2–5).

---

## Minor Issues / Nits

### 2. Remove the now-stale `// ignore: unused_field` when adding `dispose()`
`_subscription` currently carries `// ignore: unused_field — held … (GC prevention)` (KeepAliveCoordinator.dart:23). Once `dispose()` reads it via `_subscription?.cancel()`, the field is genuinely used and the ignore becomes inaccurate (and potentially an `unnecessary_ignore` flag depending on lint config). The implementer should drop that ignore comment when applying Gap B. Worth one line in the plan so it isn't left behind.

### 3. `dispose()` is added for testability only — not wired into app lifecycle
`KeepAliveCoordinator` is created in `App.initialize()` and lives for the app's lifetime; nothing calls `dispose()` in production. Adding it mirrors the sibling and is harmless, but the plan should state explicitly that the method exists for the test seam and is intentionally not invoked from `App.dart` — otherwise a future reader/verifier may flag it as a dangling/unused API.

### 4. No Flutter test binding is needed — good, but worth stating
Because the fake overrides `start()`/`stop()`, no plugin or `lookupAppLocalizations` call is ever reached, so the suite is pure-Dart and needs no `TestWidgetsFlutterBinding.ensureInitialized()`. The plan implicitly relies on this; a one-line note would prevent an implementer from reflexively adding binding setup.

---

## Positive Notes

- **Excellent source-grounding.** Every line reference is accurate, and the plan independently caught and corrected a wrong recommendation in the upstream spec note (180) rather than propagating it — exactly the right behavior.
- **Honest blocker handling.** Gaps A and B are surfaced as required SUT changes with a clear "do not fake against private internals" instruction and a defined fallback (Task 1 only) if SUT edits are refused. This prevents hollow tests.
- **Seam choice fits codebase convention** — defaulted injectable matching the clock/timer/config pattern, keeping App.dart:230 untouched.
- **Test cases are behaviorally complete**: re-arm, no-dedup delegation, interleaved pause/unpause, no-op events, and disposal (including natural stream-close) all map to real branches.

---

## Verdict

The plan is well-researched and nearly implementation-ready, but Issue #1 is a hard compile error in the code the implementer is told to write. It must be corrected (`static` helper) before implementation. Not a pass.
