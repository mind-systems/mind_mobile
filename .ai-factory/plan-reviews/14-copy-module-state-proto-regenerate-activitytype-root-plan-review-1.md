## Code Review Summary

**Files Reviewed:** plan (1) + targeted codebase (proto source, old mobile proto, generated stubs, `ActivityType.dart`, `ModuleStateChannel.dart`, `gen_proto.sh`, `analysis_options.yaml`, spec note 13, roadmap Phase 61)
**Risk Level:** 🟡 Medium

### Context Gates
- **Roadmap (WARN → OK):** The plan title `Copy module_state.proto + regenerate + ActivityType.root` matches the Phase 61 contract line in `ROADMAP.md:51`, which links `Spec: .ai-factory/notes/13-rootchild-proto-regen.md`. The plan faithfully reproduces every clause of that spec note (verbatim copy, `gen_proto.sh` not build_runner, new wire surface list, forward + reverse mapper, logged-drop-on-unknown). Linkage is clean.
- **Architecture (OK):** Task 3 keeps proto↔app mapping inside `ModuleStateChannel`/`ActivityType.dart` — consistent with the existing domain/wire seam. No boundary violation.
- **Rules (OK):** `RULES.md` has no clause bearing on this change. No `.ai-factory/skill-context/aif-review/SKILL.md` present.

### Critical Issues
None (nothing that produces a runtime error or wrong wire behavior).

### Important Issues

**1. Task 4's "analyze clean" assumption is likely wrong — the new reverse mapper is unused in this milestone and will trip `unused_element`.**
Task 3 adds a NEW private reverse mapper (`proto.ActivityType → ActivityType?`) whose only consumer is note 14 (a later, separate task). Within the scope of *this* plan nothing calls it. The Dart analyzer reports `unused_element` (severity: warning, enabled by default — not a `flutter_lints` opt-in) for unreferenced private declarations, and `flutter analyze` exits non-zero on warnings. So Task 4's instruction to "run `flutter analyze` and confirm it is clean" will fail on a `The declaration '_map…' isn't referenced` warning — for a mapper the plan *deliberately* leaves unused.
This is the plan's own internal contradiction: Task 3 says "this reverse mapper is the seam the session registry (note 14) will use," i.e. intentionally dead until note 14, while Task 4 demands a clean analyze.
Resolution — pick one and state it in the plan:
- Add `// ignore: unused_element` on the reverse mapper (cleanest; removed by note 14 when it wires the caller), **or**
- Relax Task 4 to "clean except one expected `unused_element` warning on the not-yet-wired reverse mapper," matching how Task 4 already whitelists unused new proto fields.
As written, Task 4 will report a failure the implementer may waste time chasing or "fix" by deleting the mapper the next task depends on.

### Minor Notes
- **Line reference drift:** Task 3 cites the forward switch at `:213-219`; the switch body is `214-219` and the method closes at `220`. The spec note says `:213-220`. Immaterial — the switch is unambiguous — but worth aligning if edited.
- **Toolchain-determinism caveat (WARN):** `gen_proto.sh` does `rm -rf "$OUT_DIR"` then regenerates *all* `proto/*.proto` in one pass. Task 1's guard "confirm no unrelated stub files change beyond `module_state.*`" only holds if the local `protoc` (libprotoc 34.0) and `protoc-gen-dart` (protoc_plugin 25.0.0) match the versions that produced the committed stubs. A version drift would reformat every stub and make the "no unrelated changes" check falsely fail. Consider adding: if unrelated stubs change, verify the plugin/protoc versions before assuming a contract problem.

### Positive Notes
- Correctly distinguishes `./scripts/gen_proto.sh` from `flutter pub run build_runner build` (Drift) — a real prior-art footgun called out in both CLAUDE.md and the handoff.
- Verified against the live source of truth: `mind_api/proto/module_state.proto` does contain exactly the promised additions (`ROOT = 3`, `client_activity_id = 5`, `session_id` on end/stop/pause/resume, `StateEvent.activity_type = 4`), and the old mobile proto/stubs confirmably lack them.
- The forward switch (`_mapActivityType`) is the only exhaustive switch over the app-level `ActivityType`; all other callers pass enum literals (`.breath`/`.meditation`), so adding `.root` cannot silently break another `switch` — the plan's single-arm addition is complete.
- Good instinct on the reverse mapper returning nullable and logging a drop for `ACTIVITY_TYPE_UNSPECIFIED`/unknown rather than coercing to a real type — matches the proto's sentinel-safety intent.
- Honest scoping: no behavior change, new fields expected-unused, verification-only final task.
