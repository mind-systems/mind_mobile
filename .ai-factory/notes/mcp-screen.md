# MCP Screen — Personal Access Tokens

Entry point: Profile screen → "MCP" cell (new row, below existing settings, before logout cell).

---

## Implementation Notes

- **Style**: follow the existing Profile screen style — same spacing, typography, colors, and separator lines. New cell types (token row, reveal modal) should feel consistent with the existing design language.
- **Architecture**: follow the layered architecture defined in `CLAUDE.md` and `.ai-factory/ARCHITECTURE.md`:
  - API calls via `IUserApi` / `UserApi` (Dio)
  - Domain state in a Notifier (RxDart)
  - Module boundary via Service interface + DTO conversion
  - ViewModel as Riverpod `StateNotifier`; screen reads only from ViewModel
  - Navigation via Coordinator pattern
  - New route added to `router.dart`

---

## MCP Screen

Shows the list of existing tokens and a button to create a new one.

```
┌─────────────────────────────┐
│                             │
│  Personal access tokens     │
│  allow Claude Desktop to    │
│  access your exercises.     │
│                             │
├─────────────────────────────┤
│  My laptop          🗑       │
│  Created 14 Mar 2026        │
│                             │
│  Work MacBook       🗑       │
│  Created 10 Mar 2026        │
│                             │
├─────────────────────────────┤
│                             │
│     [ + Create token ]      │
│                             │
└─────────────────────────────┘
```

- Each token row shows: user-defined **name** + creation date + revoke button (🗑)
- Tapping 🗑 shows a confirmation dialog before revoking
- No token value is shown here (only revealed once, at creation)

---

## Create Token — bottom sheet or modal

Tapping "Create token" opens a bottom sheet:

```
┌─────────────────────────────┐
│  New token                  │
│                             │
│  Name                       │
│  ┌─────────────────────┐    │
│  │ My laptop           │    │
│  └─────────────────────┘    │
│                             │
│     [ Create ]              │
└─────────────────────────────┘
```

- Name field is required (e.g. "My laptop", "Work MacBook")
- Tapping Create calls the API and transitions to the reveal modal

---

## Token Reveal — one-time modal

Shown immediately after creation. Replaces or overlays the bottom sheet.

```
┌─────────────────────────────┐
│  Copy your token            │
│                             │
│  This is shown only once.   │
│  Give it to your AI.        │
│                             │
│  ┌─────────────────────┐    │
│  │ mind_pat_xK9mZ...   │    │
│  └─────────────────────┘    │
│                             │
│     [ Copy ]  [ Done ]      │
└─────────────────────────────┘
```

- Token value is displayed in full with a **copy to clipboard** button
- Warning text: "This is shown only once"
- Tapping Done closes the modal and returns to the token list
- The new token appears in the list (without its value)
