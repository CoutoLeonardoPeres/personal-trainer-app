# Migração do banco legado

O cutover de 5 de novembro de 2026 usa os scripts versionados em
`supabase/production/`, nesta ordem:

1. `01_preflight_read_only.sql`: valida a origem sem alterar dados.
2. `02_archive_legacy.sql`: renomeia `public` para `legacy_20261105` e
   cria o schema privado `migration_20261105`.
3. Migrations `0001` a `0009`.
4. `03_import_legacy.sql`: converte tenant, status, planejamento, exercícios
   e séries; registra cada decisão de migração.
5. `04_validate_import.sql`: executa 45 invariantes e aborta em divergência.

O script `scripts/migrate_existing_supabase.sh` automatiza essa ordem quando
`DATABASE_URL`, `BACKUP_DIR` e `CONFIRM_MIGRATION` são informados.

## Resultado esperado

- 25 tabelas legadas preservadas no schema privado.
- 2.093 itens de planejamento após deduplicação.
- 777 exercícios de treino após deduplicação.
- 1.257 eventos lógicos de série após reconciliar as três fontes.
- 45 validações aprovadas, sem tenant nulo ou FK inválida.

O teste `supabase/tests/migration/05_actual_production_migration.test.sql`
confere essas evidências. O schema legado e o backup externo devem ser mantidos
até a conclusão das fases do aplicativo e da estabilização.

## Rollback

Com o aplicativo ainda fora de uso, o retorno rápido consiste em remover o
novo `public` e renomear `legacy_20261105` de volta para `public`. Depois
que houver gravações no modelo novo, elas precisam ser exportadas e convertidas
antes do retorno. O dump externo é a recuperação de último recurso.
