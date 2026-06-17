# Plan Review: Route `logPrint` through the observe sink

**Plan:** `40-route-logprint-through-the-observe-sink.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

Every factual claim in the plan was checked against the actual sources.

### Confirmed correct

1. **`lib/Logger.dart` current state** — Matches the plan exactly. `_logDestination`,
   `logToConsole`, and `logToObserver` are already declared (lines 3–6); the plan correctly
   says to reuse them and not redeclare. The `logPrint` body (lines 8–15) is the time-prefixed
   `debugPrint('[$time] $object')` the plan preserves byte-for-byte.

2. **`observeSink` API** — Confirmed in `package:observe/observe.dart`
   (`lib/src/adapter/log_print.dart`):
   ```dart
   void observeSink(String message, {Level level = Level.info}) { log(level, message); }
   ```
   - Default level is `Level.info` → the plan's "do not pass a `level:` argument, use the info
     default" is accurate.
   - The package doc explicitly states "Calling before `init` is silently ignored (never throws)"
     and "silent degradation … never-break-the-host contract" → the plan's "do not wrap in
     try/catch — guaranteed never to throw, tolerates being called before SDK init" is correct.

3. **Import path** — `package:observe/observe.dart` is the correct barrel and re-exports
   `observeSink` (line 18 of `observe.dart`). `App.dart` already imports the same barrel
   unqualified, so the import style in the plan matches existing convention.

4. **No symbol collisions** — The barrel exports `init`, `log`, `flush`, `shutdown`, `Level`,
   `Span`, etc. None collide with `Logger.dart`'s symbols (`logPrint`, `logToConsole`,
   `logToObserver`, `_logDestination`). Pulling the full barrel into `Logger.dart` is safe.

5. **Dependency presence** — `observe` is a direct git dependency in `pubspec.yaml`
   (`ref: v0.1.0`); the package resolves in pub-cache. No `flutter pub add` needed, as stated.

6. **SDK initialization is wired** — `lib/Core/App.dart:138` calls
   `init(project: 'mind', service: 'mind_mobile', endpoint: …)` guarded by `logToObserver`.
   So records forwarded by `observeSink` will actually reach the backend at runtime; this plan
   does not need to add init wiring.

### Minor / Informational (non-blocking)

- **Raw message vs. prefixed message** — The plan correctly sends the raw `object?.toString()`
  to `observeSink` (no `[$time]` prefix) since Loki carries its own timestamp, while keeping the
  `[$time]` prefix only on the console path. This is the right split and matches the
  `observeLogPrint` reference implementation (`message?.toString() ?? ''`).

- **Optional `show` clause** — The plan imports the full barrel. Using
  `import 'package:observe/observe.dart' show observeSink;` would be marginally cleaner, but the
  unqualified import matches the existing `App.dart` usage, so leaving it unqualified is a
  defensible consistency choice, not a defect.

- **`logToConsole` short-circuit** — The plan correctly notes the `now`/`time` computation can be
  skipped when `logToConsole` is false by moving it inside the guard, while preserving the exact
  format string. The resulting shape in the plan is accurate.

## Positive Notes

- Single-task, tightly scoped milestone with a clear "change only the body, keep the signature"
  constraint — minimizes blast radius across the 57 call sites.
- Correctly identifies dependency note 109 as already implemented, avoiding redundant resolver work.
- The "never break the host" reasoning for omitting try/catch is backed by the SDK contract, not
  an assumption.

## Conclusion

No missing steps, no wrong assumptions, no incorrect file paths or API usage, no architectural
issues, no migrations required. The plan is implementable exactly as written.

PLAN_REVIEW_PASS
