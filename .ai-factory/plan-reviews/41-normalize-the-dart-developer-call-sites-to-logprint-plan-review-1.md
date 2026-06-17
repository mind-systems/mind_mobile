# Plan Review: Normalize the `dart:developer` call sites to `logPrint`

## Code Review Summary

**Files Reviewed:** plan + 15 in-scope source files + `Logger.dart`, ROADMAP, RULES, ARCHITECTURE
**Risk Level:** 🟢 Low

This is a purely mechanical transport swap with no behavioral or structural change. I verified the plan against the actual codebase: file list, line numbers, call-site shapes, tag presence, error/level argument presence, the `logPrint` signature, and the exclusion of `HttpClient.dart`. Everything checks out.

### Context Gates

- **Architecture (`ARCHITECTURE.md`):** No boundary impact — `logPrint` is the established logging primitive in `lib/Logger.dart`; the swap collapses a second path into it. No new dependencies, no layer crossings. ✅ no findings.
- **Rules (`RULES.md`):** The three project rules concern Module Service statelessness, App.dart purity, and constructor injection — none touched by a logging-import swap. ✅ no findings.
- **Roadmap (`ROADMAP.md`):** Directly linked. Plan implements Phase 35's open milestone *"Normalize the `dart:developer` call sites to `logPrint`"* and is faithful to its spec note `.ai-factory/notes/111-normalize-dart-developer-to-logprint.md`. The plan even refines the ROADMAP's `→ logPrint('[X] $msg: $e')` example with two correct safeguards (don't double-bracket an already-tagged message; don't append `$e` twice). ✅ aligned.

### Verification Performed

- **File count is exact.** `import 'dart:developer'` appears in 16 `lib/` files; excluding the out-of-scope `HttpClient.dart` leaves precisely the 15 listed. ✅
- **`logPrint` signature is compatible.** `logPrint(Object? object)` takes a single positional arg; every rewrite produces a single-string call. No `name:`/`error:`/`level:` named params survive. ✅
- **`error:` audit.** The only in-scope `log(...)` calls carrying `error:` are `GrpcLoggingInterceptor.dart:16,30`, and both messages already interpolate `$e` (`'${method.path} ERROR: $e'`) — so the plan's "drop `error: e`, don't append `$e` twice" is correct. All other in-scope error context is already inline as `$e`. ✅
- **`level:` audit.** The only in-scope `level:` on a `log(...)` is `ModuleStateChannel.dart:145` (`level: 900`), which the plan explicitly drops. ✅
- **Tag-presence claims verified.** All cited messages in `GrpcConnectionManager`, `ModuleStateChannel`, `ModuleInstructionStream`, `BiometricStreamClient`, `SyncEngine`, `SyncGrpcListener`, `AppLifecycleService`, `GrpcClient`, `TokenNotifier`, `McpViewModel`, and the User files already carry their `[Tag]` prefix → `name:` is correctly just dropped. `GrpcLoggingInterceptor` (untagged) and `BreathModuleStateChannel` (aliased, untagged) are the only ones the plan prepends a bracket tag to — matching reality. ✅
- **Multi-line collapses confirmed.** The multi-arg multi-line `log(` forms exist exactly where the plan says (GrpcConnectionManager ~82/~138, ModuleStateChannel ~86, BiometricStreamClient ~108/117/124/132/179, ModuleInstructionStream ~72/115/124/133). ✅
- **Aliased import (Task 8).** `BreathModuleStateChannel.dart:2` is `import 'dart:developer' as dev;` with 5 `dev.log(... name: 'BreathModuleState')` calls (lines 65/71/76/81/125), untagged in the message — plan's prepend-`[BreathModuleState]` instruction is correct. ✅
- **Import-removal safety.** None of the 15 files use any other `dart:developer` symbol (`Timeline`, `inspect`, `debugger`, `Service`, `postEvent`, etc.) — only `log`. Removing the import is safe everywhere. ✅
- **No duplicate-import risk.** None of the 15 in-scope files already import `package:mind/Logger.dart`, so the "don't duplicate" guard is harmless. ✅

### Critical Issues

None.

### Positive Notes

- Conventions section is unusually precise about the two failure modes that would silently corrupt messages (double-bracketing, double-`$e`) and explicitly forbids dropping the error — the right guardrails for a mechanical sweep.
- Scope boundary (`HttpClient.dart` excluded as dead code) is stated in both the conventions and the verify step, matching the spec note.
- Task 9 (verify via grep + `flutter analyze`) is the correct final gate; the residual-import grep will confirm only `HttpClient.dart` remains.
- Commit messages follow the project's type-prefix-free, sentence-case convention.

### Informational (non-blocking, not defects)

- Task 9's "grep for bare `log(`" could in principle surface false positives like `Dialog(`/`catalog(`; none exist in the touched files, so this won't cause confusion in practice. No action needed.
- Line numbers cited in the tasks will drift as multi-line calls collapse to single lines; this is expected and harmless since the tasks identify sites by content, not just position.

PLAN_REVIEW_PASS
