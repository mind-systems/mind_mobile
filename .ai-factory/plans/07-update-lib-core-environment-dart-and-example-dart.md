# Plan: Update lib/Core/Environment.dart (and .example.dart)

## Context

Add gRPC connection fields (`grpcHost`, `grpcPort`, `grpcSecure`) to the Environment class so that `GrpcClient` can read host/port/TLS settings per flavor. The implementation is already complete — only roadmap bookkeeping remains.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Bookkeeping

- [x] **Task 1: Mark roadmap milestone 2.3 sub-task as done**
  Files: `.ai-factory/ROADMAP.md`
  In section `### 2.3 Create GrpcClient`, change `- [ ] **Update \`lib/Core/Environment.dart\` (and \`.example.dart\`)**` to `- [x]`. The work is already implemented: `Environment.dart` contains `grpcHost`, `grpcPort`, `grpcSecure` with correct dev/prod values, and `Environment.example.dart` has matching placeholders.
