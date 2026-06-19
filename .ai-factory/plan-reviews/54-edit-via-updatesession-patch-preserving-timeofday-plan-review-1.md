# Plan Review: Edit via `UpdateSession` (PATCH), preserving `timeOfDay`

**Plan:** `54-edit-via-updatesession-patch-preserving-timeofday.md`
**Files Reviewed:** 5 (plan, both proto files, `BreathSessionApi.dart`, generated `breath_sessions.pb.dart`, `SaveBreathSessionRequest.dart`)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture** (`ARCHITECTURE.md` / `CLAUDE.md` proto-ownership): ✅ PASS. The plan respects the proto-contract rule — `mind_api/proto/` is the source of truth, mobile copies explicitly (no symlink) and regenerates. The change stays within the domain API layer (`lib/BreathModule/Core/BreathSessionApi.dart`), the correct boundary; no DTO/module/ViewModel changes leak.
- **Rules** (`RULES.md`): ✅ PASS. None of the three project rules apply — no Module Service state changes, no `App.dart` wiring, no DI changes. Edit is confined to one method body.
- **Roadmap** (`ROADMAP.md`): ✅ PASS. Directly implements Phase 43 ("Session edit: switch from ReplaceSession (PUT) to UpdateSession (PATCH)"). Plan text, guards, and verification steps match the roadmap entry and the referenced spec note `.ai-factory/notes/126-switch-edit-to-patch-updatesession.md` (confirmed present).

## Verification Against Codebase

The plan's assumptions were checked against the actual code and all hold:

1. **API contract already dropped `ReplaceSession`** — confirmed: `mind_api/proto/breath_sessions.proto` has no `ReplaceSessionRequest` message and no `rpc ReplaceSession`, while `mind_mobile/proto/breath_sessions.proto` still carries both. Task 1's diff description ("only difference is removal of ReplaceSession") is exactly correct.
2. **Generated `UpdateSessionRequest` signature matches the plan's snippet** — confirmed in `breath_sessions.pb.dart:620`: named params `id`, `description`, `exercises: ExerciseList?`, `shared`, `timeOfDay`. The plan's call site compiles as written.
3. **`ExerciseList` wrapper factory accepts `exercises`** — confirmed (`pb.dart:171`, `factory ExerciseList({Iterable<ExerciseDto>? exercises})`). `proto.ExerciseList(exercises: _mapExercisesToProto(...))` is valid.
4. **`_mapExercisesToProto` / `_mapSession` unchanged** — both return the types the new call needs; no signature change required.
5. **Call site is isolated** — `BreathSessionApi.update()` is the only `replaceSession` reference outside the generated folder. Callers (`BreathSessionRepository.update` → `IBreathSessionApi.update`) pass `(String id, SaveBreathSessionRequest)`; the interface signature is untouched, so no ripple.
6. **`time_of_day` correctly omitted** — `SaveBreathSessionRequest` has no `timeOfDay` field, so there is no risk of accidentally threading it through. The PATCH-preserves-omitted contract is the whole fix.

## Critical Issues

None.

## Minor Notes (non-blocking)

- **Task 2 file list is incomplete but harmless.** It lists `breath_sessions.pb.dart`, `.pbgrpc.dart`, `.pbjson.dart` but omits `breath_sessions.pbenum.dart` (which exists today and holds the `StepType` / `TimeOfDay` / `SessionSection` enums). `gen_proto.sh` does `rm -rf "$OUT_DIR"` then regenerates every file in one pass, so the `.pbenum.dart` is regenerated regardless — the omission is only a documentation gap in the task's "Files" list, not a functional risk.
- **`description` and `shared` are always sent on edit.** Because `SaveBreathSessionRequest.description`/`shared` are non-nullable, the PATCH always carries them (presence always set). This is intentional and correct for a full-form edit — only `time_of_day` relies on the omit-to-preserve behavior. Worth being aware of, but no change needed.

## Positive Notes

- Guards are precise and correct: keep `create()`/`delete()`/`fetch*`/`starSession` untouched, send the full exercise array, never add `time_of_day`.
- Task dependencies are correctly ordered (proto sync → regen → call-site swap → verify).
- Verification step (`flutter analyze` + grep for residual `replaceSession` outside generated + functional re-fetch check) is appropriate and sufficient given testing is scoped out.
- The plan correctly anticipates that the call site *must* move to `updateSession` to compile once the regenerated stubs drop `ReplaceSessionRequest` — this is a compile-forcing change, not just a behavioral one, and the plan sequences it that way.

PLAN_REVIEW_PASS
