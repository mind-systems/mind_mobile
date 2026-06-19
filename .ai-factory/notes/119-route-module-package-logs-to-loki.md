# Route module-package logs through mind_logger (reach Loki)

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- Once `mind_logger` exists (note 118), module packages can finally satisfy the CLAUDE.md "all logs through `logPrint`" rule. Today the only package logs are `debugPrint` calls that never reach Loki — `BreathSessionStateMachine` (`[SM] transition…` ×2) and `mind_audio` `AudioOneShot` (`[AudioOneShot] play failed…` ×1).
- Wiring the dependency into the module packages makes `logPrint` available everywhere and migrates those stray `debugPrint`s — bringing them into compliance with the existing rule (this is compliance, not a logging-policy change).

## Details

### Add the dependency

- Add `mind_logger` (path dep) to `pubspec.yaml` of the module packages that log or will log: `breath_module`, `mind_audio` (the two with existing stray logs), and — for future use and rule-uniformity — `bci_module`, `meditation_module`, `mind_ui`. (Pure `pubspec` additions; packages with zero logs gain only the capability.)

### Migrate the stray `debugPrint`s

- `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart:357,387` — `debugPrint('[SM] transition…')` → `logPrint('[SM] transition…')`; import `package:mind_logger/mind_logger.dart`.
- `packages/mind_audio/lib/src/audio_one_shot.dart:44` — `debugPrint('[AudioOneShot] play failed…')` → `logPrint(...)`; same import.

### Guards

- Depends on note 118 (the package must exist first).
- Keep the message strings unchanged — only the sink changes (`debugPrint` → `logPrint`). This is not "rewriting logs", it is making existing logs reach Loki per the rule.
- Do NOT introduce new log lines or remove existing ones; scope is the dependency wiring + the 3 known call sites.
- After this, a repo-wide grep for `debugPrint(`/`dart:developer` inside `packages/*/lib` (excluding generated) should return nothing — the rule holds everywhere.

### Verify

`flutter analyze` clean; trigger a breath state-machine transition and an `AudioOneShot` play failure → both appear in Loki under `service_name=mind_mobile` (`observe-logs window …`), not just console.

## Open Questions

- Whether to add `mind_logger` to the zero-log packages (`bci_module`/`meditation_module`/`mind_ui`) now or lazily when they first need a log — leaning "now" for rule-uniformity, but it is a cheap reversible call.
