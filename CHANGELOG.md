# Changelog

All notable changes to App Personal are documented in this file.

## [Unreleased]

### Sprint 3 — Sync engine (2026-07-09)

#### Added
- Server-side atomic `revision` triggers and append-only `day_workout_performed_sets` table (`scripts/sprint3_sync_migration.sql`).
- `ConflictResolver`, `PerformedSetsMerge`, `PerformedSetSyncService`, `SyncWatermarkStore`, `SyncCoordinator`.
- Drift schema v37: local `PerformedSetEvents` table.
- Incremental pull via `pullIncrementalSince` and watermark cursors.
- Security/sync tests: `conflict_resolver_test.dart`, `sync_watermark_store_test.dart`.
- Documentation: `SYNC_ARCHITECTURE.md`, `SPRINT_3_REPORT.md`.

#### Changed
- Conflict resolution uses **revision only** (no `updated_at` / clock tolerances for LWW).
- Performed sets: append-only events with stable `setId`; JSON is derived cache.
- Client no longer increments `revision` on local mutations; server trigger is authoritative.
- Foreground polling reduced from 4s full scan to 5min incremental fallback.

#### Removed
- Client-side `_nextRevision()` increment on workout mutations.

### Sprint 2 — RBAC & password security (2026-07-09)

- Secure password reset via Supabase Auth links (no app-generated passwords).
- Server-side RBAC profile fetch; email uniqueness guards; hardened RLS scripts.

### Sprint 1 — Supabase Auth migration (2026-07-09)

- Login via Supabase Auth; removed local `password_hash`; RLS by `auth.uid()`.
