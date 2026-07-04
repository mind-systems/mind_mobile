# Local/cloud OTLP endpoint selection via Environment.dart

**Date:** 2026-07-04
**Source:** conversation context

## Key Findings

- `Environment.otlpEndpoint` was only ever assigned inside `overrideForDev()`, whose sole call site was commented out — so observe never activated in a real build.
- `initStaging()`/`initProd()` never set `otlpEndpoint` — stayed `null` in every real build.
- `Environment.dart` is gitignored (only `Environment.example.dart`, with placeholder values, is tracked) — it is this project's existing, established local-secrets store (already holds Google client IDs, LAN IPs, etc.). This is the right home for OTLP values too — no new file mechanism needed.
- The staging cloud observe backend is live and verified (see `digital_ocean/.ai-factory/handoffs/03-observe-staging-deploy-endpoints.md` — its live URL is an operational value, not repeated here).
- `App.dart`'s `init(...)` call passed no `headers`, but the write-proxy in front of both the local and cloud endpoints requires `Authorization: Bearer <token>` on every write. `observe-dart`'s `init()` already accepts `Map<String,String> headers`.

## Details

### Current state → target change (shipped 2026-07-04)

- Added `String? otlpAuthToken;` alongside the existing `String? otlpEndpoint;` field on `Environment`.
- `initStaging()` now sets both `otlpEndpoint`/`otlpAuthToken` directly to the real staging values (same pattern as `grpcHost`/`apiBaseUrl`), **then** calls `overrideForDev()` when `kDebugMode` — restoring the original active local-dev override (previously commented out), matching `Environment.example.dart`'s expected default. When developing locally, the dev override wins; a `kReleaseMode` staging build keeps the staging values.
- `overrideForDev()` sets `otlpEndpoint`/`otlpAuthToken` to the real local values (via the local `observe-write-proxy` on the dev LAN IP, matching `grpcHost`/`apiBaseUrl`'s existing convention), alongside the pre-existing LAN-IP overrides for `grpcHost`/`apiBaseUrl`.
- `App.initialize()` reads `Environment.instance.otlpEndpoint`/`otlpAuthToken` directly (no `--dart-define`, no separate file) and threads the token into `init(...)`'s `headers`.
- `Environment.example.dart` mirrors the same two fields with placeholder values, so a fresh checkout's `cp Environment.example.dart Environment.dart` documents what to fill in.
- Real values live only in the gitignored `Environment.dart` — never in this spec, the roadmap contract line, or `Environment.example.dart`.

### Guards

- `grpcHost`/`grpcPort`/`grpcSecure`/`apiBaseUrl` overrides are untouched — only the two new OTLP fields were added alongside them.
- No `--dart-define`, no new env file — everything lives in the one existing gitignored config class.
- Don't invent/mint a token from a spec-writing session — tokens are minted via the write-proxy's admin GUI and copied directly into the gitignored `Environment.dart`.

## Verify

- Local dev (`flutter run -t lib/main_staging.dart`, debug mode): `overrideForDev()` is active — confirm via `observe-logs` skill: `since-restart mind_mobile --project mind` against the local backend.
- Staging release build (`flutter run --release -t lib/main_staging.dart`, or an actual staging build): `overrideForDev()` does not run — confirm via Grafana Explore against the staging backend.
- `initProd()` still sets no `otlpEndpoint` — prod stack is a separate, deferred deployment; observe stays off in prod builds until then.
