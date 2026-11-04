# Sprint 3 — Relatório de sincronização

**Projeto:** App Personal (Flutter + Drift + Supabase)
**Data:** 2026-07-09
**Escopo:** motor de sync, conflitos, séries append-only, pull incremental, testes

---

## Objetivos cumpridos

| # | Objetivo | Status |
|---|----------|--------|
| 1 | Remover conflito por relógio local | ✅ Resolver só usa `revision` |
| 2 | `revision` atômico no PostgreSQL | ✅ `scripts/sprint3_sync_migration.sql` |
| 3 | Optimistic concurrency real | ✅ `UPDATE … eq(revision, expected)` |
| 4 | Séries append-only | ✅ `PerformedSetEvents` + tabela remota |
| 5 | Reduzir sobregravação | ✅ Merge por `setId`; push de eventos |
| 6 | Pull incremental por watermark | ✅ `pullIncrementalSince` + `SyncWatermarkStore` |
| 7 | Testes de concorrência/conflito | ✅ `conflict_resolver_test`, `sync_watermark_store_test` |
| 8 | Documentação | ✅ `SYNC_ARCHITECTURE.md` |

---

## Arquivos principais

### Criados
- `scripts/sprint3_sync_migration.sql`
- `lib/data/sync/conflict_resolver.dart`
- `lib/data/sync/performed_sets_merge.dart`
- `lib/data/sync/performed_set_sync_service.dart`
- `lib/data/sync/sync_watermark_store.dart`
- `lib/data/sync/sync_coordinator.dart`
- `lib/data/sync/supabase_push_diff_revision.dart`
- `SYNC_ARCHITECTURE.md`
- `test/conflict_resolver_test.dart`
- `test/sync_watermark_store_test.dart`

### Modificados
- `lib/data/local/app_database.dart` — schema v37, `PerformedSetEvents`
- `lib/data/models/day_workout_performed_set.dart` — campo `setId`
- `lib/data/repositories/app_data_repository.dart` — append evento; revision não incrementada localmente
- `lib/data/sync/supabase_remote_sync_service.dart` — push otimista + eventos
- `lib/data/sync/supabase_pull_sync_service.dart` — merge setId + pull incremental
- `lib/data/sync/supabase_auto_pull_scheduler.dart` — 5 min fallback

---

## Validação

```bash
flutter analyze lib test   # warnings menores apenas
flutter test               # 23 tests passed
```

---

## Pré-requisito produção

Executar `scripts/sprint3_sync_migration.sql` no Supabase após Sprint 1/2.

---

## Fora do escopo (Sprint 4+)

Performance geral, UI, build release, Crashlytics/Sentry, publicação App Store.
