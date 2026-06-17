# Code Review: Normalize the `dart:developer` call sites to `logPrint`

**Scope reviewed:** 15 in-scope source files + `lib/Logger.dart`, `lib/Core/Api/HttpClient.dart` (verified untouched), `flutter analyze`.
**Risk Level:** 🟢 Low — purely mechanical logging transport swap.

## Verification performed

1. **Import swap complete & non-duplicated.** Every one of the 15 modified files now imports `package:mind/Logger.dart` exactly once (no duplicate when the file already imported it). No `import 'dart:developer'` remains anywhere in `lib/` except the dead `lib/Core/Api/HttpClient.dart` — which is correctly left untouched (import + both `log(...)` calls intact).

2. **No residual `log(` / `dev.log(` / `dev.` references.** Grep confirms the only `log(` / `dart:developer` import in `lib/` is in `HttpClient.dart`. The aliased import in `BreathModuleStateChannel.dart` (`as dev`) was correctly replaced and all five `dev.log(...)` calls rewritten to `logPrint(...)`. The only remaining `dev.` matches in the tree are unrelated hostname strings in `Environment.dart`.

3. **Named args fully removed — no compile hazards.** `logPrint` takes a single positional `Object?`. Every converted call passes exactly one string argument; no leftover `name:` / `error:` / `level:` named arguments survive (the `error:` matches in the diff are the literal word "error" inside message strings, not arguments). The `level: 900` site in `ModuleStateChannel.dart` ("unhandled status") correctly dropped the level.

4. **Errors never dropped.** Every site that carried `error: e` already interpolated `$e` in its message text (e.g. `GrpcLoggingInterceptor`: `'[gRPC] ${method.path} ERROR: $e'`), so dropping the redundant `error:` argument loses no information — the error remains in the logged string.

5. **No double-bracketing.** Sites whose message already began with their `[Tag]` simply dropped `name:`. The two sites without a pre-existing tag had the tag prepended correctly:
   - `GrpcLoggingInterceptor` → `[gRPC]` prepended.
   - `BreathModuleStateChannel` → `[BreathModuleState]` prepended to all five messages.

6. **Message text preserved verbatim**, including the `⚠️` markers in `SyncEngine`, the `—` em-dashes in stream-error messages, and all interpolations.

7. **Analyzer clean.** `flutter analyze` over the changed files reports only 3 pre-existing `info`-level `library_prefixes` lints (`bsProto`/`syncProto` in `SyncApi.dart`/`SyncGrpcListener.dart` import prefixes) that are unrelated to this change and predate it. No errors, no unused-import warnings, no missing-symbol errors were introduced.

## Findings

None. The implementation matches the plan's conventions exactly and introduces no correctness, runtime, or compilation risk.

REVIEW_PASS
