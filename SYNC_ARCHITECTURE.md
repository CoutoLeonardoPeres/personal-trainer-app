# Arquitetura de sincronização — App Personal (Sprint 3)

## Princípios

1. **PostgreSQL é a fonte da verdade** para `revision` e conflitos.
2. **Conflitos só por `revision`** — proibido desempate por `updated_at` ou relógio local.
3. **Séries append-only** — tabela `day_workout_performed_sets`; merge por `setId`.
4. **Pull incremental** — watermark por escopo; full pull só no bootstrap/admin.
5. **Push otimista** — `UPDATE … WHERE revision = expected`; stale → pull + retry.

## Componentes

| Módulo | Função |
|--------|--------|
| `ConflictResolver` | `isStaleWrite`, `remoteWins`, `localMayPush` |
| `PerformedSetsMerge` | União por `setId`; JSON local é cache derivado |
| `PerformedSetSyncService` | Insert idempotente + pull de eventos |
| `SyncWatermarkStore` | Cursor `updated_at` por tabela/escopo |
| `SyncCoordinator` | Orquestra pull incremental + hot workouts |
| `SupabaseRemoteSyncService` | Push audit queue + optimistic revision |
| `SupabasePullSyncService` | Pull full (bootstrap) + `pullIncrementalSince` |

## Fluxo push (série)

```
append_set (UI)
  → PerformedSetEvents (Drift, synced=false)
  → cache performedSetsJson (derivado)
  → audit_logs + sync_queue
  → PerformedSetSyncService.pushEvent (INSERT append-only)
  → optimistic UPDATE linha (expected revision)
  → servidor: trigger revision++
  → local revision atualizada da resposta
```

## Fluxo pull (incremental)

```
SyncCoordinator.pullIncremental
  → watermark(scope) ou pullAllFromRemote (bootstrap)
  → day_workouts / day_workout_exercises WHERE updated_at >= since
  → day_workout_performed_sets por linha alterada
  → PerformedSetsMerge.unionBySetId
  → recomputeExerciseScoreForLine (não full recompute)
```

## SQL (Supabase)

Aplicar `scripts/sprint3_sync_migration.sql`:

- Trigger `app_bump_row_revision` em `day_workouts`, `day_workout_exercises`, `workout_groups`
- Tabela `day_workout_performed_sets` (append-only, RLS)
- Backfill opcional JSON → rows

## Polling

- **Antes:** full pull a cada 4s em foreground.
- **Depois:** incremental via coordinator no resume; fallback a cada **5 min** + realtime.

## Transição

- Período dual-write: eventos + `performed_sets_json` cache.
- Após backfill SQL, JSON deixa de ser fonte de verdade.
