# app_personal

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Offline-first sync rollout (sets/rest)

### 1) SQL migration (idempotent, additive)

Run the script below in Supabase SQL editor:

- `scripts/sync_events_hardening.sql`

The script only uses additive operations (`create table if not exists`,
`create index if not exists`, trigger create/replace, publication guarded with
`if not exists`, RLS/policies create) and does not drop/truncate data.

### 2) Flutter local migration

Local SQLite migration is incremental in Drift:

- `schemaVersion` bumped to `29`
- `if (from < 29)` creates:
  - `day_workout_set_events_local`
  - `day_workout_set_rest_events_local`
  - `day_workout_set_event_tombstones_local`
  - `sync_outbox`

### 3) Manual tests

1. Add set on iPhone, verify appears on tablet in a few seconds.
2. Add set on tablet, verify modal closes on local commit and set appears on iPhone.
3. Delete set on iPhone, verify disappears on tablet.
4. Delete set on tablet, verify disappears on iPhone.
5. Offline test:
   - disable internet on one device
   - add and remove sets
   - re-enable internet
   - verify outbox drains and both devices converge.

### 4) Concurrency checks

1. Keep both devices on the same started workout.
2. Log sets almost simultaneously on same line.
3. Verify no duplicate events and no stuck modal.
4. Verify UI still renders from `DayWorkoutPerformedSetCodec.decode(performedSetsJson)`.
