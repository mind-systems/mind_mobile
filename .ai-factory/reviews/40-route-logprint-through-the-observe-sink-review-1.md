# Code Review: Route `logPrint` through the observe sink

**Plan:** `40-route-logprint-through-the-observe-sink.md`
**Scope reviewed:** `lib/Logger.dart` (only code file changed; remaining diff is plan/review artifacts).

## What changed
`logPrint(Object?)` now:
- Computes the `[HH:mm:ss.SS]` prefix and calls `debugPrint` only inside an `if (logToConsole)` guard.
- Forwards the raw stringified message to `observeSink(object?.toString() ?? '')` when `logToObserver`.
- Adds `import 'package:observe/observe.dart';`.

## Correctness verification

1. **Console output byte-identical** — The `debugPrint('[$time] $object')` line and the `time` format string are unchanged character-for-character; only wrapped in a guard. ✅
2. **Raw message to observer (no `[$time]` prefix)** — Confirmed: `observeSink(object?.toString() ?? '')` sends the unprefixed message. Matches the spec (Loki carries its own timestamp) and the `observeLogPrint` reference impl (`message?.toString() ?? ''`). ✅
3. **No `Level` param / default `info`** — `observeSink` is called with no `level:` argument; its signature defaults to `Level.info`. Signature of `logPrint` is unchanged, so all 57 call sites compile untouched. ✅
4. **No try/catch** — Omitted, per the SDK's documented never-throws / pre-`init` silent-ignore contract (`lib/src/adapter/log_print.dart`). ✅
5. **Resolver reuse** — `logToConsole` / `logToObserver` / `_logDestination` from note 109 are reused, not redeclared. ✅
6. **Import safety** — The `observe` barrel re-exports `init, log, flush, shutdown, Level, Span, …, observeSink, observeLogPrint`. None of these collide with `foundation.dart`'s symbols (`debugPrint`, `kDebugMode`) or with the file's own `logPrint`/`logToConsole`/`logToObserver`/`_logDestination`. No ambiguous-import error. ✅
7. **Runtime wiring** — `observe` is a direct dependency (`pubspec.yaml`, git `v0.1.0`), and `init(...)` is invoked in `lib/Core/App.dart` guarded by `logToObserver`, so forwarded records reach the backend at runtime. Calling `observeSink` before `init` is safely ignored. ✅

## Behavioral note (non-blocking)
- `DateTime.now()` is now only computed when `logToConsole` is true (previously always). This is an intentional, plan-sanctioned optimization with no observable effect on either output path.
- Across all `LOG_DESTINATION` values (`grafana` → observer only, `file` → console only, `both`/any other → both), there is no value that disables both sinks, so no message is silently dropped.

## Security
No security impact: no new input handling, no secrets, no network call introduced in this file (the SDK manages export/batching, already initialized elsewhere).

## Conclusion
The implementation matches the spec and plan exactly, compiles cleanly, and introduces no correctness, type, or race issues. No findings.

REVIEW_PASS
