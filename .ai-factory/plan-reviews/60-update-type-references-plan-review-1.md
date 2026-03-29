## Plan Review: Update type references

**Plan file:** `.ai-factory/plans/60-update-type-references.md`
**Risk Level:** 🔴 High

### Context Gates

- **ARCHITECTURE.md:** WARN — no architectural concerns with the plan's scope (single infra file, no layer boundary crossed). No issues.
- **RULES.md:** WARN — not applicable (plan touches infra, not module services or DI wiring). No issues.
- **ROADMAP.md:** ERROR — Milestone 9.1 is marked `[x]` complete with the expectation that proto type names were renamed (`StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`). **The rename has not happened.** See Critical Issues below.

### Critical Issues

**1. The plan's premise is false — proto types were never renamed**

The plan's Context section states:

> "the generated Dart stubs now use `StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`"

This is incorrect. Verified against all three sources:

| Source | `SessionRequest`? | `StateRequest`? |
|--------|-------------------|-----------------|
| `mind_api/proto/module_state.proto` (source of truth) | ✅ present | ❌ does not exist |
| `mind_mobile/proto/module_state.proto` (local copy) | ✅ present | ❌ does not exist |
| `lib/Core/Grpc/generated/module_state.pb.dart` (generated stubs) | ✅ present | ❌ does not exist |

The same applies to all five type names the plan wants to rename. The generated stubs still define `SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent`, `SessionResponse_Event`. None of the new names (`StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`) exist anywhere in the generated code.

**Implementing this plan would produce compile errors on every changed line** — roughly 25 references to types that do not exist.

**2. Roadmap milestone 9.1 is incorrectly marked complete**

Roadmap 9.1 says:

> [x] verify `module_state.pb.dart` ... uses new type names `StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`

The `PresenceCmd`/`PresenceState` removal part of 9.1 was completed (those types are absent from the stubs). But the type rename part was not — the proto source of truth in `mind_api/proto/module_state.proto` still uses the old names. The milestone should be split or unchecked for the rename portion.

**3. Prerequisite work is missing in `mind_api`**

Per the proto ownership rules in root `CLAUDE.md`:

> `mind_api/proto/` is the single source of truth for all `.proto` files. Any contract change starts in `mind_api/proto/`.

The rename `SessionRequest → StateRequest`, `SessionStatus → ActivityStatus`, etc. must first be implemented in `mind_api/proto/module_state.proto`, then the API code updated, then the proto copied to `mind_mobile` and stubs regenerated. None of this has happened.

### Suggestions

None — the plan cannot proceed at all until the prerequisite proto rename is done.

### Recommended Next Steps

1. **Uncheck roadmap 9.1** (or split it) — the presence removal is done, but the type rename is not.
2. **Plan and execute the proto rename in `mind_api`** — rename `SessionRequest → StateRequest`, `SessionResponse → StateResponse`, `SessionStatus → ActivityStatus`, `SessionStateEvent → StateEvent`, `SessionErrorEvent → StateErrorEvent` in `mind_api/proto/module_state.proto`; update all API code that references these types.
3. **Copy proto and regenerate stubs** — copy the updated proto to `mind_mobile/proto/`, run `scripts/gen_proto.sh`, verify the generated stubs contain the new names.
4. **Then** this plan (60) becomes applicable and can be re-reviewed.

### Positive Notes

- The plan itself is well-structured and thorough — it lists every line number, every enum constant, every oneof discriminator. The level of detail would make implementation straightforward once the prerequisite is met.
- Task 2 (verify no other files reference old names) is a good safety net.
- The plan correctly identifies that `ModuleStateChannel.dart` is the only hand-written file directly using these proto types.
