---
name: aif-plan
description: Plan implementation for a feature or task. Always creates a named plan file with full exploration. Use when user says "plan", "new feature", "start feature", "create tasks".
argument-hint: "<description>"
disable-model-invocation: false
---

# Plan - Implementation Planning

Creates a named plan file with full codebase exploration and preference questions.

## Workflow

### Step 0: Load Project Context

**FIRST:** Read `.ai-factory/DESCRIPTION.md` if it exists to understand:
- Tech stack (language, framework, database, ORM)
- Project architecture
- Coding conventions
- Non-functional requirements

**ALSO:** Read `.ai-factory/ARCHITECTURE.md` if it exists to understand:
- Chosen architecture pattern
- Folder structure conventions
- Layer/module boundaries
- Dependency rules

Use this context when:
- Exploring codebase (know what patterns to look for)
- Writing task descriptions (use correct technologies)
- Planning file structure (follow project conventions)
- **Follow architecture guidelines from `.ai-factory/ARCHITECTURE.md` when planning file structure and task organization**

---

### Step 1: Quick Reconnaissance

Launch 1-2 Explore agents to understand the relevant codebase area:

```
Task(subagent_type: Explore, model: sonnet, prompt:
  "In [project root], find files and modules related to [feature domain].
   Report: key directories, relevant files, existing patterns, integration points.
   Thoroughness: quick. Be concise — return a structured summary, not file contents.")
```

Skip if `.ai-factory/DESCRIPTION.md` already provides sufficient context.

### Step 1.2: Ask Preferences

**IMPORTANT: Always ask the user before proceeding:**

```
AskUserQuestion: Before we start, a few questions:

1. Should I write tests for this feature?
   - [ ] Yes, write tests
   - [ ] No, skip tests

2. Logging level for implementation:
   - [ ] Minimal (default) — errors and key state changes only
   - [ ] Standard — INFO level, key events
   - [ ] Verbose — detailed DEBUG logs

3. Update documentation after implementation?
   - [ ] Yes, update docs (/aif-docs)
   - [ ] No, skip docs

4. Any specific requirements or constraints?
```

**Default to minimal logging** — log errors and key state changes only. Avoid noise logs.

Store all preferences — they will be used in the plan file and passed to `/aif-implement`.

---

### Step 2: Analyze Requirements

From the description, identify:
- Core functionality to implement
- Components/files that need changes
- Dependencies between tasks
- Edge cases to handle

If requirements are ambiguous, ask clarifying questions:
```
I need a few clarifications before creating the plan:
1. [Specific question about scope]
2. [Question about approach]
```

### Step 3: Explore Codebase

Before planning, understand the existing code through **parallel exploration**.

**Use `Task` tool with `subagent_type: Explore` to investigate the codebase in parallel.** This keeps the main context clean and speeds up research.

Launch 2-3 Explore agents simultaneously, each focused on a different aspect:

```
Agent 1 — Architecture & affected modules:
Task(subagent_type: Explore, model: sonnet, prompt:
  "Find files and modules related to [feature domain]. Map the directory structure,
   key entry points, and how modules interact. Thoroughness: medium.")

Agent 2 — Existing patterns & conventions:
Task(subagent_type: Explore, model: sonnet, prompt:
  "Find examples of similar functionality already implemented in the project.
   Show patterns for [relevant patterns: API endpoints, services, models, etc.].
   Thoroughness: medium.")

Agent 3 — Dependencies & integration points (if needed):
Task(subagent_type: Explore, model: sonnet, prompt:
  "Find all files that import/use [module/service]. Identify integration points
   and potential side effects of changes. Thoroughness: medium.")
```

Use recon from Step 1 as a starting point. Focus Explore agents on areas that need deeper understanding.

**After agents return, synthesize:**
- Which files need to be created/modified
- What patterns to follow (from existing code)
- Dependencies between components
- Potential risks or edge cases

**Fallback:** If Task tool is unavailable, use Glob/Grep/Read directly.

### Step 4: Create Task Plan

Create tasks using `TaskCreate` with clear, actionable items.

**Task Guidelines:**
- Each task should be completable in one focused session
- Tasks should be ordered by dependency (do X before Y)
- Include file paths where changes will be made
- Be specific about what to implement, not vague

Use `TaskUpdate` to set `blockedBy` relationships:
- Task 2 blocked by Task 1 if it depends on Task 1's output
- Keep dependency chains logical

### Step 5: Save Plan to File

**Plan file path:** `.ai-factory/plans/<NN>-<slug>.md` where:
- `<slug>` is derived from the description (lowercase, hyphens)
- `<NN>` is a zero-padded two-digit sequence number (`01`, `02`, `03` …)

To determine `<NN>`, find the highest existing `NN` prefix among files matching `[0-9][0-9]-*.md` in `.ai-factory/plans/` and add 1. If no numbered files exist yet, start at `01`.

**Before saving, ensure directory exists:**
```bash
mkdir -p .ai-factory/plans
```

**Plan file must include:**
- Title with feature name
- Branch and creation date
- `Settings` section (Testing, Logging, Docs)
- `Tasks` section grouped by phases
- `Commit Plan` section when there are 5+ tasks

Use the canonical template in `references/TASK-FORMAT.md` (Plan File Template).

**Commit Plan Rules:**
- **5+ tasks** → add commit checkpoints every 3-5 tasks
- **Less than 5 tasks** → single commit at the end, no commit plan needed
- Group logically related tasks into one commit
- Suggest meaningful commit messages following conventional commits

### Step 6: Next Steps

STOP after planning. The user reviews the plan and decides when to implement.

```
Plan created with [N] tasks.
Plan file: .ai-factory/plans/<NN>-<slug>.md

To start implementation, run:
/aif-implement

To view tasks:
/tasks (or use TaskList)
```

### Context Cleanup

Context is heavy after planning. All results are saved to the plan file — suggest freeing space:

```
AskUserQuestion: Free up context before continuing?

Options:
1. /clear — Full reset (recommended)
2. /compact — Compress history
3. Continue as is
```

---

## Task Description Requirements

Every `TaskCreate` item MUST include:
- Clear deliverable and expected behavior
- File paths to change/create
- Logging requirements (what to log, where, and levels)
- Dependency notes when applicable

**Never create tasks without logging instructions.**

Use canonical examples in `references/TASK-FORMAT.md`:
- TaskCreate Example
- Logging Requirements Checklist

## Important Rules

1. **NO tests if user said no** — Don't sneak in test tasks
2. **NO reports** — Don't create summary/report tasks at the end
3. **Actionable tasks** — Each task should have clear deliverable
4. **Right granularity** — Not too big (overwhelming), not too small (noise)
5. **Dependencies matter** — Order tasks so they can be done sequentially
6. **Include file paths** — Help implementer know where to work
7. **Commit checkpoints for large plans** — 5+ tasks need commit plan with checkpoints every 3-5 tasks
8. **Plan file location** — always `.ai-factory/plans/<NN>-<slug>.md` with zero-padded sequence number

## Plan File Handling

Plans live at `.ai-factory/plans/<NN>-<slug>.md`:
- `<NN>` determined by scanning existing `[0-9][0-9]-*.md` files and incrementing the highest
- `<slug>` derived from the task description (lowercase, hyphens)
- `/aif-implement` may offer deletion after completion

For concrete flow examples, read `references/EXAMPLES.md`.
