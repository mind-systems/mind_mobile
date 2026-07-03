# Code Review: Copy `module_state.proto` + regenerate + `ActivityType.root`

**Scope reviewed:** `proto/module_state.proto`, generated stubs (`module_state.pb.dart`, `.pbenum.dart`, `.pbjson.dart`), `lib/Core/Grpc/ActivityType.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`. Plan: `.ai-factory/plans/14-copy-module-state-proto-regenerate-activitytype-root.md`.

## Verification performed

1. **Proto is a verbatim copy of the source of truth.** `diff mind_api/proto/module_state.proto mind_mobile/proto/module_state.proto` → IDENTICAL. All promised additions present: `ROOT = 3`, `ActivityStartCmd.client_activity_id = 5`, `session_id` on `ActivityEnd/Stop/Pause/ResumeCmd`, `StateEvent.activity_type = 4`. No `.proto` was hand-authored (ownership rule respected).

2. **Stubs match the proto and only `module_state.*` changed.** `git status` shows the only generated files touched are `module_state.pb.dart`, `.pbenum.dart`, `.pbjson.dart` — no unrelated stub churn, so the local toolchain matches the committed baseline (no version drift). `.pbenum.dart` correctly adds `ROOT = 3` to `values` and bumps `_initByValueList(values, 3)`. `.pb.dart` exposes `clientActivityId`, `sessionId` (on all four command messages), and `activityType` with correct field indices/tags.

3. **Forward mapper is exhaustive.** `_mapActivityType` now covers `breath/meditation/root` with no default — the compiler enforces exhaustiveness over the app enum, so a future enum case can't silently fall through.

4. **Reverse mapper is correct and safe.** `_mapActivityTypeFromProto` maps `BREATH/MEDITATION/ROOT` and routes `ACTIVITY_TYPE_UNSPECIFIED` + any unknown to a logged drop returning `null` — matches the proto's sentinel-safety intent (no coercion to a real type). `logPrint` is already imported (`Logger.dart`, line 6) and the message follows the existing `[ModuleStateChannel]` prefix convention.

5. **`unused_element` handled as planned.** The reverse mapper has no caller in this milestone (note 14 wires it later); the `// ignore: unused_element` prefix keeps analysis clean. Confirmed: `flutter analyze lib/Core/Grpc/` → **No issues found!**

## Findings

None. The change is a faithful, behavior-preserving contract update: new wire fields are unused this milestone (expected), the forward switch is complete, and the reverse mapper's drop-on-unspecified behavior is correct for the non-optional proto3 `activity_type` field (which defaults to `UNSPECIFIED` when unset).

REVIEW_PASS
