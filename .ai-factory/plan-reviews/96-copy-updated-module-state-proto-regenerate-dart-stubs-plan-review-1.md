# Plan Review: Copy updated `module_state.proto` + regenerate Dart stubs

**Plan:** `96-copy-updated-module-state-proto-regenerate-dart-stubs.md`
**Files/areas reviewed:** 5 (both `module_state.proto` snapshots, `scripts/gen_proto.sh`, generated `module_state.pbenum.dart`, all `ActivityType` consumers in `lib/`)
**Risk Level:** 🟢 Low

All claims below were verified directly against the live tree.

## Context Gates

- **Proto ownership rule (root + `mind_mobile` CLAUDE.md):** ✅ Fully respected. `mind_api/proto/` is the
  source of truth; the plan does a full byte-for-byte copy into `mind_mobile/proto/`, forbids editing
  any other `.proto`, and forbids hand edits — matching "copy explicitly, never symlink."
- **Snapshot sync:** ✅ Verified — both repos contain the identical set of 11 `.proto` files. The **only**
  content difference is in `module_state.proto`: API has `MEDITATION = 2;` plus the comment change
  ("Only one real member for now…" → "Extension point for future activity types."); mobile is missing
  both. The plan's description of the diff is exactly correct.
- **Flutter path rule:** ✅ Task 3 uses `/usr/local/bin/flutter analyze`, matching the recorded preference.
- **Architecture / Roadmap:** No boundary concerns — the change is confined to the proto snapshot and
  generated stubs under `lib/Core/Grpc/generated/`, consistent with the documented gRPC layout. — WARN: no
  ROADMAP linkage stated in the plan; confirm a milestone entry exists if your process requires it (non-blocking).

## Critical Issues

None.

## Verification of the plan's key claims

1. **"Full file copy keeps the snapshot byte-identical" (Task 1):** ✅ Correct and the right approach. The
   diff is genuinely limited to the enum member + comment.
2. **`gen_proto.sh` regenerates all stubs from repo root (Task 2):** ✅ Verified. The script `cd`s to repo
   root, `rm -rf`s + recreates `lib/Core/Grpc/generated/`, and runs `protoc … "$PROTO_DIR"/*.proto` in one
   pass. It guards for both `protoc` and `protoc-gen-dart` and exits with a clear message if missing. The
   plan's note that other stubs get rewritten "harmlessly" is accurate **because** the rest of the snapshot
   is already in sync (confirmed above) — so the regenerated output for other files will be identical content.
3. **Generated filenames (Task 2/3):** ✅ All four exist today (`module_state.pb.dart`, `.pbenum.dart`,
   `.pbgrpc.dart`, `.pbjson.dart`); `module_state.proto` defines `service ModuleStateService`, so
   `.pbgrpc.dart` will continue to be emitted.
4. **"No application code changes required" (Task 3):** ✅ Verified correct. The generated `proto.ActivityType`
   is a `ProtobufEnum` subclass (not a Dart `enum`), so no consumer is required to switch over it
   exhaustively. The only activity-type `switch` in the codebase —
   `lib/Core/Grpc/ModuleStateChannel._mapActivityType()` — switches over the **separate handwritten enum**
   `lib/Core/Grpc/ActivityType.dart` (which contains only `breath`), **not** over the generated proto enum.
   Adding `MEDITATION = 2` to the proto enum adds a new static const and does not alter that handwritten
   enum, so nothing breaks and the project will still compile. `flutter analyze` is an appropriate final gate.

## Informational note (out of scope for this milestone, but worth recording)

To actually *produce* a `MEDITATION` activity from the client later, the handwritten
`lib/Core/Grpc/ActivityType.dart` enum and the non-exhaustive `_mapActivityType()` switch in
`ModuleStateChannel.dart` would need a corresponding case. That is correctly **not** part of this plan —
this milestone only makes the proto member available client-side. No action required now; flagged only so
the follow-up isn't forgotten when meditation sessions are wired up.

## Positive Notes

- Models the documented proto-sync workflow end to end: copy → regen → verify, with correct task dependencies.
- Respects proto ownership precisely (full copy, no hand edits, no other `.proto` touched).
- Includes a concrete verification step (presence of `MEDITATION` value + `flutter analyze`) rather than
  stopping at codegen.
- Scope is tight and the diff is genuinely minimal and low-risk.

## Verdict

The plan is accurate, complete for its stated scope, and aligned with project conventions. Every factual
claim it makes was verified against the codebase and holds. No changes required.

PLAN_REVIEW_PASS
