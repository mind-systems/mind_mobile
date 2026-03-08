---
name: aif-docs
description: Generate and maintain project documentation. Creates a lean README as a landing page with detailed docs/ directory split by topic. Use when user says "create docs", "write documentation", "update docs", "generate readme", or "document project".
argument-hint: "[--web]"
allowed-tools: Read Write Edit Glob Grep Bash(mkdir, npx, python) AskUserQuestion Questions WebFetch WebSearch
disable-model-invocation: true
metadata:
  author: AI Factory
  version: "1.0"
  category: documentation
---

# Docs - Project Documentation Generator

Generate, maintain, and improve project documentation following a landing-page README + detailed docs/ structure.

## Core Principles

1. **README is a landing page, not a manual.** ~80-120 lines. First impression, install, quick example, links to details.
2. **Details go to `docs/`.** Each file is self-contained — one topic, one page. A user should be able to read a single doc file and get the full picture on that topic.
3. **No duplication.** If information lives in `docs/`, README links to it — does not repeat it. Exception: installation command can appear in both (users expect it in README).
4. **Navigation.** Every docs/ file has a header line with prev/next links following the Documentation table order: `[← Previous Page](prev.md) · [Back to README](../README.md) · [Next Page →](next.md)`. First page has no prev link; last page has no next link. Every page ends with a "See Also" section linking to 2-3 related pages.
5. **Cross-links use relative paths.** From README: `docs/workflow.md`. Between docs: `workflow.md` (same directory).
6. **Scannable.** Use tables, bullet lists, and code blocks. Avoid long paragraphs. Users scan, they don't read.

## Workflow

### Step 0: Load Project Context

**Read `.ai-factory/DESCRIPTION.md`** if it exists to understand:
- Tech stack (language, framework, database)
- Project purpose and architecture
- Key features and conventions

**Explore the codebase:**
- Read `package.json`, `composer.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, etc.
- Scan `src/` structure to understand architecture
- Look for existing docs, comments, API endpoints, CLI commands
- Check for existing README.md and docs/ directory

**Scan for scattered markdown files in project root:**

Use `Glob` to find all `*.md` files in the project root (exclude `node_modules/`, `.ai-factory/`, agent dirs):

```
CHANGELOG.md, CONTRIBUTING.md, ARCHITECTURE.md, DEPLOYMENT.md,
SECURITY.md, API.md, SETUP.md, DEVELOPMENT.md, TESTING.md, etc.
```

Record each file, its size, and a brief summary of its content. This list is used in Step 1.1.

### Step 0.1: Parse Flags

```
--web  → Generate HTML version of documentation
```

### Step 1: Determine Current State

Check what documentation already exists:

```
State A: No README.md                → Full generation (README + docs/)
State B: README.md exists, no docs/  → Analyze README, propose split into docs/
State C: README.md + docs/ exist     → Depends on flags (see below)
```

**State C with `--web` flag — ask the user:**

```
Documentation already exists (README.md + docs/).

What would you like to do?
- [ ] Generate HTML only — build site from current docs as-is
- [ ] Audit & improve first — check for issues, then generate HTML
- [ ] Audit only — check for issues without generating HTML
```

- **"Generate HTML only"** → skip Step 1.1, Step 2, Step 4 — go directly to Step 3 (HTML generation), then done
- **"Audit & improve first"** → run Step 1.1 → Step 2 (State C) → Step 3 → Step 4 → Step 4.1
- **"Audit only"** → run Step 1.1 → Step 2 (State C) → Step 4 → Step 4.1 (skip Step 3)

**State C without `--web` flag** → run Step 2 (State C) as usual.

### Step 1.1: Check for Scattered Markdown Files

If scattered `.md` files were found in the project root (from Step 0), propose consolidating them into the `docs/` directory.

**Common files that should move to docs/:**

| Root file | Target in docs/ | Merge or move? |
|-----------|-----------------|----------------|
| `CONTRIBUTING.md` | `docs/contributing.md` | Move |
| `ARCHITECTURE.md` | `docs/architecture.md` | Move |
| `DEPLOYMENT.md` | `docs/deployment.md` | Move |
| `SETUP.md` | `docs/getting-started.md` | Merge (append to existing) |
| `DEVELOPMENT.md` | `docs/getting-started.md` or `docs/contributing.md` | Merge |
| `API.md` | `docs/api.md` | Move |
| `TESTING.md` | `docs/testing.md` | Move |
| `SECURITY.md` | `docs/security.md` | Move |

**Files that stay in root** (standard convention):
- `README.md` — always stays
- `CHANGELOG.md` — standard root-level file, keep as-is
- `LICENSE` / `LICENSE.md` — standard root-level file, keep as-is
- `CODE_OF_CONDUCT.md` — standard root-level file, keep as-is

**If scattered files found, ask the user:**

```
Found [N] markdown files in the project root:

  CONTRIBUTING.md (45 lines) — contribution guidelines
  ARCHITECTURE.md (120 lines) — system architecture overview
  DEPLOYMENT.md (80 lines) — deployment instructions
  SETUP.md (30 lines) — setup guide (overlaps with getting-started)

Suggested actions:
  → Move CONTRIBUTING.md → docs/contributing.md
  → Move ARCHITECTURE.md → docs/architecture.md
  → Move DEPLOYMENT.md → docs/deployment.md
  → Merge SETUP.md into docs/getting-started.md

Would you like to:
- [ ] Apply all suggestions
- [ ] Let me pick which ones
- [ ] Skip — keep files where they are
```

**When moving/merging:**
1. Create the target file in `docs/` with prev/next navigation header (following Documentation table order) and "See Also" footer
2. If merging into an existing doc — append content under a new section header, avoid duplicating info that's already there
3. **Do NOT delete originals yet** — keep them until the review step confirms everything is in place
4. Add the new docs/ page to README's Documentation table
5. Update any links in other files that pointed to the old root-level file
6. Record which files were moved/merged — this list is used in Step 4.1

**IMPORTANT:** Never force-move files. Always show the plan and get user approval first.

### Step 2 (State A): Generate from Scratch

When no README.md exists, generate the full documentation set.

#### 2.1: Analyze project for documentation topics

Explore the codebase and identify documentation topics:

```
Always include:
- getting-started.md    (installation, setup, quick start)

Include if relevant:
- architecture.md       (if project has clear architecture: services, modules, layers)
- api.md                (if project exposes API endpoints)
- configuration.md      (if project has config files, env vars, feature flags)
- deployment.md         (if Dockerfile, CI/CD, deploy scripts exist)
- contributing.md       (if open-source or team project)
- security.md           (if auth, permissions, or security patterns exist)
- testing.md            (if test suite exists)
- cli.md                (if project has CLI commands)
```

**Ask the user:**

```
I've analyzed your project and suggest these documentation pages:

1. getting-started.md — Installation, setup, quick start
2. architecture.md — Project structure and patterns
3. api.md — API endpoints reference
4. configuration.md — Environment variables and config

Would you like to:
- [ ] Generate all of these
- [ ] Let me pick which ones
- [ ] Add more topics
```

#### 2.2: Generate README.md

Structure (aim for ~80-120 lines):

```markdown
# Project Name

> One-line tagline describing the project.

Brief 2-3 sentence description of what this project does and why it exists.

## Quick Start

\`\`\`bash
# Installation steps (1-3 commands)
\`\`\`

## Key Features

- **Feature 1** — brief description
- **Feature 2** — brief description
- **Feature 3** — brief description

## Example

\`\`\`
# Show a real usage example — this is where users decide "I want this"
\`\`\`

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Installation, setup, first steps |
| [Architecture](docs/architecture.md) | Project structure and patterns |
| [API Reference](docs/api.md) | Endpoints, request/response formats |
| [Configuration](docs/configuration.md) | Environment variables, config files |

## License

MIT (or whatever is in the project)
```

**Key rules for README:**
- Logo/badge line at the top (if project has one)
- Tagline as blockquote
- Quick Start with real installation commands (detect from package manager)
- Key Features as bullet list (3-6 items, scannable)
- Real usage example that shows the "wow factor"
- Documentation table with links to docs/
- License at the bottom
- **NO long descriptions, NO full API reference, NO configuration details**

#### 2.3: Generate docs/ files

For each approved topic, create a doc file:

```markdown
[← Previous Topic](previous-topic.md) · [Back to README](../README.md) · [Next Topic →](next-topic.md)

# Topic Title

Content organized by subtopic with headers, code examples, and tables.
Keep each section self-contained.

## See Also

- [Related Topic 1](related-topic.md) — brief description
- [Related Topic 2](other-topic.md) — brief description
```

**Navigation link order** follows the Documentation table in README.md (top to bottom). The first doc page omits the "← Previous" link; the last page omits the "Next →" link. Example for 4 pages:

```
getting-started.md:  [Back to README](../README.md) · [Architecture →](architecture.md)
architecture.md:     [← Getting Started](getting-started.md) · [Back to README](../README.md) · [API Reference →](api.md)
api.md:              [← Architecture](architecture.md) · [Back to README](../README.md) · [Configuration →](configuration.md)
configuration.md:    [← API Reference](api.md) · [Back to README](../README.md)
```

**Content guidelines per topic:**

**getting-started.md:**
- Prerequisites (runtime versions, tools needed)
- Step-by-step installation
- First run / quick start
- Verify it works (expected output)
- Next steps links

**architecture.md:**
- High-level overview (diagram if useful)
- Directory structure with explanations
- Key patterns (naming, imports, error handling)
- Data flow

**api.md:**
- Base URL / configuration
- Authentication
- Endpoints grouped by resource
- Request/response examples
- Error codes

**configuration.md:**
- All environment variables with descriptions and defaults
- Config files and their purpose
- Feature flags

**deployment.md:**
- Build steps
- Environment setup
- CI/CD pipeline description
- Monitoring / health checks

### Step 2 (State B): Split Existing README into docs/

When README.md exists but is long (150+ lines) and there's no docs/ directory.

#### 2.1: Analyze README structure

Read README.md and identify:
- Which sections should stay (landing page content)
- Which sections should move to docs/ (detailed content)

**Stays in README:**
- Title, tagline, badges
- "Why?" / key features bullet list
- Quick install (1-3 commands)
- Brief example
- Documentation links table
- External links, license

**Moves to docs/:**
- Detailed setup instructions → `getting-started.md`
- Architecture / project structure → `architecture.md`
- Full API reference → `api.md`
- Configuration details → `configuration.md`
- Contributing guidelines → `contributing.md`
- Any section longer than ~30 lines that covers a single topic

#### 2.2: Propose changes to user

```
Your README.md is [N] lines. I suggest splitting it:

README.md (~100 lines) — keep as landing page:
  ✓ Title + tagline
  ✓ Key features
  ✓ Quick install
  ✓ Example
  ✓ Documentation links table

Move to docs/:
  → "Installation" section → docs/getting-started.md
  → "Configuration" section → docs/configuration.md
  → "API Reference" section → docs/api.md
  → "Architecture" section → docs/architecture.md

Proceed?
```

#### 2.3: Execute the split

1. Create `docs/` directory
2. Create each doc file with content from README + prev/next navigation header (following Documentation table order) + "See Also" footer
3. Rewrite README as landing page with Documentation links table
4. **Verify no content was lost** — every section from old README must exist somewhere

### Step 2 (State C): Improve Existing Docs

When both README.md and docs/ exist.

#### 2.1: Audit current documentation

Check for:
- **README length** — is it still a landing page (<150 lines)?
- **Missing topics** — are there aspects of the project not documented?
- **Stale content** — do docs reference files/APIs that no longer exist?
- **Navigation** — do all docs have prev/next header links and "See Also"?
- **Broken links** — verify all internal links point to existing files/anchors
- **Consistency** — same formatting style across all docs
- **Standards compliance** — does existing documentation match the current skill standards? (see 2.1.1)

#### 2.1.1: Standards compliance check

Check existing docs against current Core Principles for gaps (missing navigation, missing "See Also", stale formats). For the full compliance table and auto-fix rules → read `references/REVIEW-CHECKLISTS.md` (Standards Compliance section).

**When gaps are found**, include them in the audit report alongside content issues (Step 2.2). Treat them as regular improvements — show the plan and get user approval before applying.

#### 2.2: Propose improvements

```
Documentation audit results:

✅ README is lean (105 lines)
⚠️  docs/ pages missing prev/next navigation — will add
⚠️  docs/api.md is missing — project has 12 API endpoints
⚠️  docs/configuration.md references old env var DB_HOST (now DATABASE_URL)
❌ docs/getting-started.md links to docs/setup.md which doesn't exist

Proposed fixes:
1. Add prev/next navigation to all docs/ pages
2. Create docs/api.md with endpoint reference
3. Update DATABASE_URL in docs/configuration.md
4. Fix broken link in docs/getting-started.md

Apply fixes?
```

### Step 3: Generate HTML Version (--web flag)

When `--web` flag is passed, generate a static HTML site from the markdown docs.

#### 3.1: Create docs-html/ directory

```bash
mkdir -p docs-html
```

#### 3.2: Generate HTML files

For each markdown file (README.md + docs/*.md), generate an HTML version:

Read the HTML template from `templates/html-template.html` and use it for each page.
Customize: `{page_title}`, `{project_name}`, `{nav_links}`, `{content}`.

#### 3.3: Convert markdown to HTML

For each doc file: parse markdown → convert to HTML elements → fix `.md` links to `.html` → generate nav bar → write to `docs-html/`.

File mapping: `README.md` → `index.html`, `docs/*.md` → `*.html`.

#### 3.4: Output result

Show tree of generated files and `open docs-html/index.html` hint.

## Step 4: Documentation Review

**MANDATORY after any content change** (generation, split, improvement, file consolidation). Do NOT skip this step.

**Skip this step** only when "Generate HTML only" was chosen — no content was modified, nothing to review.

Read every generated/modified file and evaluate it against both checklists from `references/REVIEW-CHECKLISTS.md`. Two checklists: **Technical Accuracy** and **Readability & Completeness**.

Fix any issues found before presenting the result to the user. Display results as a compact table with ✅/❌/⚠️ status per item.

### Step 4.1: Clean Up Moved Files

**Only if files were moved/merged from root into docs/ during Step 1.1.**

After the review confirms all content is correctly placed in `docs/`, offer to delete the original root-level files:

```
The following root files have been incorporated into docs/:

  CONTRIBUTING.md → now in docs/contributing.md
  ARCHITECTURE.md → now in docs/architecture.md
  DEPLOYMENT.md → now in docs/deployment.md
  SETUP.md → merged into docs/getting-started.md

These originals are no longer needed. Delete them?
- [ ] Yes, delete all originals
- [ ] Let me pick which ones to delete
- [ ] No, keep them (I'll clean up later)
```

**When deleting:**
1. Verify one more time that the target docs/ file contains all content from the original
2. Delete the root file
3. Run `git status` to show what was deleted

**Do NOT auto-delete.** Always ask. The user may want to keep originals temporarily for reference or diff comparison.

### Step 5: Update AGENTS.md

**After any documentation changes**, update the Documentation section in `AGENTS.md` (if the file exists).

Read `AGENTS.md` and find the `## Documentation` section. Update it to reflect the current state of all documentation files:

```markdown
## Documentation
| Document | Path | Description |
|----------|------|-------------|
| README | README.md | Project landing page |
| Getting Started | docs/getting-started.md | Installation, setup, first steps |
| Architecture | docs/architecture.md | Project structure and patterns |
| API Reference | docs/api.md | Endpoints, request/response formats |
| Configuration | docs/configuration.md | Environment variables, config files |
```

**Rules:**
- List README.md first, then all docs/ files in the same order as the README Documentation table
- If files were moved/merged from root during Step 1.1, reflect the new locations
- If new doc pages were created, add them
- If doc pages were removed, remove them
- Keep descriptions concise (under 10 words)
- If `AGENTS.md` doesn't exist, skip this step silently

### Context Cleanup

Context is heavy after codebase scanning and documentation generation. All docs are saved — suggest freeing space:

```
AskUserQuestion: Free up context before continuing?

Options:
1. /clear — Full reset (recommended)
2. /compact — Compress history
3. Continue as is
```

## Important Rules

1. **Always ask before making changes** to existing documentation — show the plan first
2. **Never delete content** without moving it somewhere else
3. **Detect real project info** — don't invent features, read package.json/config files
4. **Use the project's language** — if project README is in Russian, write docs in Russian
5. **Preserve existing badges/logos** — don't remove them during restructuring
6. **Add to .gitignore** if generating HTML: add `docs-html/` to .gitignore
