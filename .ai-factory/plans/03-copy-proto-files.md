# Plan: Copy proto files

## Context
Create `mind_mobile/proto/` and populate it with explicit copies of all `.proto` files from `mind_api/proto/` (the single source of truth). No symlinks — files are copied so the proto snapshot in this repo is stable and independent of `mind_api` checkout state.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Copy proto files

- [x] **Task 1: Create `proto/` directory and copy all `.proto` files**
  Files: `proto/auth.proto`, `proto/breath_sessions.proto`, `proto/device.proto`, `proto/live.proto`, `proto/stats.proto`, `proto/sync.proto`, `proto/telemetry.proto`, `proto/users.proto`
  Create the `mind_mobile/proto/` directory. Copy all 8 `.proto` files from `mind_api/proto/` into it: `auth.proto`, `breath_sessions.proto`, `device.proto`, `live.proto`, `stats.proto`, `sync.proto`, `telemetry.proto`, `users.proto`. Copy only the `.proto` files — do not copy `README.md` or the `generated/` subdirectory. Files must be byte-identical to their `mind_api/proto/` originals.
